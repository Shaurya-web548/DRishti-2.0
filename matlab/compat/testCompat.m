function failures = testCompat()
%TESTCOMPAT  Self-test for the pure-MATLAB image-processing shims.
%
%   failures = testCompat()
%
%   Checks each shim against a hand-computed expectation rather than against
%   the toolbox, so it is meaningful on a machine that has no toolbox to
%   compare with. Prints one line per check and returns the failure count.

drishtiSetupCompat();

results = {};

% ---- type conversion ---------------------------------------------------
results{end+1} = chk('im2uint8 logical',   isequal(im2uint8([true false]), uint8([255 0])));
results{end+1} = chk('im2uint8 double',    isequal(im2uint8([0 0.5 1]), uint8([0 128 255])));
results{end+1} = chk('im2single uint8',    abs(im2single(uint8(255)) - 1) < 1e-6);

% ---- padding and filtering --------------------------------------------
A = magic(5);
results{end+1} = chk('imfilter identity',  isequal(imfilter(A, 1), A));

box = ones(3) / 9;
Fr = imfilter(double(A), box, 'replicate');
results{end+1} = chk('imfilter replicate centre', ...
    abs(Fr(3,3) - mean(mean(double(A(2:4, 2:4))))) < 1e-9);

% A constant image must survive any normalised smoothing unchanged.
C = 7 * ones(20);
results{end+1} = chk('imgaussfilt constant', max(max(abs(imgaussfilt(C, 2) - 7))) < 1e-9);

% A delta smoothed by a Gaussian must stay normalised and peak in the middle.
D = zeros(31); D(16,16) = 1;
Dg = imgaussfilt(D, 3);
results{end+1} = chk('imgaussfilt mass',   abs(sum(Dg(:)) - 1) < 0.02);
results{end+1} = chk('imgaussfilt peak',   Dg(16,16) == max(Dg(:)));

% ---- median filter, both code paths ------------------------------------
M = uint8([1 2 3; 4 200 6; 7 8 9]);
med3 = medfilt2(M, [3 3], 'symmetric');
results{end+1} = chk('medfilt2 small kills spike', med3(2,2) < 200);

Big = uint8(repmat(uint8(100), 60, 60));
Big(30, 30) = 255;
medBig = medfilt2(Big, [11 11], 'symmetric');
results{end+1} = chk('medfilt2 level-scan path', medBig(30,30) == 100);

% ---- threshold ---------------------------------------------------------
bim = [zeros(1,50) ones(1,50)] * 200;
results{end+1} = chk('graythresh separates', graythresh(uint8(bim)) > 0 && graythresh(uint8(bim)) < 1);
results{end+1} = chk('imbinarize explicit', isequal(imbinarize([0.2 0.8], 0.5), [false true]));

% ---- structuring elements and morphology -------------------------------
se3 = strel('disk', 3);
results{end+1} = chk('strel disk size',  isequal(size(se3.Neighborhood), [7 7]));
results{end+1} = chk('strel disk round', se3.Neighborhood(1,1) == false && se3.Neighborhood(4,1) == true);

sq = false(21); sq(8:14, 8:14) = true;
er = imerode(sq, strel('disk', 2));
di = imdilate(sq, strel('disk', 2));
results{end+1} = chk('imerode shrinks',  nnz(er) < nnz(sq));
results{end+1} = chk('imdilate grows',   nnz(di) > nnz(sq));
results{end+1} = chk('erode/dilate dual', nnz(imdilate(er, strel('disk',2))) <= nnz(sq));

% Opening must remove a thin spur but keep the body.
spur = sq; spur(11, 15:19) = true;
op = imopen(spur, strel('disk', 2));
results{end+1} = chk('imopen removes spur', nnz(op(:, 15:19)) < nnz(spur(:, 15:19)));

% Closing must fill a small notch.
notch = sq; notch(11, 11) = false;
cl = imclose(notch, strel('disk', 2));
results{end+1} = chk('imclose fills notch', cl(11,11) == true);

% Grayscale top-hat keeps a small bright dot, drops the broad background.
g = 0.4 * ones(41); g(21, 21) = 1;
th = imtophat(g, strel('disk', 5));
results{end+1} = chk('imtophat isolates dot', th(21,21) > 0.5 && th(3,3) < 1e-6);

