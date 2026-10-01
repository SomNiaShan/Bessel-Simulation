function values = bessel_parse_z_planes(text)
%BESSEL_PARSE_Z_PLANES Parse numbers without evaluating MATLAB expressions.
if ~(ischar(text) || (isstring(text) && isscalar(text)))
    error('Bessel:ZPlan:InvalidExtraPlane', 'Extra planes must be supplied as text.');
end
text = strtrim(char(text));
if isempty(text), values = zeros(1,0); return; end
tokens = regexp(text,'[,;\s]+','split');
number = '^[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?$';
if any(cellfun(@(token) isempty(regexp(token,number,'once')),tokens))
    error('Bessel:ZPlan:InvalidExtraPlane', 'Use numbers separated by commas, semicolons, or spaces; expressions are not allowed.');
end
values = cellfun(@str2double,tokens);
if any(~isfinite(values))
    error('Bessel:ZPlan:InvalidExtraPlane', 'Extra planes must be finite.');
end
end
