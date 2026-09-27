function B = drishtiPad(A, padSize, method)
%DRISHTIPAD  Pad a 2-D (or 3-D) array, like padarray(A, padSize, method, 'both').
%
%   method: 'replicate' | 'symmetric' | 'circular' | numeric constant.
%   padSize is [padRows padCols]; the same padding is added on both sides.

if nargin < 3, method = 0; end
pr = padSize(1);
if numel(padSize) > 1, pc = padSize(2); else, pc = padSize(1); end
if pr == 0 && pc == 0, B = A; return; end

[H, W, ~] = size(A);

if ischar(method) || isstring(method)
    switch lower(char(method))
        case 'replicate'
            ri = min(max((1 - pr : H + pr), 1), H);
            ci = min(max((1 - pc : W + pc), 1), W);
        case 'symmetric'
            ri = drishtiReflectIdx(1 - pr : H + pr, H);
            ci = drishtiReflectIdx(1 - pc : W + pc, W);
        case 'circular'
            ri = mod((1 - pr : H + pr) - 1, H) + 1;
            ci = mod((1 - pc : W + pc) - 1, W) + 1;
        otherwise
            error('drishtiPad:badMethod', 'Unsupported padding method: %s', char(method));
    end
    B = A(ri, ci, :);
else
    B = repmat(cast(method, 'like', A), H + 2 * pr, W + 2 * pc, size(A, 3));
    B(pr + (1:H), pc + (1:W), :) = A;
end
end

function idx = drishtiReflectIdx(idx, n)
%DRISHTIREFLECTIDX  Mirror out-of-range indices back inside 1..n (whole-sample
% symmetric padding, matching padarray's 'symmetric' option).
if n == 1
    idx = ones(size(idx));
    return
end
period = 2 * n;
idx = mod(idx - 1, period);           % 0 .. 2n-1
idx(idx < 0) = idx(idx < 0) + period;
fold = idx >= n;
idx(fold) = period - idx(fold) - 1;   % reflect the upper half back down
idx = idx + 1;
end
