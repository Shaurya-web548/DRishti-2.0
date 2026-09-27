function B = imgaussfilt(A, sigma, varargin)
%IMGAUSSFILT  2-D Gaussian smoothing (Image Processing Toolbox compat shim).
%
%   B = imgaussfilt(A)                        sigma = 0.5
%   B = imgaussfilt(A, sigma)
%   B = imgaussfilt(A, sigma, 'FilterSize', n, 'Padding', p)
%
%   The filter is separable, so this applies two 1-D passes rather than one
%   2-D kernel - same result, far less work on the large fundus images.

if nargin < 2 || isempty(sigma), sigma = 0.5; end
sigma = double(sigma);
if isscalar(sigma), sigma = [sigma sigma]; end

filterSize = [];
padding    = 'replicate';
for k = 1:2:numel(varargin)
    name = lower(char(varargin{k}));
    val  = varargin{k + 1};
    switch name
        case 'filtersize'
            filterSize = val;
            if isscalar(filterSize), filterSize = [filterSize filterSize]; end
        case 'padding'
            padding = val;
        case 'filterdomain'
            % 'spatial' / 'frequency' / 'auto' - always spatial here
        otherwise
            error('imgaussfilt:badOption', 'Unsupported option: %s', name);
    end
end

if isempty(filterSize)
    filterSize = 2 * ceil(2 * sigma) + 1;     % the toolbox default
end
filterSize = max(1, filterSize);

inClass = class(A);
Ad = double(A);

gRow = drishtiGaussKernel(sigma(1), filterSize(1));   % vertical pass
gCol = drishtiGaussKernel(sigma(2), filterSize(2));   % horizontal pass

pr = floor(numel(gRow) / 2);
pc = floor(numel(gCol) / 2);

B = zeros(size(Ad));
for c = 1:size(Ad, 3)
    P = drishtiPad(Ad(:, :, c), [pr pc], padding);
    P = conv2(gRow(:), 1, P, 'same');
    P = conv2(1, gCol(:).', P, 'same');
    B(:, :, c) = P(pr + (1 : size(Ad, 1)), pc + (1 : size(Ad, 2)));
end

B = drishtiCastLike(B, inClass);
end

function g = drishtiGaussKernel(sigma, n)
%DRISHTIGAUSSKERNEL  Normalised 1-D Gaussian of length n.
n = max(1, round(n));
if mod(n, 2) == 0, n = n + 1; end       % keep it centred
r = (n - 1) / 2;
x = -r : r;
if sigma <= 0
    g = zeros(1, n);
    g(r + 1) = 1;
    return
end
g = exp(-(x .^ 2) / (2 * sigma ^ 2));
g = g / sum(g);
end
