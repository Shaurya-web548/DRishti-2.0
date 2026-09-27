function P = bwperim(BW, conn)
%BWPERIM  Perimeter pixels of binary objects (IPT compat shim).
%
%   A foreground pixel is on the perimeter when at least one of its
%   neighbours is background.

if nargin < 2 || isempty(conn), conn = 4; end
BW = logical(BW);

if conn == 4
    se = strel('arbitrary', [0 1 0; 1 1 1; 0 1 0]);
else
    se = strel('square', 3);
end

P = BW & ~imerode(BW, se);
end
