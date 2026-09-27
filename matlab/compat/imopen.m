function B = imopen(A, se)
%IMOPEN  Morphological opening: erosion then dilation (IPT compat shim).
B = drishtiFlatMorph(drishtiFlatMorph(A, se, 'min'), se, 'max');
end
