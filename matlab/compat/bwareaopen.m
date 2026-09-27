function BW2 = bwareaopen(BW, p, conn)
%BWAREAOPEN  Remove connected components smaller than p pixels (IPT compat shim).

if nargin < 3 || isempty(conn), conn = 8; end
CC = bwconncomp(BW, conn);
BW2 = false(CC.ImageSize);
for k = 1:CC.NumObjects
    pix = CC.PixelIdxList{k};
    if numel(pix) >= p
        BW2(pix) = true;
    end
end
end
