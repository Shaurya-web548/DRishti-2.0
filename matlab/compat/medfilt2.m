function B = medfilt2(A, varargin)
%MEDFILT2  2-D median filtering (Image Processing Toolbox compat shim).
%
%   B = medfilt2(A)                  3-by-3 neighbourhood
%   B = medfilt2(A, [m n])
%   B = medfilt2(A, [m n], padopt)   padopt: 'zeros' (default) | 'symmetric'
%
%   Two strategies, picked by window size:
%
%   * Small windows gather the m*n shifted copies into one stack and take the
%     median along the third dimension.
%   * Large windows (the pipeline's background estimate uses 53x53, where a
%     stack would need tens of gigabytes) walk the intensity levels instead.
%     For each level the count of window pixels at or below it comes from a
%     separable box sum, and the median is the first level whose count
%     reaches half the window. Exact, and memory stays flat.

nhood  = [3 3];
padopt = 'zeros';
for k = 1:numel(varargin)
    v = varargin{k};
    if isnumeric(v) && numel(v) == 2
        nhood = v;
    elseif ischar(v) || isstring(v)
        padopt = lower(char(v));
    end
end

m = max(1, round(nhood(1)));
n = max(1, round(nhood(2)));
pr = floor(m / 2);
pc = floor(n / 2);

switch padopt
    case 'zeros',     padMethod = 0;
    case 'symmetric', padMethod = 'symmetric';
    case 'indexed',   padMethod = 0;
    otherwise
        error('medfilt2:badPadopt', 'Unsupported padding option: %s', padopt);
end

inClass = class(A);
Ad = double(A);
[H, W] = size(Ad);

P = drishtiPad(Ad, [pr pc], padMethod);

levels = unique(P(:));
useLevelScan = (m * n > 81) && (numel(levels) <= 1024);

if useLevelScan
    out = zeros(H, W);
    found = false(H, W);
    half = floor((m * n) / 2) + 1;      % rank of the median within the window
    for L = levels(:).'
        C = drishtiBoxSum(double(P <= L), m, n);
        C = C(pr + (1:H), pc + (1:W));
        hit = ~found & (C >= half);
        if any(hit(:))
            out(hit) = L;
            found = found | hit;
            if all(found(:)), break; end
        end
    end
    out(~found) = levels(end);
else
    if m * n > 4096
        error('medfilt2:windowTooLarge', ...
              ['A %d-by-%d window over %d distinct levels is too large for this ' ...
               'compatibility shim.'], m, n, numel(levels));
    end
    stack = zeros(H, W, m * n);
    idx = 0;
    for di = 0 : m - 1
        for dj = 0 : n - 1
            idx = idx + 1;
            stack(:, :, idx) = P(di + (1:H), dj + (1:W));
        end
    end
    out = median(stack, 3);
end

B = drishtiCastLike(out, inClass);
end
