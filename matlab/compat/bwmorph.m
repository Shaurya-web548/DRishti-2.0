function BW2 = bwmorph(BW, operation, n)
%BWMORPH  Morphological operations on a binary image (IPT compat shim).
%
%   Implements the operations this pipeline uses:
%     'endpoints'     skeleton pixels with exactly one 8-neighbour
%     'branchpoints'  skeleton pixels where three or more branches meet
%     'thin'          Zhang-Suen thinning ('inf' or a repeat count)
%     'skel'          same thinning, run to convergence
%     'clean'         remove isolated pixels
%
%   Everything works off the list of foreground pixels rather than the whole
%   frame. A vessel mask is a few percent foreground, so gathering the eight
%   neighbours by index arithmetic costs a fraction of what shifting eight
%   full-size copies per iteration would, and thinning a fundus image drops
%   from tens of seconds to well under one.
%
%   Branch points use a crossing-number test on the 8-neighbourhood rather
%   than a raw neighbour count, so a pixel sitting on a thick diagonal is
%   not mistaken for a junction.

if nargin < 3 || isempty(n), n = 1; end
if (ischar(n) || isstring(n)) && strcmpi(char(n), 'inf'), n = Inf; end

BW = logical(BW);
operation = lower(char(operation));

switch operation
    case 'endpoints'
        [nb, ~, idx, sz] = drishtiNeighbourStats(BW);
        BW2 = drishtiScatter(idx(nb == 1), sz);

    case 'branchpoints'
        [nb, cn, idx, sz] = drishtiNeighbourStats(BW);
        BW2 = drishtiScatter(idx(nb >= 3 & cn >= 3), sz);

    case {'thin', 'skel'}
        if strcmp(operation, 'skel'), n = Inf; end
        BW2 = drishtiZhangSuen(BW, n);

    case 'clean'
        [nb, ~, idx, sz] = drishtiNeighbourStats(BW);
        BW2 = drishtiScatter(idx(nb > 0), sz);

    otherwise
        error('bwmorph:unsupported', ...
              'This compatibility shim does not implement the %s operation.', operation);
end
end

% ------------------------------------------------------------------------
function [nb, cn, idx, sz] = drishtiNeighbourStats(BW)
%DRISHTINEIGHBOURSTATS  Neighbour count and crossing number for every
% foreground pixel, plus those pixels' linear indices in the original image.
[Bp, idxP, sz] = drishtiPadForNeighbours(BW);
ring = drishtiRingValues(Bp, idxP, size(Bp, 1));

nb = sum(ring, 2);

% 0-to-1 transitions around the ring: a simple arc gives 2, a junction 3+.
nxt = ring(:, [2:8, 1]);
cn = sum(~ring & nxt, 2);

idx = drishtiUnpadIndex(idxP, size(Bp, 1), sz);
end

function [Bp, idxP, sz] = drishtiPadForNeighbours(BW)
%DRISHTIPADFORNEIGHBOURS  One-pixel false border, so neighbour arithmetic
% never runs off the array and no bounds checks are needed.
sz = size(BW);
Bp = false(sz(1) + 2, sz(2) + 2);
Bp(2:end-1, 2:end-1) = BW;
idxP = find(Bp);
end

function ring = drishtiRingValues(Bp, idxP, Hp)
%DRISHTIRINGVALUES  The eight neighbours of each pixel, in clockwise ring
% order starting north. Columns are N, NE, E, SE, S, SW, W, NW.
offsets = [-1, -1 + Hp, Hp, 1 + Hp, 1, 1 - Hp, -Hp, -1 - Hp];
ring = false(numel(idxP), 8);
for k = 1:8
    ring(:, k) = Bp(idxP + offsets(k));
end
end

function idx = drishtiUnpadIndex(idxP, Hp, sz)
%DRISHTIUNPADINDEX  Padded linear indices back to original linear indices.
rp = mod(idxP - 1, Hp) + 1;
cp = floor((idxP - 1) / Hp) + 1;
idx = (rp - 1) + (cp - 2) * sz(1);
end

function BW = drishtiScatter(idx, sz)
%DRISHTISCATTER  Build a mask from a list of linear indices.
BW = false(sz);
BW(idx) = true;
end

function BW = drishtiZhangSuen(BW, maxIter)
%DRISHTIZHANGSUEN  Zhang-Suen thinning to an 8-connected skeleton.
%
%   Each iteration is two sub-passes. Both evaluate the deletion test only
%   on the pixels that are still foreground, and that set shrinks as the
%   shape thins, so later iterations are cheaper than earlier ones.

[Bp, ~, sz] = drishtiPadForNeighbours(BW);
Hp = size(Bp, 1);

iter = 0;
while iter < maxIter
    iter = iter + 1;
    changedAny = false;

    for subIter = 1:2
        idxP = find(Bp);
        if isempty(idxP), break; end

        ring = drishtiRingValues(Bp, idxP, Hp);
        P2 = ring(:, 1);  P3 = ring(:, 2);  P4 = ring(:, 3);  P5 = ring(:, 4);
        P6 = ring(:, 5);  P7 = ring(:, 6);  P8 = ring(:, 7);  P9 = ring(:, 8);

        B = sum(ring, 2);                       % neighbour count

        nxt = ring(:, [2:8, 1]);
        A = sum(~ring & nxt, 2);                % 0-to-1 transitions

        if subIter == 1
            c1 = ~(P2 & P4 & P6);
            c2 = ~(P4 & P6 & P8);
        else
            c1 = ~(P2 & P4 & P8);
            c2 = ~(P2 & P6 & P8);
        end

        del = (B >= 2) & (B <= 6) & (A == 1) & c1 & c2;
        if any(del)
            Bp(idxP(del)) = false;
            changedAny = true;
        end
    end

    if ~changedAny, break; end
end

BW = Bp(2:end-1, 2:end-1);
BW = reshape(BW, sz);
end
