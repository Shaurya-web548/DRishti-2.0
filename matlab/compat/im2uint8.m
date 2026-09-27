function B = im2uint8(A)
%IM2UINT8  Convert an image to uint8 (Image Processing Toolbox compatibility shim).
%
%   logical  -> 0 / 255
%   uint8    -> unchanged
%   uint16   -> scaled by 255/65535
%   int16    -> shifted from [-32768,32767] then scaled
%   single/double -> assumed to lie in [0,1], clipped, then scaled by 255

if islogical(A)
    B = uint8(A) * 255;
elseif isa(A, 'uint8')
    B = A;
elseif isa(A, 'uint16')
    B = uint8(double(A) * (255 / 65535));
elseif isa(A, 'int16')
    B = uint8((double(A) + 32768) * (255 / 65535));
elseif isfloat(A)
    B = uint8(min(1, max(0, double(A))) * 255);
else
    error('im2uint8:badClass', 'Unsupported image class: %s', class(A));
end
end
