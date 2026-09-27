function rgb = lab2rgb(lab, varargin)
%LAB2RGB  Convert CIE L*a*b* to sRGB (Image Processing Toolbox compat shim).
%
%   rgb = lab2rgb(lab)
%   rgb = lab2rgb(lab, 'OutputType', 'uint8' | 'single' | 'double')
%
%   Inverse of rgb2lab: D65 white point, sRGB primaries and companding.

outputType = 'double';
for k = 1:2:numel(varargin)
    if strcmpi(char(varargin{k}), 'outputtype')
        outputType = lower(char(varargin{k + 1}));
    end
end

labD = double(lab);
[H, W, C] = size(labD);
if C ~= 3
    error('lab2rgb:badInput', 'Input must be an M-by-N-by-3 L*a*b* image.');
end

P = reshape(labD, [], 3);
L = P(:, 1);
a = P(:, 2);
b = P(:, 3);

fy = (L + 16) / 116;
fx = fy + a / 500;
fz = fy - b / 200;

XYZn = [drishtiLabFInv(fx), drishtiLabFInv(fy), drishtiLabFInv(fz)];

white = [0.95047 1.00000 1.08883];          % D65
XYZ = XYZn .* white;

Minv = [ 3.2404542 -1.5371385 -0.4985314
        -0.9692660  1.8760108  0.0415560
         0.0556434 -0.2040259  1.0572252];
lin = XYZ * Minv.';
lin = min(1, max(0, lin));

% ---- linear RGB -> sRGB companding -------------------------------------
srgb = lin;
thresh = 0.0031308;
below = lin <= thresh;
srgb(below)  = 12.92 * lin(below);
srgb(~below) = 1.055 * (lin(~below) .^ (1 / 2.4)) - 0.055;
srgb = min(1, max(0, srgb));

out = reshape(srgb, H, W, 3);

switch outputType
    case 'uint8'
        rgb = uint8(round(out * 255));
    case 'uint16'
        rgb = uint16(round(out * 65535));
    case 'single'
        rgb = single(out);
    otherwise
        rgb = out;
end
end

function t = drishtiLabFInv(f)
%DRISHTILABFINV  Inverse of the CIE L*a*b* nonlinearity.
delta = 6 / 29;
t = zeros(size(f));
big = f > delta;
t(big)  = f(big) .^ 3;
t(~big) = 3 * delta ^ 2 * (f(~big) - 4 / 29);
end
