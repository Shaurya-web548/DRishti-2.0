function B = labeloverlay(A, L, varargin)
%LABELOVERLAY  Blend a label image over a picture (IPT compat shim).
%
%   B = labeloverlay(A, L, 'Colormap', cmap, 'Transparency', t)
%
%   Label 0 is background and stays untouched. Every other label takes its
%   colour from the corresponding row of cmap, blended with the original
%   pixel: t = 0 is opaque colour, t = 1 leaves the image unchanged.

cmap = [];
transparency = 0.5;
included = [];
for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    val  = varargin{k + 1};
    switch name
        case 'colormap'
            cmap = val;
        case 'transparency'
            transparency = min(1, max(0, double(val)));
        case 'includedlabels'
            included = val;
        otherwise
            error('labeloverlay:badOption', 'Unsupported option: %s', name);
    end
end

A = im2uint8(A);
if size(A, 3) == 1
    A = repmat(A, [1 1 3]);
end

L = double(L);
nLabels = max(0, round(max(L(:))));

if isempty(cmap)
    cmap = drishtiDefaultLabelColors(nLabels);
elseif ischar(cmap) || isstring(cmap)
    cmap = drishtiDefaultLabelColors(nLabels);
end
cmap = double(cmap);
if any(cmap(:) > 1), cmap = cmap / 255; end

B = A;
for k = 1:nLabels
    if ~isempty(included) && ~ismember(k, included), continue; end
    m = (L == k);
    if ~any(m(:)), continue; end
    row = cmap(min(k, size(cmap, 1)), :);
    for ch = 1:3
        plane = double(B(:, :, ch));
        tint  = row(ch) * 255;
        plane(m) = transparency * plane(m) + (1 - transparency) * tint;
        B(:, :, ch) = uint8(round(plane));
    end
end
end

function cmap = drishtiDefaultLabelColors(n)
%DRISHTIDEFAULTLABELCOLORS  A readable fallback palette.
base = [1 0 0; 0 1 0; 0 0 1; 1 1 0; 1 0 1; 0 1 1; 1 0.5 0; 0.5 0 1];
if n <= size(base, 1)
    cmap = base(1:max(1, n), :);
else
    cmap = repmat(base, ceil(n / size(base, 1)), 1);
    cmap = cmap(1:n, :);
end
end
