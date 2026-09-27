# `matlab/compat` — image-processing shims for base MATLAB

Base MATLAB ships only a handful of image functions: `imread`, `imwrite`,
`imresize`, `rgb2gray`, `im2double` and `ind2rgb`. Everything else the DRishti
pipeline needs belongs to the **Image Processing Toolbox**, which is a separate
licensed product.

This folder is a pure-MATLAB implementation of the toolbox functions the
pipeline calls, so the DR screening pipeline runs on a machine that has base
MATLAB alone.

## How it switches on

`matlab/drishtiSetupCompat.m` adds this folder to the path **only when the real
toolbox is absent**. On a licensed machine nothing changes and MathWorks' own
implementations are used. The Python bridge calls it automatically after
`addpath`; from MATLAB, call it yourself:

```matlab
addpath('path/to/drishti/matlab');
drishtiSetupCompat(true);   % true = say which route it took
```

## What is implemented

| Area | Functions |
|---|---|
| Type conversion | `im2uint8`, `im2single` |
| Filtering | `imfilter`, `imgaussfilt`, `imboxfilt`, `medfilt2` |
| Morphology | `strel`, `imerode`, `imdilate`, `imopen`, `imclose`, `imtophat`, `imreconstruct`, `imfill`, `bwperim` |
| Connectivity | `bwconncomp`, `bwlabel`, `bwareaopen`, `bwareafilt`, `regionprops` |
| Skeletons | `bwmorph` (`skel`, `thin`, `endpoints`, `branchpoints`, `clean`), `bwskel` |
| Distance | `bwdist` |
| Thresholding | `imbinarize`, `graythresh` |
| Contrast | `adapthisteq` (CLAHE) |
| Colour | `rgb2lab`, `lab2rgb` |
| Detection | `imfindcircles` |
| Overlays | `imoverlay`, `labeloverlay` |

Only the option combinations the pipeline actually uses are supported. An
unsupported option raises a clear error rather than silently doing something
else.

## Notes on fidelity

* `strel('disk', r)` is the **exact Euclidean disk**. The toolbox defaults to an
  octagonal approximation (`N = 4`), so masks can differ by a pixel at the
  boundary.
* `regionprops` shape measurements use the toolbox's own second-moment formulas,
  including the 1/12 pixel-variance correction, so axis lengths and eccentricity
  match rather than merely correlate.
* `bwdist` is the exact Euclidean transform (Felzenszwalb and Huttenlocher's
  lower-envelope algorithm), not a chamfer approximation.
* `bwmorph`'s skeleton is Zhang-Suen thinning. The toolbox's medial-axis
  skeleton can place a branch slightly differently.
* `imfindcircles` uses its own gradient-voting accumulator rather than the
  toolbox's phase-coding method. `Sensitivity` keeps its usual meaning: the
  score is the share of a circle's circumference that voted for it, and the
  threshold is `1 - Sensitivity`.

## Performance

The pipeline runs on roughly 1024x1024 images, so the slow paths are written
around that:

* Disk morphology decomposes the disk into horizontal chords and uses
  `movmax`/`movmin`, turning an O(r^2) neighbourhood scan into O(r) passes.
* `medfilt2` switches to an intensity-level scan with separable box sums for
  large windows. The background estimate uses a 53x53 window, where gathering
  every shifted copy into one stack would need tens of gigabytes.
* `bwmorph` thinning evaluates its test only on pixels that are still
  foreground, which is a few percent of a vessel mask.

## Tests

```matlab
addpath('path/to/drishti/matlab');
drishtiSetupCompat();
testCompat
```

61 checks, each against a hand-computed expectation rather than against the
toolbox, so the suite is meaningful on a machine with no toolbox to compare
against.
