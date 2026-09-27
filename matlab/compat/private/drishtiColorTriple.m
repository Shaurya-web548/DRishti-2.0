function c = drishtiColorTriple(color)
%DRISHTICOLORTRIPLE  Normalise a colour name or triple to [r g b] in [0,1].

if ischar(color) || isstring(color)
    switch lower(char(color))
        case {'r', 'red'},     c = [1 0 0];
        case {'g', 'green'},   c = [0 1 0];
        case {'b', 'blue'},    c = [0 0 1];
        case {'c', 'cyan'},    c = [0 1 1];
        case {'m', 'magenta'}, c = [1 0 1];
        case {'y', 'yellow'},  c = [1 1 0];
        case {'w', 'white'},   c = [1 1 1];
        case {'k', 'black'},   c = [0 0 0];
        otherwise
            error('drishtiColorTriple:unknownColor', 'Unknown colour: %s', char(color));
    end
    return
end

c = double(color(:)).';
if isinteger(color) || any(c > 1)
    c = c / 255;
end
c = min(1, max(0, c));
end
