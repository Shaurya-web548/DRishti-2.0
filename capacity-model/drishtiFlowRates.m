function r = drishtiFlowRates(p)
%DRISHTIFLOWRATES  Derived rate constants for the district flow model.
%
%   r = drishtiFlowRates(p)
%
%   These are the constants buildDRishtiSimulinkModel wires into its
%   Constant, Gain and Pulse Generator blocks, computed the same way. The
%   base-MATLAB solver in drishtiFlowModel uses them too, so both engines
%   run on identical numbers.
%
%   The builder keeps its own private copies of these helpers because it
%   cannot be executed on a machine without Simulink; if you change a
%   formula here, change it there as well.

% Patients per hour arriving while a session is open.
r.patPerSessionHour = p.annualPatients / (p.workingDays * p.sessionHours);

% Capture capacity across all sites, patients/hour while sessions are open.
r.captureCapPerH = p.sites * 60 / (p.captureMin + p.retryMin * expectedRetries(p));

% Images actually uploaded per screened patient.
r.imgPerPatient = 2 * (1 - residualRejectRate(p));

% Uplink capacity, images/hour, all sites, around the clock.
r.uplinkCapPerH = p.sites * (p.uplinkMbps * 3600) / (p.imageMB * 8);

% Compute capacity, images/hour, around the clock.
r.computeCapPerH = p.workers * 3600 / p.procMeanSec;

% Human review, cases/hour while graders are on shift.
r.reviewCapPerH  = p.graderFTE * 60 / p.reviewMin;
r.humanTouchRate = p.pDisagree + (1 - p.pDisagree) * p.qaSampleRate;

% Referral, cases/hour while the clinic is open.
r.referralCapPerH = p.ophthFTE * 60 / p.ophthMinPerCase;
end

function r = expectedRetries(p)
%EXPECTEDRETRIES  Mean recapture attempts per patient across both eyes.
pn = p.pRejectNormal; pd = p.pRejectDifficult; f = p.pDifficultPatient;
en = meanAttempts(pn, p.maxRetries);
ed = meanAttempts(pd, p.maxRetries);
r = 2 * ((1 - f) * en + f * ed);
end

function m = meanAttempts(pRej, maxRetries)
m = 0;
for k = 1:maxRetries
    m = m + pRej ^ k;
end
end

function r = residualRejectRate(p)
%RESIDUALREJECTRATE  Fraction of eyes still ungradable after all retries.
n = p.maxRetries + 1;
r = (1 - p.pDifficultPatient) * p.pRejectNormal ^ n + ...
     p.pDifficultPatient      * p.pRejectDifficult ^ n;
end
