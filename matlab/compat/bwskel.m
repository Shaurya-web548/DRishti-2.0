function out = bwskel(BW, varargin)
%BWSKEL  Skeleton of a binary image, with short spurs pruned (IPT compat shim).
%
%   out = bwskel(BW)
%   out = bwskel(BW, 'MinBranchLength', n)
%
%   Thins to an 8-connected skeleton, then repeatedly drops terminal branches
%   shorter than n pixels. Pruning runs a few rounds because removing one
%   spur can expose another behind it.

minBranchLength = 0;
for k = 1:2:numel(varargin)
    if strcmpi(char(varargin{k}), 'minbranchlength')
        minBranchLength = varargin{k + 1};
    end
end

BW = logical(BW);
skel = bwmorph(BW, 'skel', Inf);

if minBranchLength > 0
    for round = 1:5
        pruned = drishtiPruneSpurs(skel, minBranchLength);
        if isequal(pruned, skel), break; end
        skel = pruned;
    end
end

out = skel;
end

function skel = drishtiPruneSpurs(skel, minLen)
%DRISHTIPRUNESPURS  Remove terminal branches shorter than minLen.
%
%   Cutting the branch points apart splits the skeleton into simple arcs.
%   An arc that still carries an endpoint is terminal, so if it is also
%   shorter than the threshold it is a spur and gets deleted.

bp = bwmorph(skel, 'branchpoints');
ep = bwmorph(skel, 'endpoints');

segments = skel & ~bp;
CC = bwconncomp(segments, 8);

for k = 1:CC.NumObjects
    pix = CC.PixelIdxList{k};
    if numel(pix) >= minLen, continue; end
    if any(ep(pix))
        skel(pix) = false;
    end
end

% A branch point left with fewer than two surviving arms is no longer a
% junction; keep it only if it still connects something.
skel = bwmorph(skel, 'clean') | (bp & skel);
end
