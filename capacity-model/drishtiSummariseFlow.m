function s = drishtiSummariseFlow(f, p)
%DRISHTISUMMARISEFLOW  Reduce flow-model step data to what the page shows.
%
%   s = drishtiSummariseFlow(f, p)
%
%   f comes from drishtiFlowModel, or from a real Simulink run repackaged in
%   the same shape. Returns annual totals, utilisation while each resource
%   is available, peak backlogs, a three-day window at full step resolution
%   (the daily burst-and-drain shape) and the end-of-day backlog for every
%   day of the year (which is where an overloaded specialist queue shows up
%   as a line that never comes back down).

dt = f.dt;
stepsPerDay = round(24 / dt);
nDays = floor(size(f.flow, 1) / stepsPerDay);

s.stages = f.stages;
s.units  = {'patients', 'images', 'images', 'cases', 'referrals'};

s.total = sum(f.flow, 1) * dt;

capTotal = sum(f.cap, 1) * dt;
s.availUtilPct = 100 * s.total ./ max(capTotal, eps);

s.maxBacklog = max(f.backlog, [], 1);

% A window away from the empty-system start-up, so it shows steady state.
startDay = min(max(1, round(nDays / 2)), max(1, nDays - 3));
idx = (startDay - 1) * stepsPerDay + (1 : 3 * stepsPerDay);
idx = idx(idx <= size(f.flow, 1));
s.window.hours   = ((0 : numel(idx) - 1) * dt).';
s.window.backlog = round(f.backlog(idx, :), 3);
s.window.flow    = round(f.flow(idx, :), 3);
s.window.startDay = startDay;

endOfDay = (1 : nDays) * stepsPerDay;
s.daily.day     = (1 : nDays).';
s.daily.backlog = round(f.backlog(endOfDay, :), 2);

s.params.simStepH    = dt;
s.params.workingDays = p.workingDays;
end
