function used = drishtiSetupCompat(verbose)
%DRISHTISETUPCOMPAT  Put the pure-MATLAB image-processing shims on the path
% when the Image Processing Toolbox is not available.
%
%   used = drishtiSetupCompat()        returns true if the shims are in use
%   used = drishtiSetupCompat(true)    also prints which route was taken
%
%   Base MATLAB ships only imread, imwrite, imresize, rgb2gray, im2double
%   and ind2rgb. Everything else the DRishti pipeline needs - morphology,
%   connected components, regionprops, CLAHE, the distance transform, the
%   circular Hough transform - lives in compat/ as plain MATLAB code.
%
%   The shims go on the path ONLY when the real toolbox is missing, so an
%   installation that does have the toolbox keeps using MathWorks' own
%   implementations and never silently runs the fallbacks.

if nargin < 1, verbose = false; end

here = fileparts(mfilename('fullpath'));
compatDir = fullfile(here, 'compat');

% Decide on the toolbox by where the probe function resolves to, not merely
% whether it resolves: once the shims are on the path, which() would find
% them and a plain existence test would report a toolbox that is not there.
probe = which('imfindcircles');
hasToolbox = ~isempty(probe) && ~drishtiIsInside(probe, compatDir);

if hasToolbox
    used = false;
    if verbose
        fprintf('[drishti] Image Processing Toolbox found - using it.\n');
    end
    return
end

if isempty(probe)
    addpath(compatDir);
end
used = true;

if verbose
    fprintf('[drishti] Image Processing Toolbox not installed.\n');
    fprintf('[drishti] Using the pure-MATLAB shims in %s\n', compatDir);
end
end

function tf = drishtiIsInside(filePath, folder)
%DRISHTIISINSIDE  True when filePath sits inside folder.
filePath = lower(strrep(char(filePath), '/', filesep));
folder   = lower(strrep(char(folder),   '/', filesep));
tf = strncmp(filePath, [folder filesep], numel(folder) + 1);
end
