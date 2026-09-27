function B = imfilter(A, h, varargin)
%IMFILTER  N-D filtering of a 2-D image (Image Processing Toolbox compat shim).
%
%   B = imfilter(A, h)                  correlation, zero padding, 'same' size
%   B = imfilter(A, h, 'replicate')     replicate border padding
%   B = imfilter(A, h, 'symmetric')     mirror border padding
%   B = imfilter(A, h, 'circular')      periodic border padding
%   B = imfilter(A, h, 'conv')          convolution instead of correlation
%   B = imfilter(A, h, PADVAL)          constant padding
%
%   Output keeps the class of A, with integer results rounded and saturated,
%   matching the toolbox behaviour the pipeline relies on.

padMethod = 0;
doConv    = false;
for k = 1:numel(varargin)
    v = varargin{k};
    if ischar(v) || isstring(v)
        s = lower(char(v));
        switch s
            case {'replicate', 'symmetric', 'circular'}
                padMethod = s;
            case 'conv'
                doConv = true;
            case 'corr'
                doConv = false;
            case 'same'
                % default, nothing to do
            case 'full'
                error('imfilter:fullUnsupported', ...
                      'This compatibility shim only implements ''same'' output.');
            otherwise
                error('imfilter:badOption', 'Unsupported option: %s', s);
        end
    elseif isnumeric(v) && isscalar(v)
        padMethod = v;
    end
end

inClass = class(A);
Ad = double(A);
h  = double(h);

% imfilter correlates by default; conv2 convolves, so flip the kernel unless
% the caller explicitly asked for convolution.
if ~doConv
    h = rot90(h, 2);
end

[kh, kw] = size(h);
pr = floor(kh / 2);
pc = floor(kw / 2);

B = zeros(size(Ad));
for c = 1:size(Ad, 3)
    P = drishtiPad(Ad(:, :, c), [pr pc], padMethod);
    F = conv2(P, h, 'same');
    % Trim the padding back off. With an even-sized kernel conv2 'same' keeps
    % the lower-right biased window, which is what the toolbox does too.
    B(:, :, c) = F(pr + (1 : size(Ad, 1)), pc + (1 : size(Ad, 2)));
end

B = drishtiCastLike(B, inClass);
end
