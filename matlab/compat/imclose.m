function B = imclose(A, se)
%IMCLOSE  Morphological closing: dilation then erosion (IPT compat shim).
B = drishtiFlatMorph(drishtiFlatMorph(A, se, 'max'), se, 'min');
end
