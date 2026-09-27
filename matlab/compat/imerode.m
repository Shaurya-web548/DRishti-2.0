function B = imerode(A, se, varargin)
%IMERODE  Flat erosion (Image Processing Toolbox compat shim).
B = drishtiFlatMorph(A, se, 'min');
end
