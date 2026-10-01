function [fieldOutput, diagnostic] = bessel_collins_plane(fieldInput, gridInput, gridOutput, ...
        matrixABCD, wavelengthMm, opticalPathMm, sourcePhase)
%BESSEL_COLLINS_PLANE Scalar paraxial propagation with physical output sampling.
% ABCD acts on [x; n*theta], so a distance d in index n has B=d/n.
% The field is the complete complex amplitude; the returned phase must be
% retained if another optical element or propagation follows.

if nargin < 7
    sourcePhase = [];
end
A = matrixABCD(1,1); B = matrixABCD(1,2);
C = matrixABCD(2,1); D = matrixABCD(2,2);
if any(~isfinite(matrixABCD(:))) || abs(det(matrixABCD)-1) > 1e-8
    error('ABCD matrix must be finite and have unit determinant.');
end
if ~isscalar(wavelengthMm) || wavelengthMm <= 0
    error('wavelengthMm must be positive.');
end
if isempty(sourcePhase)
    sourcePhase = angle(fieldInput);
end
k0 = 2*pi/wavelengthMm;
diagnostic = struct('A', A, 'B', B, 'C', C, 'D', D, ...
    'inputPhaseStepRad', 0, 'method', 'collinsCZT');

if abs(B) <= 1e-10*max([1, abs(A), abs(D)])
    if abs(A) < eps
        error('Singular imaging matrix.');
    end
    [xOut, yOut] = meshgrid(gridOutput.xValuesMm, gridOutput.yValuesMm);
    xSource = xOut/A;
    ySource = yOut/A;
    fieldOutput = interp2(gridInput.xValuesMm, gridInput.yValuesMm, fieldInput, ...
        xSource, ySource, 'linear', 0) .* ...
        exp(1i*k0*C/(2*A)*(xOut.^2+yOut.^2) + 1i*k0*opticalPathMm)/abs(A);
    diagnostic.method = 'imaging';
    return;
end

sourceChirp = k0*A/(2*B) * (gridInput.x.^2+gridInput.y.^2);
totalInputPhase = sourcePhase + sourceChirp;
inputPower = abs(fieldInput).^2;
active = inputPower > max(inputPower(:))*1e-4;
phaseStepX = abs(diff(totalInputPhase, 1, 2));
phaseStepY = abs(diff(totalInputPhase, 1, 1));
activeX = active(:,1:end-1) & active(:,2:end);
activeY = active(1:end-1,:) & active(2:end,:);
if any(activeX(:))
    diagnostic.inputPhaseStepRad = max(phaseStepX(activeX));
end
if any(activeY(:))
    diagnostic.inputPhaseStepRad = max(diagnostic.inputPhaseStepRad, max(phaseStepY(activeY)));
end
if diagnostic.inputPhaseStepRad >= pi
    sourceStepX = abs(diff(sourcePhase,1,2));
    sourceStepY = abs(diff(sourcePhase,1,1));
    sourceStep = 0;
    if any(activeX(:)), sourceStep = max(sourceStep,max(sourceStepX(activeX))); end
    if any(activeY(:)), sourceStep = max(sourceStep,max(sourceStepY(activeY))); end
    equivalentDistance = B/A;
    if abs(A) > 1e-12 && sourceStep < pi
        [nearImageField, lostPowerFraction] = localParaxialSourcePropagation(fieldInput,gridInput, ...
            wavelengthMm,equivalentDistance);
        if lostPowerFraction > 1e-3
            error(['Near-image decomposition loses %.3g%% of power outside the source ' ...
                'window. Increase source sizeMm (and N to preserve dx).'], ...
                100*lostPowerFraction);
        end
        [xOut,yOut] = meshgrid(gridOutput.xValuesMm,gridOutput.yValuesMm);
        fieldOutput = interp2(gridInput.xValuesMm,gridInput.yValuesMm,nearImageField, ...
            xOut/A,yOut/A,'linear',0) .* ...
            exp(1i*k0*C/(2*A)*(xOut.^2+yOut.^2)+1i*k0*opticalPathMm)/abs(A);
        diagnostic.method = 'nearImageASM';
        return;
    end
    error(['Collins input integral is undersampled (phase step %.3g rad >= pi), ' ...
        'and a near-image decomposition is not valid. Increase source N or change the optical sampling.'], ...
        diagnostic.inputPhaseStepRad);
end

chirpedInput = fieldInput .* exp(1i*sourceChirp);
fxOutput = gridOutput.xValuesMm/(wavelengthMm*B);
fyOutput = gridOutput.yValuesMm/(wavelengthMm*B);
% Negative B reverses both frequency axes. The CZT accepts ascending axes.
flipX = fxOutput(2) < fxOutput(1);
flipY = fyOutput(2) < fyOutput(1);
if flipX, fxOutput = fliplr(fxOutput); end
if flipY, fyOutput = fliplr(fyOutput); end
transformed = bessel_czt2_physical(chirpedInput, gridInput.xValuesMm, ...
    gridInput.yValuesMm, fxOutput, fyOutput);
if flipX, transformed = fliplr(transformed); end
if flipY, transformed = flipud(transformed); end
fieldOutput = transformed .* exp(1i*k0*(D/(2*B)* ...
    (gridOutput.x.^2+gridOutput.y.^2) + opticalPathMm)) / (1i*wavelengthMm*B);
end

function [propagated,lostPowerFraction] = localParaxialSourcePropagation(field,grid,wavelengthMm,reducedDistance)
nSource = grid.N;
nPadded = 2*nSource-mod(nSource,2);
offset = floor((nPadded-nSource)/2);
padded = zeros(nPadded,nPadded,'like',field);
padded(offset+(1:nSource),offset+(1:nSource)) = field;
frequency = (-floor(nPadded/2):ceil(nPadded/2)-1)/(nPadded*grid.dxMm);
[fx,fy] = meshgrid(frequency,frequency);
transfer = exp(-1i*pi*wavelengthMm*reducedDistance*(fx.^2+fy.^2));
fullPlane = ifft2(ifftshift(fftshift(fft2(padded)).*transfer));
propagated = fullPlane(offset+(1:nSource),offset+(1:nSource));
lostPowerFraction = max(0,1-sum(abs(propagated).^2,'all')/ ...
    max(sum(abs(fullPlane).^2,'all'),realmin));
end
