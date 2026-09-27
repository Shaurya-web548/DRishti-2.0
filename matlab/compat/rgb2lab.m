function lab = rgb2lab(rgb, varargin)
%RGB2LAB  Convert sRGB to CIE L*a*b* (Image Processing Toolbox compat shim).
%
%   lab = rgb2lab(rgb)
%
%   Assumes sRGB input and a D65 white point, matching the toolbox defaults.
%   L* comes back in [0,100]; a* and b* are roughly in [-128,127].

rgbD = double(rgb);
if isinteger(rgb)
    rgbD = rgbD / double(intmax(class(rgb)));
end
rgbD = min(1, max(0, rgbD));

[H, W, C] = size(rgbD);
if C ~= 3
    error('rgb2lab:badInput', 'Input must be an M-by-N-by-3 RGB image.');
end

P = reshape(rgbD, [], 3);

% ---- sRGB companding -> linear RGB -------------------------------------
lin = P;
thresh = 0.04045;
below = P <= thresh;
lin(below)  = P(below) / 12.92;
lin(~below) = ((P(~below) + 0.055) / 1.055) .^ 2.4;

% ---- linear RGB -> XYZ (sRGB primaries, D65) ---------------------------
M = [0.4124564 0.3575761 0.1804375
     0.2126729 0.7151522 0.0721750
     0.0193339 0.1191920 0.9503041];
XYZ = lin * M.';

% ---- XYZ -> L*a*b* -----------------------------------------------------
white = [0.95047 1.00000 1.08883];          % D65
XYZn = XYZ ./ white;

f = drishtiLabF(XYZn);

L = 116 * f(:, 2) - 16;
a = 500 * (f(:, 1) - f(:, 2));
b = 200 * (f(:, 2) - f(:, 3));

lab = reshape([L a b], H, W, 3);
end

function f = drishtiLabF(t)
%DRISHTILABF  The CIE L*a*b* nonlinearity, with its linear segment near zero.
delta = 6 / 29;
f = zeros(size(t));
big = t > delta ^ 3;
f(big)  = t(big) .^ (1/3);
f(~big) = t(~big) / (3 * delta ^ 2) + 4 / 29;
end
