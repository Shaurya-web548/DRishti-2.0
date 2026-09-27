function B = im2single(A)
%IM2SINGLE  Convert an image to single in [0,1] (IPT compatibility shim).

if isa(A, 'single')
    B = A;
elseif islogical(A)
    B = single(A);
elseif isa(A, 'uint8')
    B = single(A) / 255;
elseif isa(A, 'uint16')
    B = single(A) / 65535;
elseif isa(A, 'int16')
    B = (single(A) + 32768) / 65535;
elseif isa(A, 'double')
    B = single(A);
else
    error('im2single:badClass', 'Unsupported image class: %s', class(A));
end
end
