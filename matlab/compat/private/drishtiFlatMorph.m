function B = drishtiFlatMorph(A, se, op)
%DRISHTIFLATMORPH  Flat grayscale/binary erosion or dilation.
%
%   op is 'max' (dilation) or 'min' (erosion).
%
%   Disk structuring elements are decomposed into horizontal chords: for each
%   row offset dy the disk covers a run of 2*w+1 columns, and a running
%   max/min over that run costs O(1) per pixel via movmax/movmin. That turns
%   an O(r^2) neighbourhood scan into O(r) passes, which is what makes the
%   large background disks on a 1024 px fundus image tractable.

[se, isDisk, R] = drishtiNormaliseSE(se);

inClass   = class(A);
isLogical = islogical(A);
Ad = double(A);
[H, W] = size(Ad);

if strcmp(op, 'max')
    fill = -Inf;
    mov  = @(X, k) movmax(X, k, 2);
    comb = @max;
else
    fill = Inf;
    mov  = @(X, k) movmin(X, k, 2);
    comb = @min;
end

if isDisk
    if R == 0, B = A; return; end
    dys = -R : R;
    ws  = floor(sqrt(max(0, R ^ 2 - dys .^ 2)));

    P = [repmat(fill, H, R), Ad, repmat(fill, H, R)];
    out = repmat(fill, H, W);

    for w = unique(ws)
        M = mov(P, 2 * w + 1);
        M = M(:, R + (1 : W));
        for dy = dys(ws == w)
            rows = max(1, 1 + dy) : min(H, H + dy);
            if isempty(rows), continue; end
            out(rows, :) = comb(out(rows, :), M(rows - dy, :));
        end
    end
else
    nhood = se;
    [nh, nw] = size(nhood);
    pr = floor(nh / 2);
    pc = floor(nw / 2);
    P = drishtiPad(Ad, [pr pc], fill);
    out = repmat(fill, H, W);
    [ii, jj] = find(nhood);
    for k = 1:numel(ii)
        di = ii(k) - 1;
        dj = jj(k) - 1;
        out = comb(out, P(di + (1:H), dj + (1:W)));
    end
end

out(~isfinite(out) & out == fill) = 0;   % windows that never saw a real pixel

if isLogical
    B = out > 0.5;
else
    B = drishtiCastLike(out, inClass);
end
end

function [nhood, isDisk, R] = drishtiNormaliseSE(se)
%DRISHTINORMALISESE  Accept a strel struct or a raw neighbourhood matrix.
isDisk = false;
R = 0;
if isstruct(se)
    if isfield(se, 'Shape') && strcmp(se.Shape, 'disk') && ~isempty(se.Radius)
        isDisk = true;
        R = se.Radius;
        nhood = se.Neighborhood;
        return
    end
    nhood = se.Neighborhood;
elseif isobject(se)
    nhood = se.Neighborhood;   % a real IPT strel, if one is ever passed in
else
    nhood = logical(se);
end
end
