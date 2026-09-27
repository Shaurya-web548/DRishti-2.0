function BW2 = bwareafilt(BW, n, varargin)
%BWAREAFILT  Keep the n largest connected components (IPT compat shim).
%
%   BW2 = bwareafilt(BW, n)                 n largest
%   BW2 = bwareafilt(BW, n, 'largest')
%   BW2 = bwareafilt(BW, n, 'smallest')
%   BW2 = bwareafilt(BW, [lo hi])           components whose area is in range

conn = 8;
mode = 'largest';
for k = 1:numel(varargin)
    v = varargin{k};
    if ischar(v) || isstring(v)
        mode = lower(char(v));
    elseif isnumeric(v) && isscalar(v)
        conn = v;
    end
end

CC = bwconncomp(BW, conn);
BW2 = false(CC.ImageSize);
if CC.NumObjects == 0, return; end

areas = cellfun(@numel, CC.PixelIdxList);

if numel(n) == 2
    keep = find(areas >= n(1) & areas <= n(2));
else
    [~, order] = sort(areas, 'descend');
    if strcmp(mode, 'smallest')
        order = flip(order);
    end
    keep = order(1 : min(n, numel(order)));
end

for k = keep(:).'
    BW2(CC.PixelIdxList{k}) = true;
end
end
