function collectReportData(outFile)
%COLLECTREPORTDATA  Run every scenario the project report quotes and save
% the numbers as JSON, so the report never carries a hand-typed figure.
%
%   collectReportData()                        -> tools/report/report_data.json
%   collectReportData('somewhere/data.json')
%
%   Takes about ten seconds in base MATLAB.

here = fileparts(mfilename('fullpath'));
repo = fileparts(fileparts(here));
addpath(fullfile(repo, 'capacity-model'));
if nargin < 1, outFile = fullfile(here, 'report_data.json'); end

data.generated = char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm'));
data.matlabRelease = version('-release');

data.baseline = slim(drishtiRunScenario());
data.growth   = slim(drishtiRunScenario(struct('annualPatients', 150000)));
data.minimum  = slim(drishtiRunScenario(struct('sites', 10, 'workers', 1, 'graderFTE', 1)));

volumes = [50000 100000 150000 200000 300000];
data.volumeSweep = arrayfun(@(v) slim(drishtiRunScenario(struct('annualPatients', v))), volumes);

secs = [11 20 40 60];
data.computeSweep = arrayfun(@(s) slim(drishtiRunScenario(struct('workers', 1, 'procMeanSec', s))), secs);

fid = fopen(outFile, 'w');
fwrite(fid, jsonencode(data, PrettyPrint = true));
fclose(fid);
fprintf('Wrote %s\n', outFile);
end

function s = slim(r)
%SLIM  Keep what the report prints; drop the per-step chart series.
s.engine      = r.engine;
s.params      = r.params;
s.des         = r.des;
s.utilisation = r.utilisation;
s.bottleneck  = r.bottleneck;
s.validation  = r.validation;
s.flowTotal   = r.flow.total;
s.referralBacklogEndOfYear = r.flow.daily.backlog(end, 5);
s.timing      = r.timing;
end
