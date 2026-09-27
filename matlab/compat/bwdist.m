function [D, IDX] = bwdist(BW)
%BWDIST  Exact Euclidean distance transform (IPT compat shim).
%
%   D(p) is the distance from p to the nearest true pixel of BW.
%   IDX(p) is the linear index of that nearest true pixel.
%
%   Uses Felzenszwalb and Huttenlocher's lower-envelope algorithm: a 1-D
%   squared-distance transform down the columns, then across the rows. That
%   is exact - not a chamfer approximation - and runs in linear time, which
%   matters because the vessel-width map calls it on the full working image.

BW = logical(BW);
[H, W] = size(BW);

if ~any(BW(:))
    D = inf(H, W);
    IDX = zeros(H, W);
    return
end

f = inf(H, W);
f(BW) = 0;

% ---- pass 1: down each column -----------------------------------------
Dcol = zeros(H, W);
Rcol = zeros(H, W);          % source row for each column entry
for c = 1:W
    [Dcol(:, c), Rcol(:, c)] = drishtiDT1D(f(:, c));
end

% ---- pass 2: across each row ------------------------------------------
D2 = zeros(H, W);
IDX = zeros(H, W);
for r = 1:H
    [d, srcCols] = drishtiDT1D(Dcol(r, :));
    D2(r, :) = d;
    idxRow = zeros(1, W);
    valid = srcCols > 0;
    if any(valid)
        cols = srcCols(valid);
        rows = Rcol(r + (cols - 1) * H);      % source row inside each source column
        idxRow(valid) = rows + (cols - 1) * H;
    end
    IDX(r, :) = idxRow;
end

D = sqrt(D2);
end

function [d, arg] = drishtiDT1D(f)
%DRISHTIDT1D  1-D squared distance transform of a sampled function.
%
%   d(q) = min_p ( (q - p)^2 + f(p) ), with arg(q) the minimising p.
%   Computed as the lower envelope of the parabolas rooted at each sample.
%   Samples where f is Inf contribute no parabola.

f = f(:).';
n = numel(f);

finite = find(isfinite(f));
if isempty(finite)
    d = inf(1, n);
    arg = zeros(1, n);
    return
end

v = zeros(1, n + 1);       % parabola locations currently in the envelope
z = zeros(1, n + 2);       % boundaries between consecutive parabolas
k = 1;
v(1) = finite(1);
z(1) = -Inf;
z(2) = Inf;

for q = finite(2:end)
    while true
        p = v(k);
        s = ((f(q) + q ^ 2) - (f(p) + p ^ 2)) / (2 * (q - p));
        if k > 1 && s <= z(k)
            k = k - 1;
        else
            break
        end
    end
    k = k + 1;
    v(k) = q;
    z(k) = s;
    z(k + 1) = Inf;
end

d = zeros(1, n);
arg = zeros(1, n);
k = 1;
for q = 1:n
    while z(k + 1) < q
        k = k + 1;
    end
    p = v(k);
    d(q) = (q - p) ^ 2 + f(p);
    arg(q) = p;
end
end
