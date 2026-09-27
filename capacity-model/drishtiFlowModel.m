function f = drishtiFlowModel(p)
%DRISHTIFLOWMODEL  Execute the district flow model in base MATLAB.
%
%   f = drishtiFlowModel(p)
%
%   Runs exactly the block diagram that buildDRishtiSimulinkModel builds,
%   step by step, without needing Simulink:
%
%     acquisition -> uplink -> compute -> human review -> referral
%
%   Each stage is a backlog integrator:
%
%     offered   = inflow + backlog / dt
%     flow      = min(offered, capacity)
%     backlog'  = max(0, backlog + (inflow - flow) * dt)   (Forward Euler)
%
%   Capacities of shift-bound resources are gated by sample-based pulse
%   generators with zero phase, exactly as in the Simulink model, so hour 0
%   of every day is the moment the session opens. Forward Euler matters: it
%   is what lets the Simulink model break the backlog -> flow algebraic
%   loop, and the same ordering is kept here so the two agree step for step.
%
%   Returns the per-step matrices; drishtiSummariseFlow turns them into the
%   numbers the web page shows. On a machine with Simulink, drishtiRunScenario
%   runs the real model instead and hands its logged signals to the same
%   summariser.

r  = drishtiFlowRates(p);
dt = p.simStepH;

stepsPerDay = round(24 / dt);
nSteps      = p.workingDays * stepsPerDay;

sessionGate = pulseGate(nSteps, stepsPerDay, p.sessionHours, dt);
graderGate  = pulseGate(nSteps, stepsPerDay, p.graderHoursPerDay, dt);
ophthGate   = pulseGate(nSteps, stepsPerDay, p.ophthHoursPerDay, dt);

% Capacity of each stage at every step (columns follow f.stages).
cap = [ r.captureCapPerH  * sessionGate, ...
        r.uplinkCapPerH   * ones(nSteps, 1), ...
        r.computeCapPerH  * ones(nSteps, 1), ...
        r.reviewCapPerH   * graderGate, ...
        r.referralCapPerH * ophthGate ];

arrivals = r.patPerSessionHour * sessionGate;

flow    = zeros(nSteps, 5);
backlog = zeros(nSteps, 5);        % integrator output at the start of the step
state   = zeros(1, 5);

for k = 1:nSteps
    backlog(k, :) = state;

    % Stage inflows chain through the same step, as in the block diagram.
    inflow = zeros(1, 5);
    inflow(1) = arrivals(k);
    for s = 1:5
        if s == 2
            inflow(2) = flow(k, 1) * r.imgPerPatient;
        elseif s == 3
            inflow(3) = flow(k, 2);
        elseif s == 4
            inflow(4) = flow(k, 3) / r.imgPerPatient * r.humanTouchRate;
        elseif s == 5
            inflow(5) = flow(k, 4) * (p.pReferable / r.humanTouchRate);
        end

        offered    = inflow(s) + state(s) / dt;
        flow(k, s) = min(offered, cap(k, s));
        state(s)   = max(0, state(s) + (inflow(s) - flow(k, s)) * dt);
    end
end

f.engine  = 'matlab';
f.dt      = dt;
f.stages  = {'Acquire', 'Uplink', 'Compute', 'Review', 'Referral'};
f.flow    = flow;
f.backlog = backlog;
f.cap     = cap;
end

function g = pulseGate(nSteps, period, hoursOn, dt)
%PULSEGATE  Sample-based pulse: 1 for the first hoursOn of every period.
% Mirrors Pulse Generator with PulseType 'Sample based' and PhaseDelay 0.
width = max(1, round(hoursOn / dt));
k = (0:nSteps - 1).';
g = double(mod(k, period) < width);
end
