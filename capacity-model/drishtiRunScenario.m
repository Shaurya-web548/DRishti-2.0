function res = drishtiRunScenario(overrides)
%DRISHTIRUNSCENARIO  Run one what-if scenario through both capacity models.
%
%   res = drishtiRunScenario()            baseline, drishtiParams()
%   res = drishtiRunScenario(overrides)   struct of parameters to change
%
%   Runs the two models side by side, because they answer different
%   questions:
%
%     drishtiCapacityDES   entity-level and stochastic. The reference: every
%                          utilisation, wait and percentile comes from here.
%     flow model           deterministic rates and backlogs. Shows the daily
%                          burst-and-drain shape and where backlog piles up.
%
%   The flow model runs in real Simulink when Simulink is installed, and in
%   drishtiFlowModel (same block equations, base MATLAB) when it is not.
%   res.engine says which one ran, and res.validation compares the flow
%   model's annual totals with the DES, the same check compareSimulinkToDES
%   performs.
%
%   Only the parameters a planner would reasonably change are accepted, and
%   each is range-checked here as well as in the web layer.

if nargin < 1 || isempty(overrides), overrides = struct(); end

p = applyOverrides(drishtiParams(), overrides);

tDes = tic;
des = drishtiCapacityDES(p);
res.timing.desSec = toc(tDes);

tFlow = tic;
[f, note] = runFlowModel(p);
res.timing.flowSec = toc(tFlow);

flow = drishtiSummariseFlow(f, p);

res.engine     = f.engine;
res.engineNote = note;
res.params     = publicParams(p);
res.des        = desHeadline(des);
res.utilisation = utilisationRows(des);

[~, worst] = max([res.utilisation.pct]);
res.bottleneck = res.utilisation(worst);

res.flow = flow;
res.validation = validateAgainstDES(flow, des);
end

%% ===================================================== parameter handling

function p = applyOverrides(p, ov)
%APPLYOVERRIDES  Copy the allowed, range-checked fields of ov into p.
limits = allowedLimits();
names = fieldnames(ov);
for k = 1:numel(names)
    name = names{k};
    if ~isfield(limits, name)
        error('drishtiRunScenario:unknownParam', 'Unknown parameter: %s', name);
    end
    v = ov.(name);
    if ~(isnumeric(v) && isscalar(v) && isfinite(v))
        error('drishtiRunScenario:badValue', '%s must be a finite number.', name);
    end
    lim = limits.(name);
    if v < lim(1) || v > lim(2)
        error('drishtiRunScenario:outOfRange', ...
              '%s must be between %g and %g.', name, lim(1), lim(2));
    end
    p.(name) = double(v);
end

% Whole-number quantities.
p.annualPatients = round(p.annualPatients);
p.sites          = round(p.sites);
p.workers        = round(p.workers);
end

function lim = allowedLimits()
%ALLOWEDLIMITS  What the page may change, and the sane range for each.
lim.annualPatients = [10000 400000];
lim.sites          = [1 30];
lim.workers        = [1 16];
lim.procMeanSec    = [2 180];
lim.graderFTE      = [0.5 10];
lim.ophthFTE       = [0.25 6];
lim.uplinkMbps     = [0.1 50];
lim.pReferable     = [0.01 0.40];
lim.pDisagree      = [0 0.60];
end

function q = publicParams(p)
q = struct();
names = fieldnames(allowedLimits());
for k = 1:numel(names)
    q.(names{k}) = p.(names{k});
end
q.workingDays  = p.workingDays;
q.sessionHours = p.sessionHours;
end

%% ========================================================= flow model

function [f, note] = runFlowModel(p)
%RUNFLOWMODEL  Real Simulink when it is installed, otherwise the base-MATLAB
% solver of the same block diagram.
if isempty(which('new_system'))
    note = ['Simulink is not installed here, so the Simulink block diagram ' ...
            'ran in the base-MATLAB solver (same blocks, same equations).'];
    f = drishtiFlowModel(p);
    return
end

try
    f = runSimulink(p);
    note = 'Flow model simulated in Simulink.';
catch err
    note = ['Simulink run failed (' err.message '); ' ...
            'used the base-MATLAB solver of the same block diagram instead.'];
    f = drishtiFlowModel(p);