% ---- connected components ---------------------------------------------
two = false(10); two(2:3, 2:3) = true; two(7:9, 7:9) = true;
CC = bwconncomp(two, 8);
results{end+1} = chk('bwconncomp count', CC.NumObjects == 2);
results{end+1} = chk('bwconncomp order',  numel(CC.PixelIdxList{1}) == 4);
results{end+1} = chk('bwareaopen drops small', nnz(bwareaopen(two, 5)) == 9);
results{end+1} = chk('bwareafilt keeps largest', nnz(bwareafilt(two, 1)) == 9);

% Diagonal-only contact: one object under 8-connectivity, two under 4.
diag2 = false(6); diag2(2,2) = true; diag2(3,3) = true;
cc8 = bwconncomp(diag2, 8);
cc4 = bwconncomp(diag2, 4);
results{end+1} = chk('conn 8 joins diagonal', cc8.NumObjects == 1);
results{end+1} = chk('conn 4 splits diagonal', cc4.NumObjects == 2);

% ---- regionprops -------------------------------------------------------
blob = false(20); blob(5:9, 5:12) = true;      % 5 rows x 8 cols
st = regionprops(blob, 'Area', 'Centroid', 'BoundingBox', 'Extent');
results{end+1} = chk('regionprops area',   st(1).Area == 40);
results{end+1} = chk('regionprops centroid', ...
    abs(st(1).Centroid(1) - 8.5) < 1e-9 && abs(st(1).Centroid(2) - 7) < 1e-9);
results{end+1} = chk('regionprops bbox',   isequal(st(1).BoundingBox, [4.5 4.5 8 5]));
results{end+1} = chk('regionprops extent', abs(st(1).Extent - 1) < 1e-9);

axes1 = regionprops(blob, 'MajorAxisLength', 'MinorAxisLength', 'Eccentricity');
results{end+1} = chk('regionprops major>minor', ...
    axes1(1).MajorAxisLength > axes1(1).MinorAxisLength);
results{end+1} = chk('regionprops eccentricity range', ...
    axes1(1).Eccentricity >= 0 && axes1(1).Eccentricity <= 1);

% A filled rectangle is its own convex hull, so solidity is 1.
sol = regionprops(blob, 'Solidity');
results{end+1} = chk('regionprops solidity full', abs(sol(1).Solidity - 1) < 0.05);

% Intensity statistics.
I2 = zeros(20); I2(5:9, 5:12) = 0.5; I2(5,5) = 1;
ints = regionprops(blob, I2, 'MeanIntensity', 'MaxIntensity');
results{end+1} = chk('regionprops max intensity', abs(ints(1).MaxIntensity - 1) < 1e-9);
results{end+1} = chk('regionprops mean intensity', ...
    abs(ints(1).MeanIntensity - (0.5 * 39 + 1) / 40) < 1e-9);

% Equivalent diameter of a 40 px region.
eqd = regionprops(blob, 'EquivDiameter');
results{end+1} = chk('regionprops equivdiameter', ...
    abs(eqd(1).EquivDiameter - sqrt(4 * 40 / pi)) < 1e-9);

% ---- fill, perimeter, reconstruct -------------------------------------
ring = false(15); ring(4:11, 4:11) = true; ring(6:9, 6:9) = false;
results{end+1} = chk('imfill holes', nnz(imfill(ring, 'holes')) == 64);

results{end+1} = chk('bwperim smaller than object', nnz(bwperim(blob)) < nnz(blob));
perimMask = bwperim(blob);
results{end+1} = chk('bwperim on edge', all(perimMask(:) <= blob(:)));

marker = false(10); marker(2,2) = true;
maskR  = false(10); maskR(2:3, 2:3) = true; maskR(7:8, 7:8) = true;
rec = imreconstruct(marker, maskR);
results{end+1} = chk('imreconstruct keeps marked', nnz(rec) == 4);

% ---- distance transform -----------------------------------------------
dpt = false(9); dpt(5,5) = true;
Dd = bwdist(dpt);
results{end+1} = chk('bwdist at seed',    Dd(5,5) == 0);
results{end+1} = chk('bwdist orthogonal', abs(Dd(5,8) - 3) < 1e-9);
results{end+1} = chk('bwdist diagonal',   abs(Dd(8,8) - sqrt(18)) < 1e-9);
results{end+1} = chk('bwdist is euclidean', abs(Dd(1,1) - sqrt(32)) < 1e-9);

