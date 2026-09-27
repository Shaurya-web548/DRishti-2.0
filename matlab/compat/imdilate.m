function B = imdilate(A, se, varargin)
%IMDILATE  Flat dilation (Image Processing Toolbox compat shim).
B = drishtiFlatMorph(A, se, 'max');
end
