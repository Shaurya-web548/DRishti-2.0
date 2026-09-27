function stats = regionprops(input, varargin)
%REGIONPROPS  Measure properties of image regions (IPT compat shim).
%
%   stats = regionprops(BW, properties...)
%   stats = regionprops(CC, properties...)
%   stats = regionprops(L,  properties...)
%   stats = regionprops(___, I, properties...)   with an intensity image
%
%   Supported properties:
%     Area  Centroid  BoundingBox  PixelIdxList  PixelList  EquivDiameter
%     MajorAxisLength  MinorAxisLength  Eccentricity  Orientation
%     ConvexArea  Solidity  Extent  Perimeter
%     MeanIntensity  MaxIntensity  MinIntensity  WeightedCentroid
%
%   Shape measurements use the same second-moment formulas as the toolbox,
%   including its 1/12 pixel-variance correction, so axis lengths and
%   eccentricity match rather than merely correlate.

% ---- work out the region list ------------------------------------------
if isstruct(input) && isfield(input, 'PixelIdxList')
    pixelIdxList = input.PixelIdxList;
    imSize = input.ImageSize;
elseif islogical(input)
    CC = bwconncomp(input, 8);
    pixelIdxList = CC.PixelIdxList;
    imSize = CC.ImageSize;
else
    L = double(input);
    imSize = size(L);
    nLab = max(0, round(max(L(:))));
    pixelIdxList = cell(1, nLab);
    for k = 1:nLab
        pixelIdxList{k} = find(L == k);
    end
end

% ---- split out an optional intensity image and the property names ------
I = [];
props = {};
for k = 1:numel(varargin)
    v = varargin{k};
    if (ischar(v) || isstring(v)) && ~isempty(v)
        props{end + 1} = char(v);
    elseif isnumeric(v) || islogical(v)
        I = double(v);
    elseif iscell(v)
        props = [props, cellfun(@char, v, 'UniformOutput', false)];
    end
end

if isempty(props) || any(strcmpi(props, 'all')) || any(strcmpi(props, 'basic'))
    props = {'Area', 'Centroid', 'BoundingBox'};
end

H = imSize(1);
n = numel(pixelIdxList);
stats = drishtiEmptyStats(props, n);

for k = 1:n
    pix = pixelIdxList{k};
    pix = pix(:);
    rows = mod(pix - 1, H) + 1;
    cols = floor((pix - 1) / H) + 1;
    area = numel(pix);

    for p = 1:numel(props)
        name = lower(props{p});
        switch name
            case 'area'
                stats(k).Area = area;

            case 'centroid'
                stats(k).Centroid = [mean(cols), mean(rows)];

            case 'boundingbox'
                stats(k).BoundingBox = [min(cols) - 0.5, min(rows) - 0.5, ...
                                        max(cols) - min(cols) + 1, ...
                                        max(rows) - min(rows) + 1];

            case 'pixelidxlist'
                stats(k).PixelIdxList = pix;

            case 'pixellist'
                stats(k).PixelList = [cols, rows];

            case 'equivdiameter'
                stats(k).EquivDiameter = sqrt(4 * area / pi);

            case 'extent'
                bw = max(cols) - min(cols) + 1;
                bh = max(rows) - min(rows) + 1;
                stats(k).Extent = area / (bw * bh);

            case {'majoraxislength', 'minoraxislength', 'eccentricity', 'orientation'}
                e = drishtiEllipseFit(cols, rows);
                if isfield(stats, 'MajorAxisLength'), stats(k).MajorAxisLength = e.major; end
                if isfield(stats, 'MinorAxisLength'), stats(k).MinorAxisLength = e.minor; end
                if isfield(stats, 'Eccentricity'),    stats(k).Eccentricity    = e.ecc;   end
                if isfield(stats, 'Orientation'),     stats(k).Orientation     = e.theta; end

            case {'convexarea', 'solidity'}
                ca = drishtiConvexArea(cols, rows);
                if isfield(stats, 'ConvexArea'), stats(k).ConvexArea = ca; end
                if isfield(stats, 'Solidity')
                    if ca > 0
                        stats(k).Solidity = area / ca;
                    else
                        stats(k).Solidity = 1;
                    end
                end

            case 'perimeter'
                stats(k).Perimeter = drishtiPerimeter(pix, imSize);

            case 'meanintensity'
                stats(k).MeanIntensity = mean(I(pix));

            case 'maxintensity'
                stats(k).MaxIntensity = max(I(pix));

            case 'minintensity'
                stats(k).MinIntensity = min(I(pix));

            case 'weightedcentroid'
                w = I(pix);
                sw = sum(w);
                if sw > 0
                    stats(k).WeightedCentroid = [sum(cols .* w) / sw, sum(rows .* w) / sw];
                else
                    stats(k).WeightedCentroid = [mean(cols), mean(rows)];
                end

            otherwise
                error('regionprops:badProperty', ...
                      'This compatibility shim does not implement %s.', props{p});
        end
    end
