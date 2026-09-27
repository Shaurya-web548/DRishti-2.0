function S = drishtiBoxSum(A, m, n)
%DRISHTIBOXSUM  Centred m-by-n moving sum, computed separably.
%
%   Same size as A. Windows that run off the edge sum only the pixels that
%   exist, so callers that need edge handling should pad A first.

S = movsum(A, n, 2);
S = movsum(S, m, 1);
end
