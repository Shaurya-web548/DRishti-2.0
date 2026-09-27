function [level, effectiveness] = drishtiOtsu(x)
%DRISHTIOTSU  Otsu's threshold on a vector of intensities.
%
%   Returns the threshold on the same scale as the input data, plus Otsu's
%   effectiveness metric (between-class variance over total variance).

x = double(x(:));
x = x(isfinite(x));
if isempty(x)
    level = 0; effectiveness = 0; return
end

lo = min(x);
hi = max(x);
if hi <= lo
    level = lo; effectiveness = 0; return
end

nbins = 256;
edges = linspace(lo, hi, nbins + 1);
counts = histcounts(x, edges);
p = counts / sum(counts);
centers = (edges(1:end-1) + edges(2:end)) / 2;

omega = cumsum(p);                       % class-1 probability at each split
mu    = cumsum(p .* centers);
muT   = mu(end);

denom = omega .* (1 - omega);
sigmaB = zeros(1, nbins);
ok = denom > eps;
sigmaB(ok) = (muT * omega(ok) - mu(ok)) .^ 2 ./ denom(ok);

[maxSigma, idx] = max(sigmaB);
level = centers(idx);

sigmaT = sum(p .* (centers - muT) .^ 2);
if sigmaT > eps
    effectiveness = maxSigma / sigmaT;
else
    effectiveness = 0;
end
end