% ---- skeleton ----------------------------------------------------------
bar = false(21); bar(10:12, 4:18) = true;
sk = bwmorph(bar, 'skel', Inf);
results{end+1} = chk('skeleton thinner',  nnz(sk) < nnz(bar));
ccSk = bwconncomp(sk, 8);
results{end+1} = chk('skeleton connected', ccSk.NumObjects == 1);

line1 = false(21); line1(11, 4:18) = true;
results{end+1} = chk('endpoints of a line', nnz(bwmorph(line1, 'endpoints')) == 2);

tee = false(21); tee(11, 4:18) = true; tee(12:18, 11) = true;
results{end+1} = chk('branchpoint of a tee', nnz(bwmorph(tee, 'branchpoints')) >= 1);

spurT = tee; spurT(10, 16) = true;
results{end+1} = chk('bwskel prunes spur', ...
    nnz(bwskel(spurT, 'MinBranchLength', 6)) <= nnz(bwmorph(spurT, 'skel', Inf)));

% ---- CLAHE -------------------------------------------------------------
flat = 0.5 * ones(64);
flatEq = adapthisteq(flat);
results{end+1} = chk('adapthisteq flat stays in range', ...
    all(all(flatEq >= 0 & flatEq <= 1)));

ramp = repmat(linspace(0.3, 0.7, 64), 64, 1);
eq = adapthisteq(ramp, 'ClipLimit', 0.02, 'NumTiles', [4 4]);
results{end+1} = chk('adapthisteq widens contrast', (max(eq(:)) - min(eq(:))) > (0.7 - 0.3));
results{end+1} = chk('adapthisteq monotone-ish', eq(32, 60) > eq(32, 4));
results{end+1} = chk('adapthisteq size kept', isequal(size(eq), size(ramp)));

% ---- colour round trip -------------------------------------------------
% Four pixels: mid blue, white, black, brown. cat(3,...) keeps the channels
% straight; reshape would interleave them.
rgbIn = uint8(cat(3, [30 255 0 120], [90 255 0 60], [200 255 0 20]));
labOut = rgb2lab(rgbIn);
back = lab2rgb(labOut, 'OutputType', 'uint8');
results{end+1} = chk('rgb2lab white L*', abs(labOut(1,2,1) - 100) < 0.5);
results{end+1} = chk('rgb2lab black L*', abs(labOut(1,3,1)) < 0.5);
results{end+1} = chk('lab round trip', max(abs(double(back(:)) - double(rgbIn(:)))) <= 2);

% ---- overlays ----------------------------------------------------------
base = uint8(zeros(10, 10, 3));
mk = false(10); mk(5,5) = true;
ov = imoverlay(base, mk, [1 0 0]);
results{end+1} = chk('imoverlay paints', ...
    ov(5,5,1) == 255 && ov(5,5,2) == 0 && ov(1,1,1) == 0);

lblIm = zeros(10); lblIm(3,3) = 1;
lo = labeloverlay(uint8(zeros(10,10,3)), lblIm, 'Colormap', [0 1 0], 'Transparency', 0);
results{end+1} = chk('labeloverlay tints label', lo(3,3,2) == 255 && lo(1,1,2) == 0);

% ---- circular Hough ----------------------------------------------------
sz = 200;
[xx, yy] = meshgrid(1:sz, 1:sz);
disc = uint8(255 * double(sqrt((xx - 100).^2 + (yy - 95).^2) <= 60));
[cen, rad] = imfindcircles(disc, [40 80], 'ObjectPolarity', 'bright', 'Sensitivity', 0.92);
foundCircle = ~isempty(cen);
results{end+1} = chk('imfindcircles finds a circle', foundCircle);
if foundCircle
    results{end+1} = chk('imfindcircles centre accurate', ...
        abs(cen(1,1) - 100) <= 6 && abs(cen(1,2) - 95) <= 6);
    results{end+1} = chk('imfindcircles radius accurate', abs(rad(1) - 60) <= 8);
else
    results{end+1} = chk('imfindcircles centre accurate', false);
    results{end+1} = chk('imfindcircles radius accurate', false);
end

% ---- report ------------------------------------------------------------
failures = 0;
for k = 1:numel(results)
    r = results{k};
    if r.pass
        fprintf('  ok    %s\n', r.name);
    else
        fprintf('  FAIL  %s\n', r.name);
        failures = failures + 1;
    end
end
fprintf('\n%d checks, %d failures\n', numel(results), failures);
end

function r = chk(name, condition)
r.name = name;
r.pass = logical(condition) && isscalar(condition);
end
