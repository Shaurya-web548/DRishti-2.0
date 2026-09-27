function out = imoverlay(I, mask, color)
%IMOVERLAY  Burn a colour into an image wherever a mask is true (IPT compat shim).
%
%   out = imoverlay(I, mask, color)
%
%   color may be a 1-by-3 triple in [0,1], a uint8 triple, or a colour name
%   such as 'red'. The result is always uint8 RGB, which is what the toolbox
%   version returns for uint8 input.

if nargin < 3 || isempty(color), color = [1 0 0]; end
color = drishtiColorTriple(color);

I = im2uint8(I);
if size(I, 3) == 1
    I = repmat(I, [1 1 3]);
end

mask = logical(mask);
if ~isequal(size(mask), [size(I, 1) size(I, 2)])
    error('imoverlay:sizeMismatch', 'The mask must match the image size.');
end

out = I;
for k = 1:3
    ch = out(:, :, k);
    ch(mask) = uint8(round(color(k) * 255));
    out(:, :, k) = ch;
end
end
