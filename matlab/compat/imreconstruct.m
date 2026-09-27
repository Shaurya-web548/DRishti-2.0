function J = imreconstruct(marker, mask, conn)
%IMRECONSTRUCT  Morphological reconstruction by dilation (IPT compat shim).
%
%   J = imreconstruct(MARKER, MASK)
%   J = imreconstruct(MARKER, MASK, CONN)      CONN is 4 or 8
%
%   For binary inputs - the hysteresis threshold the vessel segmentation
%   relies on - reconstruction is exactly "keep the MASK components that
%   contain at least one MARKER pixel", so this takes the connected-component
%   route instead of iterating dilations.
%
%   Grayscale inputs fall back to iterated geodesic dilation, capped so a
%   pathological input cannot spin forever.

if nargin < 3 || isempty(conn), conn = 8; end

if islogical(marker) && islogical(mask)
    CC = bwconncomp(mask, conn);
    J = false(size(mask));
    for k = 1:CC.NumObjects
        pix = CC.PixelIdxList{k};
        if any(marker(pix))
            J(pix) = true;
        end
    end
    return
end

% ---- grayscale reconstruction ------------------------------------------
inClass = class(mask);
m = double(marker);
M = double(mask);
m = min(m, M);

if conn == 4
    se = strel('arbitrary', [0 1 0; 1 1 1; 0 1 0]);
else
    se = strel('square', 3);
end

maxIter = 10 * max(size(M));
for k = 1:maxIter
    prev = m;
    m = min(imdilate(m, se), M);
    if isequal(m, prev), break; end
end

J = drishtiCastPublic(m, inClass);
end

function B = drishtiCastPublic(B, inClass)
%DRISHTICASTPUBLIC  Local copy of the cast helper (private/ is not on the
% path for local functions in this file).
switch inClass
    case 'double'
    case 'single'
        B = single(B);
    case 'logical'
        B = B > 0.5;
    otherwise
        lo = double(intmin(inClass));
        hi = double(intmax(inClass));
        B  = cast(min(hi, max(lo, round(B))), inClass);
end
end
