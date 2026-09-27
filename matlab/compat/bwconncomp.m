function CC = bwconncomp(BW, conn)
%BWCONNCOMP  Connected components of a binary image (IPT compat shim).
%
%   CC = bwconncomp(BW)        8-connectivity (the toolbox default for 2-D)
%   CC = bwconncomp(BW, conn)  conn is 4 or 8
%
%   Components are numbered in the order their first pixel appears in
%   column-major scan order, matching the toolbox so that any code indexing
%   into PixelIdxList keeps the same meaning.

if nargin < 2 || isempty(conn), conn = 8; end
BW = logical(BW);
[H, W] = size(BW);

idx = find(BW);
N = numel(idx);

CC = struct('Connectivity', conn, 'ImageSize', [H W], ...
            'NumObjects', 0, 'PixelIdxList', {{}});
if N == 0, return; end

lut = zeros(H * W, 1);
lut(idx) = 1:N;

r = mod(idx - 1, H) + 1;
c = floor((idx - 1) / H) + 1;

% Only forward-looking neighbours are needed; the graph is undirected.
offsets = { 1,     r < H                        % down
            H,     c < W };                     % right
if conn == 8
    offsets = [ offsets
                { H + 1, (r < H) & (c < W)      % down-right
                  H - 1, (r > 1) & (c < W) } ]; % up-right
end

src = [];
dst = [];
for k = 1:size(offsets, 1)
    step  = offsets{k, 1};
    valid = offsets{k, 2};
    if ~any(valid), continue; end
    a = idx(valid);
    b = a + step;
    keep = BW(b);
    src = [src; lut(a(keep))];   %#ok<AGROW>
    dst = [dst; lut(b(keep))];   %#ok<AGROW>
end

G = graph(src, dst, [], N);
bins = conncomp(G).';

% Renumber so component 1 is the one containing the smallest linear index.
firstIdx = accumarray(bins, idx, [], @min);
[~, order] = sort(firstIdx);
remap = zeros(numel(firstIdx), 1);
remap(order) = 1:numel(order);
bins = remap(bins);

CC.NumObjects   = max(bins);
CC.PixelIdxList = accumarray(bins, idx, [], @(v) {sort(v)}).';
end
