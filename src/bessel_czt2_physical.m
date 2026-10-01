function output = bessel_czt2_physical(input, xInputMm, yInputMm, fxOutputInvMm, fyOutputInvMm)
%BESSEL_CZT2_PHYSICAL Evaluate a sampled 2-D Fourier integral on a chosen grid.
% The input coordinates and output frequencies must be uniformly spaced.
% No Signal Processing Toolbox is required. The integral convention is
% F(fx,fy) = integral U(x,y)*exp(-2*pi*i*(fx*x+fy*y)) dx dy.

if size(input, 2) ~= numel(xInputMm) || size(input, 1) ~= numel(yInputMm)
    error('Input field size does not match its physical coordinates.');
end
[dxMm, xInputMm] = localUniformAxis(xInputMm, 'xInputMm');
[dyMm, yInputMm] = localUniformAxis(yInputMm, 'yInputMm');
[~, fxOutputInvMm] = localUniformAxis(fxOutputInvMm, 'fxOutputInvMm');
[~, fyOutputInvMm] = localUniformAxis(fyOutputInvMm, 'fyOutputInvMm');

output = localCztColumns(input, yInputMm, fyOutputInvMm) * dyMm;
output = localCztColumns(output.', xInputMm, fxOutputInvMm).' * dxMm;
end

function output = localCztColumns(input, xInput, fOutput)
nInput = numel(xInput);
nOutput = numel(fOutput);
dx = xInput(2) - xInput(1);
if nOutput == 1
    fStep = 0;
else
    fStep = fOutput(2) - fOutput(1);
end
alpha = dx * fStep;
j = (0:nInput-1).';
ell = (0:nOutput-1).';
m = (-(nInput-1):nOutput-1).';
inputChirp = exp(-2i*pi*(fOutput(1)*dx*j + alpha*j.^2/2));
convolutionChirp = exp(1i*pi*alpha*m.^2);
nFft = 2^nextpow2(2*nInput+nOutput-2);
convolution = ifft(fft(input .* inputChirp, nFft, 1) .* ...
    fft(convolutionChirp, nFft, 1), [], 1);
output = convolution(nInput:nInput+nOutput-1, :) .* ...
    exp(-2i*pi*(fOutput(:)*xInput(1) + alpha*ell.^2/2));
end

function [step, values] = localUniformAxis(values, name)
values = double(values(:).');
if numel(values) < 2 || any(~isfinite(values))
    error('%s must contain at least two finite points.', name);
end
differences = diff(values);
step = differences(1);
if step <= 0 || any(abs(differences-step) > 1e-9*max(1, abs(step)))
    error('%s must be strictly increasing and uniformly spaced.', name);
end
end
