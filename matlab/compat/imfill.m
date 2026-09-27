function BW2 = imfill(BW, varargin)
%IMFILL  Fill holes in a binary image (Image Processing Toolbox compat shim).
%
%   BW2 = imfill(BW, 'holes')
%   BW2 = imfill(BW, conn, 'holes')
%
%   A hole is a background component that does not reach the image border,
%   so this labels the background and fills every component that stays
%   inside the frame.

conn = 8;
doHoles = false;
for k = 1:numel(varargin)
    v = varargin{k};
    if (ischar(v) || isstring(v)) && strcmpi(char(v), 'holes')
        doHoles = true;
    elseif isnumeric(v) && isscalar(v)
        conn = v;
    end
end

if ~doHoles
    error('imfill:unsupported', ...
          'This compatibility shim only implements imfill(BW, ''holes'').');
end

BW = logical(BW);
[H, W] = size(BW);

% Background connectivity is the dual of the foreground connectivity.
if conn == 8, bgConn = 4; else, bgConn = 8; end

CC = bwconncomp(~BW, bgConn);
BW2 = BW;
for k = 1:CC.NumObjects
    pix = CC.PixelIdxList{k};
    rows = mod(pix - 1, H) + 1;
    cols = floor((pix - 1) / H) + 1;
    touchesBorder = any(rows == 1 | rows == H | cols == 1 | cols == W);
    if ~touchesBorder
        BW2(pix) = true;
    end
end
end
