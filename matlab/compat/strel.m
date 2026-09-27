function se = strel(shape, varargin)
%STREL  Flat structuring element (Image Processing Toolbox compat shim).
%
%   se = strel('disk', r)        Euclidean disk of radius r
%   se = strel('square', n)
%   se = strel('rectangle', [m n])
%   se = strel('line', len, deg)
%   se = strel('arbitrary', nhood)
%
%   Returned as a struct with a .Neighborhood field. The disk case also
%   records .Radius so imerode/imdilate can use the fast chord decomposition
%   instead of expanding the full neighbourhood.
%
%   Note: the toolbox's strel('disk', r) defaults to an octagonal
%   approximation (N = 4). This shim uses the exact Euclidean disk, which is
%   marginally rounder; lesion and vessel masks differ only at the boundary.

shape = lower(char(shape));
se = struct('Shape', shape, 'Radius', [], 'Neighborhood', []);

switch shape
    case 'disk'
        r = round(varargin{1});
        se.Radius = max(0, r);
        [xx, yy] = meshgrid(-se.Radius : se.Radius, -se.Radius : se.Radius);
        se.Neighborhood = (xx .^ 2 + yy .^ 2) <= se.Radius ^ 2;

    case 'square'
        n = round(varargin{1});
        se.Neighborhood = true(n, n);

    case 'rectangle'
        d = round(varargin{1});
        se.Neighborhood = true(d(1), d(2));

    case 'line'
        len = varargin{1};
        deg = varargin{2};
        se.Neighborhood = drishtiLineNhood(len, deg);

    case 'arbitrary'
        se.Neighborhood = logical(varargin{1});

    otherwise
        error('strel:badShape', ...
              'This compatibility shim supports disk, square, rectangle, line and arbitrary.');
end
end

function nhood = drishtiLineNhood(len, deg)
%DRISHTILINENHOOD  Discrete line of the given length and angle, centred.
len = max(1, round(len));
th = deg * pi / 180;
half = (len - 1) / 2;
t = linspace(-half, half, max(2, len));
xs = round(t * cos(th));
ys = round(-t * sin(th));
r = max(max(abs(xs)), max(abs(ys)));
nhood = false(2 * r + 1, 2 * r + 1);
idx = sub2ind(size(nhood), ys + r + 1, xs + r + 1);
nhood(idx) = true;
end
