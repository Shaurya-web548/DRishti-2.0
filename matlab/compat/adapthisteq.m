function J = adapthisteq(I, varargin)
%ADAPTHISTEQ  Contrast-limited adaptive histogram equalisation (IPT compat shim).
%
%   J = adapthisteq(I)
%   J = adapthisteq(I, 'ClipLimit', c, 'NumTiles', [m n], 'NBins', b)
%
%   Follows the standard CLAHE construction the toolbox uses:
%
%     1. split the image into NumTiles tiles,
%     2. histogram each tile, clip counts at the contrast limit and spread
%        the clipped excess back across all bins,
%     3. turn each clipped histogram into a cumulative mapping,
%     4. bilinearly interpolate between the four surrounding tile mappings
%        so tile seams do not show.
%
%   The clip limit is normalised exactly as the toolbox does: it scales
%   between "flat histogram" (0) and "no clipping" (1), so ClipLimit 0.01
%   means the same thing here as it does with the real toolbox.

p = drishtiParseArgs(varargin);

inClass = class(I);
[Id, wasScaled] = drishtiToUnit(I);
[H, W] = size(Id);

numTiles = p.NumTiles;
nBins    = p.NBins;

% ---- pad so the tiles divide the image evenly --------------------------
tileH = ceil(H / numTiles(1));
tileW = ceil(W / numTiles(2));
padH = tileH * numTiles(1) - H;
padW = tileW * numTiles(2) - W;
if padH > 0 || padW > 0
    Ip = Id([1:H, H * ones(1, padH)], [1:W, W * ones(1, padW)]);
else
    Ip = Id;
end

% ---- per-tile clipped mappings -----------------------------------------
numPixInTile = tileH * tileW;
minClipLimit = ceil(numPixInTile / nBins);
clipLimit = minClipLimit + round(p.ClipLimit * (numPixInTile - minClipLimit));

mappings = zeros(numTiles(1), numTiles(2), nBins);
edges = linspace(0, 1, nBins + 1);
edges(end) = Inf;                        % make the last bin inclusive

for ti = 1:numTiles(1)
    for tj = 1:numTiles(2)
        rows = (ti - 1) * tileH + (1:tileH);
        cols = (tj - 1) * tileW + (1:tileW);
        tile = Ip(rows, cols);

        counts = histcounts(tile(:), edges);
        counts = drishtiClipHistogram(counts, clipLimit);

        cdf = cumsum(counts) / max(1, sum(counts));
        mappings(ti, tj, :) = reshape(cdf, 1, 1, nBins);
    end
end

% ---- bilinear interpolation between tile mappings ----------------------
binIdx = min(nBins, max(1, floor(Id * nBins) + 1));

% Tile centres, in image coordinates.
rowCentres = ((1:numTiles(1)) - 0.5) * tileH;
colCentres = ((1:numTiles(2)) - 0.5) * tileW;

[cc, rr] = meshgrid(1:W, 1:H);

ri = drishtiLocate(rr, rowCentres);
ci = drishtiLocate(cc, colCentres);

r0 = ri.lo;  r1 = ri.hi;  wr = ri.w;
c0 = ci.lo;  c1 = ci.hi;  wc = ci.w;

v00 = drishtiGather(mappings, r0, c0, binIdx);
v01 = drishtiGather(mappings, r0, c1, binIdx);
v10 = drishtiGather(mappings, r1, c0, binIdx);
v11 = drishtiGather(mappings, r1, c1, binIdx);

top = v00 .* (1 - wc) + v01 .* wc;
bot = v10 .* (1 - wc) + v11 .* wc;
out = top .* (1 - wr) + bot .* wr;

out = min(1, max(0, out));

if wasScaled
    J = drishtiFromUnit(out, inClass);
else
    J = cast(out, inClass);
end
end

% ------------------------------------------------------------------------
function p = drishtiParseArgs(args)
p.ClipLimit = 0.01;
p.NumTiles  = [8 8];
p.NBins     = 256;
for k = 1:2:numel(args)
    name = lower(char(args{k}));
    val  = args{k + 1};
    switch name
        case 'cliplimit'
            p.ClipLimit = min(1, max(0, double(val)));
        case 'numtiles'
            p.NumTiles = max(2, round(double(val)));
            if isscalar(p.NumTiles), p.NumTiles = [p.NumTiles p.NumTiles]; end
        case 'nbins'
            p.NBins = max(2, round(double(val)));
        case {'range', 'distribution', 'alpha'}
            % 'full'/'uniform' defaults are the only ones this shim implements
        otherwise
            error('adapthisteq:badOption', 'Unsupported option: %s', name);
    end
end
end

function counts = drishtiClipHistogram(counts, clipLimit)
%DRISHTICLIPHISTOGRAM  Clip bin counts and redistribute the excess evenly,
% iterating because redistribution can push bins back over the limit.
nBins = numel(counts);
excess = sum(max(0, counts - clipLimit));
if excess <= 0, return; end

counts = min(counts, clipLimit);
avgInc = floor(excess / nBins);
upper  = clipLimit - avgInc;

for b = 1:nBins
    if counts(b) < upper
        counts(b) = counts(b) + avgInc;
        excess = excess - avgInc;
    elseif counts(b) < clipLimit
        excess = excess - (clipLimit - counts(b));
        counts(b) = clipLimit;
    end
end

% Scatter whatever is left, one count at a time, over the bins with room.
b = 1;
guard = 0;
while excess > 0 && guard < nBins * 4
    if counts(b) < clipLimit
        counts(b) = counts(b) + 1;
        excess = excess - 1;
    end
    b = b + 1;
    if b > nBins
        b = 1;
        guard = guard + nBins;
    end
end
end

function s = drishtiLocate(coord, centres)
%DRISHTILOCATE  For each coordinate, the two nearest tile centres and the
% interpolation weight between them. Pixels outside the outermost centres
% clamp to the edge tile, which is what stops the border from banding.
n = numel(centres);
if n == 1
    s.lo = ones(size(coord));
    s.hi = ones(size(coord));
    s.w  = zeros(size(coord));
    return
end

spacing = centres(2) - centres(1);
t = (coord - centres(1)) / spacing;        % 0 at the first centre, n-1 at the last
t = min(n - 1, max(0, t));

lo = floor(t);
w  = t - lo;
lo = lo + 1;
hi = min(n, lo + 1);

s.lo = lo;
s.hi = hi;
s.w  = w;
end

function v = drishtiGather(mappings, ri, ci, binIdx)
%DRISHTIGATHER  mappings(ri, ci, binIdx) for every pixel, in one indexing op.
[nr, nc, ~] = size(mappings);
idx = ri + (ci - 1) * nr + (binIdx - 1) * nr * nc;
v = mappings(idx);
end

function [Id, wasScaled] = drishtiToUnit(I)
%DRISHTITOUNIT  Map an image to double in [0,1].
if isinteger(I)
    Id = double(I) / double(intmax(class(I)));
    wasScaled = true;
else
    Id = double(I);
    wasScaled = false;
    if max(Id(:)) > 1 || min(Id(:)) < 0
        Id = min(1, max(0, Id));
    end
end
end

function J = drishtiFromUnit(out, inClass)
%DRISHTIFROMUNIT  Map [0,1] back to the caller's integer class.
J = cast(round(out * double(intmax(inClass))), inClass);
end
