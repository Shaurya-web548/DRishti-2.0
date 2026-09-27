function json = drishtiRunScenarioJSON(overridesJson)
%DRISHTIRUNSCENARIOJSON  JSON in, JSON out wrapper for the web layer.
%
%   json = drishtiRunScenarioJSON('{"annualPatients":150000}')
%
%   Passing plain JSON across the MATLAB Engine boundary avoids the fragile
%   conversion of nested structs and struct arrays into Python objects.

if nargin < 1 || isempty(overridesJson) || strlength(string(overridesJson)) == 0
    overrides = struct();
else
    overrides = jsondecode(char(overridesJson));
    if ~isstruct(overrides)
        error('drishtiRunScenarioJSON:badInput', 'Expected a JSON object of parameters.');
    end
end

json = jsonencode(drishtiRunScenario(overrides));
end
