function [propagation, observationGrid] = bessel_adaptive_propagation(inputModes, sourceGrid, sourcePhase, params,zPlan)
%BESSEL_ADAPTIVE_PROPAGATION Evaluate requested planes on a focused ROI grid.
% Each plane is computed from the full source field through all preceding
% lenses by an ABCD/Collins integral. A displayed ROI never becomes a
% truncated input to a later plane. This backend is scalar and paraxial.

simulation = params.simulation;
if simulation.adaptiveOutputN < 2 || simulation.adaptiveOutputN ~= round(simulation.adaptiveOutputN)
    error('simulation.adaptiveOutputN must be an integer of at least 2.');
end
if simulation.adaptiveOutputSizeMm < 0 || ~isfinite(simulation.adaptiveOutputSizeMm)
    error('simulation.adaptiveOutputSizeMm must be finite and nonnegative.');
end
if simulation.adaptiveOutputSizeMm == 0
    afocalSpacing = params.optics.lens1Enabled && params.optics.lens2Enabled && ...
        abs(params.optics.lens2PositionMm-params.optics.lens1PositionMm- ...
        params.optics.lens1FocalLengthMm-params.optics.lens2FocalLengthMm) < 1e-8;
    if afocalSpacing
        focalRatio = abs(params.optics.lens2FocalLengthMm/params.optics.lens1FocalLengthMm);
        outputSizeMm = sourceGrid.sizeMm*min(1, max(0.002, 2*focalRatio));
    else
        outputSizeMm = sourceGrid.sizeMm;
    end
else
    outputSizeMm = simulation.adaptiveOutputSizeMm;
end
nOut = simulation.adaptiveOutputN;
observationGrid = localGrid(nOut, outputSizeMm);

if nargin < 5
    zPlan = bessel_build_z_plan(params);
end
zValues = zPlan.zValuesMm;
opticalEvents = localEvents(params);
firstLensZ = inf;
for eventIndex = 1:numel(opticalEvents)
    if ~strcmp(opticalEvents(eventIndex).name,'sample')
        firstLensZ = min(firstLensZ,opticalEvents(eventIndex).z);
    end
end
nZ = numel(zValues);

memory = bessel_estimate_adaptive_memory(params,zPlan);
if ~memory.withinBudget
    error('Bessel:Memory:BudgetExceeded', ...
        'Estimated adaptive working memory %.2f GiB exceeds budget %.2f GiB.', ...
        memory.totalGiB,memory.budgetGiB);
end

intensityStack = zeros(nOut, nOut, nZ, 'single');
roiPowerFraction = zeros(1,nZ);
edgePowerFraction = zeros(1,nZ);
largestInputPhaseStepRad = 0;
maxAsmSpectralPowerRemovedFraction = 0;
finalField = [];
sourceIntegral = sum(inputModes.inputIntensity, 'all')*sourceGrid.dxMm*sourceGrid.dyMm;
sourceBorderRows = inputModes.inputIntensity([1:2,end-1:end],:);
sourceBorderColumns = inputModes.inputIntensity(:,[1:2,end-1:end]);
sourceEdgePowerFraction = (sum(sourceBorderRows,'all')+sum(sourceBorderColumns,'all'))/ ...
    max(sum(inputModes.inputIntensity,'all'),realmin);
activeSource = inputModes.inputIntensity > max(inputModes.inputIntensity,[],'all')*1e-4;
activeRadius = hypot(sourceGrid.x,sourceGrid.y);
maxSourceRadiusMm = max(activeRadius(activeSource));
phaseDifferenceX = abs(diff(sourcePhase,1,2));
phaseDifferenceY = abs(diff(sourcePhase,1,1));
activeNeighborsX = activeSource(:,1:end-1) & activeSource(:,2:end);
activeNeighborsY = activeSource(1:end-1,:) & activeSource(2:end,:);
sourceSlopeX = 0;
sourceSlopeY = 0;
if any(activeNeighborsX(:))
    sourceSlopeX = max(phaseDifferenceX(activeNeighborsX))/sourceGrid.dxMm;
end
if any(activeNeighborsY(:))
    sourceSlopeY = max(phaseDifferenceY(activeNeighborsY))/sourceGrid.dyMm;
