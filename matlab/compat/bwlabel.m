function [L, n] = bwlabel(BW, conn)
%BWLABEL  Label connected components (Image Processing Toolbox compat shim).

if nargin < 2 || isempty(conn), conn = 8; end
CC = bwconncomp(BW, conn);
L = zeros(CC.ImageSize);
for k = 1:CC.NumObjects
    L(CC.PixelIdxList{k}) = k;
end
n = CC.NumObjects;
end
