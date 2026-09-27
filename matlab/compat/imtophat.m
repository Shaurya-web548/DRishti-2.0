function B = imtophat(A, se)
%IMTOPHAT  Top-hat transform: A minus its opening (IPT compat shim).
%
%   Keeps bright structures smaller than the structuring element, which is
%   how the pipeline isolates exudates and microaneurysms.
opened = imopen(A, se);
if islogical(A)
    B = A & ~opened;
else
    inClass = class(A);
    B = drishtiCastLike(double(A) - double(opened), inClass);
end
end
