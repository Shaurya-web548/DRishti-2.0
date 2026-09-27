function [centers, radii, metric] = imfindcircles(A, radiusRange, varargin)
%IMFINDCIRCLES  Circular Hough transform (Image Processing Toolbox compat shim).
%
%   [centers, radii] = imfindcircles(A, radiusRange)
%   [centers, radii, metric] = imfindcircles(___, 'ObjectPolarity', p, ...
%                                                 'Sensitivity', s, ...
%                                                 'EdgeThreshold', e)
%
%   centers is N-by-2 as [x y], radii is N-by-1, and both are sorted
%   strongest first, matching the toolbox.
%
%   Method: every strong-gradient pixel votes for a centre one radius away
%   along its gradient direction - towards the bright side for
%   ObjectPolarity 'bright', away from it for 'dark'. Votes are accumulated
%   one radius at a time and each pixel keeps only its best-scoring radius,
%   so memory stays flat no matter how wide the radius range is.
%
%   The score is the share of a circle's circumference that voted for it, so
%   Sensitivity keeps its usual meaning: the threshold is 1 - Sensitivity.

p = drishtiParseCircleArgs(varargin);

% ---- grayscale, in [0,1] ----------------------------------------------
if size(A, 3) == 3
    G = double(rgb2gray(A));
else
    G = double(A);
end
if isinteger(A)
    G = G / double(intmax(class(A)));
else
    G = G / max(1, max(G(:)));
end

[H, W] = size(G);

rMin = max(1, floor(min(radiusRange)));
rMax = max(rMin, ceil(max(radiusRange)));

% Keep the radius sweep bounded; a step above 1 px costs nothing here
% because the accumulator is smoothed anyway.
maxSteps = 60;
rStep = max(1, ceil((rMax - rMin + 1) / maxSteps));
radiusList = rMin : rStep : rMax;

% ---- gradients ---------------------------------------------------------
% conv2 convolves, which flips the kernel. Rotating the Sobel masks first
% turns that back into correlation, so the gradient really points from dark
% towards bright. Get this backwards and every vote lands on the far side of
% the circle and nothing is ever found.
sobelX = [-1 0 1; -2 0 2; -1 0 1];
sobelY = [-1 -2 -1; 0 0 0; 1 2 1];
gx = conv2(G, rot90(sobelX, 2), 'same');
gy = conv2(G, rot90(sobelY, 2), 'same');
gm = sqrt(gx .^ 2 + gy .^ 2);

if ~any(gm(:) > 0)
    centers = zeros(0, 2); radii = zeros(0, 1); metric = zeros(0, 1);
    return
end

% Edge pixels. With no explicit EdgeThreshold, split the gradient magnitudes
% with Otsu rather than taking a fixed top percentile: a percentile throws
% away most of a clean boundary, which starves the accumulator and makes even
% an obvious circle score below threshold.
if isempty(p.EdgeThreshold)
    nz = gm(gm > 0);
    if isempty(nz)
        centers = zeros(0, 2); radii = zeros(0, 1); metric = zeros(0, 1);
        return
    end
    thresh = max(drishtiOtsu(nz), 0.02 * max(gm(:)));
else
    thresh = p.EdgeThreshold * max(gm(:));
end
edgeIdx = find(gm >= thresh);

if isempty(edgeIdx)
    centers = zeros(0, 2); radii = zeros(0, 1); metric = zeros(0, 1);
    return
end

ex = floor((edgeIdx - 1) / H) + 1;          % column = x
ey = mod(edgeIdx - 1, H) + 1;               % row    = y
ux = gx(edgeIdx) ./ gm(edgeIdx);
uy = gy(edgeIdx) ./ gm(edgeIdx);

if strcmpi(p.ObjectPolarity, 'dark')
    ux = -ux;
    uy = -uy;
end

% ---- vote, one radius at a time ---------------------------------------
bestVal = zeros(H, W);
bestRad = zeros(H, W);

% Votes scatter by a pixel or two because the centre is rounded to the grid
% and the gradient direction is noisy, so collect each candidate's votes over
% a small window. A box sum keeps the vote COUNT intact; blurring would
% spread the peak out and deflate the score.
win = 2 * max(2, rStep) + 1;

for r = radiusList
    cx = round(ex + r * ux);
    cy = round(ey + r * uy);
    keep = cx >= 1 & cx <= W & cy >= 1 & cy <= H;
    if ~any(keep), continue; end

    lin = cy(keep) + (cx(keep) - 1) * H;
    acc = accumarray(lin, 1, [H * W, 1]);
    acc = reshape(acc, H, W);

    acc = drishtiBoxSum(acc, win, win);

    % Score is the share of the circle's circumference that voted for it,
    % which keeps Sensitivity meaning what it does in the toolbox.
    score = acc / (2 * pi * r);
    upd = score > bestVal;
    bestVal(upd) = score(upd);
    bestRad(upd) = r;
end

% ---- pick peaks --------------------------------------------------------
threshold = max(0, 1 - p.Sensitivity);

centers = zeros(0, 2);
radii   = zeros(0, 1);
metric  = zeros(0, 1);

work = bestVal;
for k = 1:p.MaxCircles
    [val, idx] = max(work(:));
    if ~isfinite(val) || val < threshold, break; end

    cy = mod(idx - 1, H) + 1;
    cx = floor((idx - 1) / H) + 1;
    r  = bestRad(idx);
    if r <= 0, break; end

    centers(end + 1, :) = [cx cy];    %#ok<AGROW>
    radii(end + 1, 1)   = r;          %#ok<AGROW>
    metric(end + 1, 1)  = val;        %#ok<AGROW>

    % Suppress this peak's neighbourhood so the next pick is a new circle.
    supp = max(3, round(r / 2));
    rows = max(1, cy - supp) : min(H, cy + supp);
    cols = max(1, cx - supp) : min(W, cx + supp);
    work(rows, cols) = -Inf;
end
end

% ------------------------------------------------------------------------
function p = drishtiParseCircleArgs(args)
p.ObjectPolarity = 'bright';
p.Sensitivity    = 0.85;
p.EdgeThreshold  = [];
p.MaxCircles     = 20;
for k = 1:2:numel(args)
    name = lower(char(args{k}));
    val  = args{k + 1};
    switch name
        case 'objectpolarity'
            p.ObjectPolarity = lower(char(val));
        case 'sensitivity'
            p.Sensitivity = min(1, max(0, double(val)));
        case 'edgethreshold'
            p.EdgeThreshold = min(1, max(0, double(val)));
        case 'method'
            % 'PhaseCode' / 'TwoStage' - this shim always uses its own accumulator
        otherwise
            error('imfindcircles:badOption', 'Unsupported option: %s', name);
    end
end
end