end
maxSourceReducedAngle = hypot(sourceSlopeX,sourceSlopeY)*params.laser.wavelengthMm/(2*pi);
sourcePhaseStepRad = max(sourceSlopeX*sourceGrid.dxMm,sourceSlopeY*sourceGrid.dyMm);
maxRayAngleDeg = 0;
progressTimer = tic;
lastProgressTime = -inf;
for zIndex = 1:nZ
    [matrixABCD, opticalPathMm] = localSystemMatrix(zValues(zIndex), opticalEvents, params);
    nAtPlane = params.material.backgroundIndex;
    if params.optics.sampleEnabled && zValues(zIndex) >= params.optics.samplePositionMm
        nAtPlane = params.material.sampleIndex;
    end
    reducedAngleBound = abs(matrixABCD(2,1))*maxSourceRadiusMm + ...
        abs(matrixABCD(2,2))*maxSourceReducedAngle;
    maxRayAngleDeg = max(maxRayAngleDeg,rad2deg(atan(reducedAngleBound/nAtPlane)));
    intensity = zeros(nOut,nOut);
    for modeIndex = 1:numel(inputModes.modes)
        mode = inputModes.modes(modeIndex);
        if zValues(zIndex) < firstLensZ || isinf(firstLensZ)
            [field, removedFraction] = localAsmObserve(mode.field, sourceGrid, observationGrid, ...
                zValues(zIndex), params);
            maxAsmSpectralPowerRemovedFraction = max(maxAsmSpectralPowerRemovedFraction,removedFraction);
            diagnostic = struct('inputPhaseStepRad',0);
        else
            [field, diagnostic] = bessel_collins_plane(mode.field, sourceGrid, observationGrid, ...
                matrixABCD, params.laser.wavelengthMm, opticalPathMm, sourcePhase);
        end
        intensity = intensity + mode.weight*abs(field).^2;
        largestInputPhaseStepRad = max(largestInputPhaseStepRad, diagnostic.inputPhaseStepRad);
        if zIndex == nZ && ~inputModes.requiresIncoherentSum
            finalField = field;
        end
    end
    intensityStack(:,:,zIndex) = single(intensity);
    roiIntegral = sum(intensity,'all')*observationGrid.dxMm*observationGrid.dyMm;
    roiPowerFraction(zIndex) = roiIntegral/sourceIntegral;
    edgeRows = intensity([1:2,end-1:end],:);
    edgeColumns = intensity(:,[1:2,end-1:end]);
    edgePowerFraction(zIndex) = (sum(edgeRows,'all')+sum(edgeColumns,'all'))/ ...
        max(sum(intensity,'all'),realmin);
    if isfield(params,'runtimeProgressCallback') && ~isempty(params.runtimeProgressCallback) && ...
            (toc(progressTimer)-lastProgressTime >= 3 || zIndex == nZ)
        params.runtimeProgressCallback(sprintf('Scaled propagation: %d/%d, z=%.6g mm', ...
            zIndex,nZ,zValues(zIndex)));
        lastProgressTime = toc(progressTimer);
    end
end

propagation = struct();
propagation.E3D = [];
propagation.intensity3D = intensityStack;
propagation.finalField = finalField;
propagation.finalIntensity = intensityStack(:,:,end);
propagation.zValuesMm = zValues;
propagation.zPlan = zPlan;
propagation.modeSummaries = inputModes.modeSummaries;
propagation.intensityModel = params.beam.beamQualityModel;
propagation.lens1AppliedAtMm = localEventPosition(opticalEvents,'lens1',simulation.zRangeMm);
propagation.lens2AppliedAtMm = localEventPosition(opticalEvents,'lens2',simulation.zRangeMm);
propagation.sampleAppliedAtMm = localEventPosition(opticalEvents,'sample',simulation.zRangeMm);
propagation.backend = 'adaptiveCollins';
propagation.diagnostics = struct( ...
    'roiPowerFraction', roiPowerFraction, ...
    'edgePowerFraction', edgePowerFraction, ...
    'largestInputPhaseStepRad', largestInputPhaseStepRad, ...
    'maxAsmSpectralPowerRemovedFraction', maxAsmSpectralPowerRemovedFraction, ...
    'estimatedWorkingGiB', memory.totalGiB, ...
    'observationSizeMm', outputSizeMm, ...
    'observationDxMm', observationGrid.dxMm, ...
    'sourceIntegral', sourceIntegral, ...
    'sourceEdgePowerFraction', sourceEdgePowerFraction, ...
    'maxRayAngleEstimateDeg', maxRayAngleDeg, ...
    'sourcePhaseStepRad', sourcePhaseStepRad, ...
    'opticalEvents', opticalEvents, ...
    'model', 'scalar paraxial ABCD; no Fresnel reflection at sample interface');
end

function [observed,removedFraction] = localAsmObserve(input,sourceGrid,observationGrid,z,params)
removedFraction = 0;
if z == 0
    fullPlane = input;
