function B = drishtiCastLike(B, inClass)
%DRISHTICASTLIKE  Return a double result in the caller's original image class,
% rounding and saturating for integer types the way the toolbox does.

switch inClass
    case 'double'
        % nothing to do
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
