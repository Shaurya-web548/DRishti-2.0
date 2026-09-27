function BW = imbinarize(I, varargin)
%IMBINARIZE  Threshold a grayscale image (Image Processing Toolbox compat shim).
%
%   BW = imbinarize(I)              global Otsu threshold
%   BW = imbinarize(I, T)           explicit threshold (scalar or per-pixel)
%   BW = imbinarize(I, 'global')    same as imbinarize(I)
%
%   For floating-point input the threshold is taken on the same scale as the
%   data; for integer input it is scaled the way the toolbox does.

Id = double(I);
if isinteger(I)
    scale = double(intmax(class(I)));
else
    scale = 1;
end

if isempty(varargin)
    method = 'global';
    T = [];
else
    v = varargin{1};
    if ischar(v) || isstring(v)
        method = lower(char(v));
        T = [];
        if ~strcmp(method, 'global')
            error('imbinarize:badMethod', ...
                  'This compatibility shim only implements the global method.');
        end
    else
        method = 'explicit';
        T = double(v);
    end
end

switch method
    case 'global'
        T = drishtiOtsu(Id(:)) ;
        BW = Id > T;
    case 'explicit'
        if isscalar(T)
            BW = Id > T * scale;
        else
            BW = Id > double(T) * scale;
        end
end
end