else
    nSource = sourceGrid.N;
    paddedN = 2*nSource-mod(nSource,2);
    offset = floor((paddedN-nSource)/2);
    padded = zeros(paddedN,paddedN,'like',input);
    padded(offset+(1:nSource),offset+(1:nSource)) = input;
    frequencies = (-floor(paddedN/2):ceil(paddedN/2)-1)/ ...
        (paddedN*sourceGrid.dxMm);
    [fx,fy] = meshgrid(frequencies,frequencies);
    kx2ky2 = (2*pi)^2*(fx.^2+fy.^2);
    k0 = 2*pi/params.laser.wavelengthMm;
    n1 = params.material.backgroundIndex;
    backgroundDistance = z;
    sampleDistance = 0;
    if params.optics.sampleEnabled && params.optics.samplePositionMm >= 0 && ...
            z > params.optics.samplePositionMm
        backgroundDistance = params.optics.samplePositionMm;
        sampleDistance = z-backgroundDistance;
    end
    transfer = exp(1i*backgroundDistance*sqrt(complex((k0*n1)^2-kx2ky2)));
    if sampleDistance > 0
        n2 = params.material.sampleIndex;
        transfer = transfer .* exp(1i*sampleDistance*sqrt(complex((k0*n2)^2-kx2ky2)));
    end
    spectrum = fftshift(fft2(padded));
    if params.simulation.bandLimitASM
        radialFrequencySquared = fx.^2+fy.^2;
        backgroundLimit = (n1/params.laser.wavelengthMm)^2;
        propagating = radialFrequencySquared < backgroundLimit;
        shiftFactor = zeros(size(fx));
        shiftFactor(propagating) = backgroundDistance ./ ...
            sqrt(backgroundLimit-radialFrequencySquared(propagating));
        if sampleDistance > 0
            sampleLimit = (params.material.sampleIndex/params.laser.wavelengthMm)^2;
            samplePropagating = radialFrequencySquared < sampleLimit;
            propagating = propagating & samplePropagating;
            shiftFactor(propagating) = shiftFactor(propagating) + sampleDistance ./ ...
                sqrt(sampleLimit-radialFrequencySquared(propagating));
        end
        windowHalfWidthMm = paddedN*sourceGrid.dxMm/2;
        retained = ~propagating | ...
            (abs(fx.*shiftFactor) <= windowHalfWidthMm & ...
             abs(fy.*shiftFactor) <= windowHalfWidthMm);
        removedFraction = sum(abs(spectrum(~retained)).^2,'all') / ...
            max(sum(abs(spectrum).^2,'all'),realmin);
        transfer(~retained) = 0;
    end
    propagated = ifft2(ifftshift(spectrum.*transfer));
    fullPlane = propagated(offset+(1:nSource),offset+(1:nSource));
end
[xQuery,yQuery] = meshgrid(observationGrid.xValuesMm,observationGrid.yValuesMm);
observed = interp2(sourceGrid.xValuesMm,sourceGrid.yValuesMm,fullPlane, ...
    xQuery,yQuery,'linear',0);
end

function grid = localGrid(n, sizeMm)
grid = struct();
grid.N = n;
grid.sizeMm = sizeMm;
grid.dxMm = sizeMm/n;
grid.dyMm = grid.dxMm;
grid.xValuesMm = ((1:n)-n/2)*grid.dxMm;
grid.yValuesMm = grid.xValuesMm;
[grid.x,grid.y] = meshgrid(grid.xValuesMm,grid.yValuesMm);
end

function events = localEvents(params)
events = struct('name',{},'z',{},'focalLengthMm',{});
if params.optics.lens1Enabled
    events(end+1) = struct('name','lens1','z',params.optics.lens1PositionMm, ...
        'focalLengthMm',params.optics.lens1FocalLengthMm);
end
if params.optics.lens2Enabled
    events(end+1) = struct('name','lens2','z',params.optics.lens2PositionMm, ...
        'focalLengthMm',params.optics.lens2FocalLengthMm);
end
if params.optics.sampleEnabled
    events(end+1) = struct('name','sample','z',params.optics.samplePositionMm, ...
        'focalLengthMm',NaN);
end
if isempty(events)
    return;
end
[~,order] = sort([events.z]);
events = events(order);
if any([events.z] < 0)
    error('Adaptive propagation requires all enabled optical events at z >= 0.');
end
end

function [matrixABCD,opticalPathMm] = localSystemMatrix(z,events,params)
matrixABCD = eye(2);
opticalPathMm = 0;
lastZ = 0;
n = params.material.backgroundIndex;
for index = 1:numel(events)
    event = events(index);
    if event.z > z
        break;
    end
    distance = event.z-lastZ;
    matrixABCD = [1,distance/n;0,1]*matrixABCD;
    opticalPathMm = opticalPathMm+n*distance;
    lastZ = event.z;
    if strcmp(event.name,'sample')
        n = params.material.sampleIndex;
    else
        matrixABCD = [1,0;-n/event.focalLengthMm,1]*matrixABCD;
    end
end
distance = z-lastZ;
matrixABCD = [1,distance/n;0,1]*matrixABCD;
opticalPathMm = opticalPathMm+n*distance;
end

function position = localEventPosition(events,name,zMaximum)
position = NaN;
for index = 1:numel(events)
    if strcmp(events(index).name,name) && events(index).z <= zMaximum
        position = events(index).z;
        return;
    end
end
end
