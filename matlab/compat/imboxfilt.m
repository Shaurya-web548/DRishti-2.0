function B = imboxfilt(A, filterSize, varargin)
%IMBOXFILT  2-D box filtering (Image Processing Toolbox compat shim).
%
%   B = imboxfilt(A)
%   B = imboxfilt(A, filterSize)
%   B = imboxfilt(A, filterSize, 'NormalizationFactor', f, 'Padding', p)
%
%   filterSize must be odd, scalar or [m n]. The default normalisation makes
%   this a local mean, which is how the neovascularisation check reads it as
%   a vessel-fill fraction.

if nargin < 2 || isempty(filterSize), filterSize = 3; end
filterSize = round(filterSize);
if isscalar(filterSize), filterSize = [filterSize filterSize]; end
if any(mod(filterSize, 2) == 0)
    error('imboxfilt:evenSize', 'The filter size must be odd.');
end

normFactor = 1 / prod(filterSize);
padding = 'replicate';
for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    val  = varargin{k + 1};
    switch name
        case 'normalizationfactor'
            normFactor = double(val);
        case 'padding'
            padding = val;
        otherwise
            error('imboxfilt:badOption', 'Unsupported option: %s', name);
    end
end

m = filterSize(1);
n = filterSize(2);
pr = floor(m / 2);
pc = floor(n / 2);

inClass = class(A);
Ad = double(A);
[H, W, C] = size(Ad);

B = zeros(H, W, C);
for c = 1:C
    P = drishtiPad(Ad(:, :, c), [pr pc], padding);
    S = drishtiBoxSum(P, m, n);
    B(:, :, c) = S(pr + (1:H), pc + (1:W)) * normFactor;
end

B = drishtiCastLike(B, inClass);
end
