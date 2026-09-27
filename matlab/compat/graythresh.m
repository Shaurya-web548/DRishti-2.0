function [level, em] = graythresh(I)
%GRAYTHRESH  Otsu's global threshold, normalised to [0,1] (IPT compat shim).

Id = double(I);
if isinteger(I)
    scale = double(intmax(class(I)));
else
    scale = 1;
end
[t, em] = drishtiOtsu(Id(:));
level = t / scale;
level = min(1, max(0, level));
end