end
end

function f = runSimulink(p)
%RUNSIMULINK  Build and simulate the real Simulink model.
%
%   Written for a machine that has Simulink; this one does not, so this
%   branch has never executed. runFlowModel catches any failure and falls
%   back to the base-MATLAB solver, so a problem here cannot break a request.

work = fullfile(tempdir, 'drishti_simulink');
if ~isfolder(work), mkdir(work); end
here = pwd;
restoreDir = onCleanup(@() cd(here));
cd(work);

mdl = 'drishtiCapacityFlow';
buildDRishtiSimulinkModel(p, mdl);
closeModel = onCleanup(@() close_system(mdl, 0));
simOut = sim(mdl);

% Capacities are not logged by the model; the reference solver computes the
% identical gated capacities, so borrow them from there.
ref = drishtiFlowModel(p);
n = size(ref.flow, 1);

f = ref;
f.engine = 'simulink';
for s = 1:numel(ref.stages)
    name = ref.stages{s};
    f.flow(:, s)    = loggedSeries(simOut, [name '_flow'], n);
    f.backlog(:, s) = loggedSeries(simOut, [name '_backlog'], n);
end
end

function v = loggedSeries(simOut, name, n)
%LOGGEDSERIES  One To Workspace timeseries, trimmed to n samples.
ts = simOut.get(name);
d = double(ts.Data(:));
if numel(d) < n
    error('drishtiRunScenario:shortLog', 'Signal %s has %d samples, expected %d.', ...
          name, numel(d), n);
end
v = d(1:n);
end

%% ====================================================== result shaping

function h = desHeadline(des)
h.patientsScreened   = des.demand.patientsScreened;
h.unmetDemandPct     = des.demand.unmetDemandPct;
h.ungradableRatePct  = des.demand.ungradableRatePct;
h.imagesUploaded     = des.demand.imagesUploaded;
h.gbPerYear          = des.bandwidth.gbPerYear;
h.autoMedianMin      = des.turnaround.autoMedianMin;
h.autoP95Min         = des.turnaround.autoP95Min;
h.sameSessionPct     = des.turnaround.sameSessionPct;
h.turnaroundP95H     = des.turnaround.p95H;
h.withinSlaPct       = des.turnaround.withinSlaPct;
h.humanTouchRatePct  = des.review.humanTouchRatePct;
h.casesToHuman       = des.review.casesToHuman;
h.referableCases     = des.referral.referableCases;
h.referralP95WaitDays = des.referral.p95WaitDays;
h.referralMaxBacklog = des.referral.maxBacklog;
h.computeP95WaitMin  = des.compute.p95WaitMin;
h.computeUtil24hPct  = des.compute.utilPct;
end

function rows = utilisationRows(des)
%UTILISATIONROWS  One row per resource, each on the basis that governs its
% queueing: shift hours for people, session hours for the always-on
% resources, because every site captures inside the same window.
rows = struct( ...
    'key',   {'technician', 'uplink', 'compute', 'grader', 'ophthalmologist'}, ...
    'label', {'Technician', 'Site uplink', 'Compute workers', 'Graders', 'Ophthalmologist'}, ...
    'pct',   {des.technician.utilPct, des.bandwidth.sessionLinkUtilPct, ...
              des.compute.sessionUtilPct, des.review.utilPct, des.referral.utilPct}, ...
    'basis', {'of session hours', 'of session hours', 'of session hours', ...
              'of shift hours', 'of appointment slots'});
end

function v = validateAgainstDES(flow, des)
%VALIDATEAGAINSTDES  Annual totals, flow model versus the DES reference.
names = {'Patients screened', 'Images uploaded', 'Images processed', ...
         'Human review cases', 'Referrals'};
desVals = [des.demand.patientsScreened, des.demand.imagesUploaded, ...
           des.demand.imagesUploaded, des.review.casesToHuman, ...
           des.referral.referableCases];
v = struct('quantity', names, ...
           'flow', num2cell(round(flow.total)), ...
           'des',  num2cell(desVals), ...
           'diffPct', num2cell(round(100 * (flow.total - desVals) ./ max(1, desVals), 1)));
end