end
end

% ------------------------------------------------------------------------
function stats = drishtiEmptyStats(props, n)
%DRISHTIEMPTYSTATS  Pre-build the output struct array with every field the
% caller asked for, so indexing into it works even when a region is empty.
fields = cell(1, numel(props));
for p = 1:numel(props)
    fields{p} = drishtiCanonical(props{p});
end
fields = unique(fields, 'stable');

args = cell(1, 2 * numel(fields));
for k = 1:numel(fields)
    args{2 * k - 1} = fields{k};
    args{2 * k}     = [];
end
template = struct(args{:});
if n == 0
    stats = template([]);
else
    stats = repmat(template, n, 1);
end
end

function name = drishtiCanonical(name)
%DRISHTICANONICAL  Map a case-insensitive property name to its toolbox spelling.
known = {'Area', 'Centroid', 'BoundingBox', 'PixelIdxList', 'PixelList', ...
         'EquivDiameter', 'MajorAxisLength', 'MinorAxisLength', 'Eccentricity', ...
         'Orientation', 'ConvexArea', 'Solidity', 'Extent', 'Perimeter', ...
         'MeanIntensity', 'MaxIntensity', 'MinIntensity', 'WeightedCentroid'};
hit = strcmpi(known, name);
if any(hit)
    name = known{find(hit, 1)};
end
end

function e = drishtiEllipseFit(cols, rows)
%DRISHTIELLIPSEFIT  Second-moment ellipse, using the toolbox's formulation
% (normalised central moments plus the 1/12 discrete-pixel correction).
x = cols - mean(cols);
y = -(rows - mean(rows));        % flip so orientation is measured anticlockwise

uxx = sum(x .^ 2) / numel(x) + 1/12;
uyy = sum(y .^ 2) / numel(y) + 1/12;
uxy = sum(x .* y) / numel(x);

common = sqrt((uxx - uyy) ^ 2 + 4 * uxy ^ 2);
e.major = 2 * sqrt(2) * sqrt(uxx + uyy + common);
e.minor = 2 * sqrt(2) * sqrt(max(0, uxx + uyy - common));

if e.major > 0
    e.ecc = 2 * sqrt(max(0, (e.major / 2) ^ 2 - (e.minor / 2) ^ 2)) / e.major;
else
    e.ecc = 0;
end

if uyy > uxx
    num = uyy - uxx + common;
    den = 2 * uxy;
else
    num = 2 * uxy;
    den = uxx - uyy + common;
end
if num == 0 && den == 0
    e.theta = 0;
else
    e.theta = (180 / pi) * atan(num / den);
end
end

function ca = drishtiConvexArea(cols, rows)
%DRISHTICONVEXAREA  Pixel count inside the convex hull of a region.
if numel(cols) < 3
    ca = numel(cols);
    return
end
% Use the pixel corners so a flat or 1-pixel-wide region still has a hull.
px = [cols - 0.5; cols + 0.5; cols - 0.5; cols + 0.5];
py = [rows - 0.5; rows - 0.5; rows + 0.5; rows + 0.5];
try
    h = convhull(px, py);
catch
    ca = numel(cols);   % degenerate (collinear) region
    return
end
hx = px(h);
hy = py(h);

[gx, gy] = meshgrid(min(cols):max(cols), min(rows):max(rows));
inside = inpolygon(gx(:), gy(:), hx, hy);
ca = nnz(inside);
if ca < numel(cols), ca = numel(cols); end
end

function per = drishtiPerimeter(pix, imSize)
%DRISHTIPERIMETER  Boundary pixel count, used only as a coarse shape gate.
mask = false(imSize);
mask(pix) = true;
per = nnz(mask & ~drishtiFlatMorphPublic(mask));
end

function E = drishtiFlatMorphPublic(mask)
%DRISHTIFLATMORPHPUBLIC  3-by-3 erosion via the public shim, since the
% private helper is not visible from this file's local functions.
E = imerode(mask, strel('square', 3));
end
