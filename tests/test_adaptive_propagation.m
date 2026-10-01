function tests = test_adaptive_propagation
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
root = fileparts(fileparts(mfilename('fullpath')));
sourceDir = fullfile(root,'src');
addpath(sourceDir);
testCase.TestData.sourceDir = sourceDir;
end

function teardownOnce(testCase)
rmpath(testCase.TestData.sourceDir);
end

function testPhysicalCztMatchesDirectSummation(testCase)
x = (-3:3)*0.07;
y = (-2:2)*0.11;
fx = -1.3:0.19:0.6;
fy = -0.7:0.23:0.5;
[xx,yy] = meshgrid(x,y);
input = exp(-(xx.^2+yy.^2)) .* exp(1i*(3*xx+2*yy));
actual = bessel_czt2_physical(input,x,y,fx,fy);
expected = zeros(numel(fy),numel(fx));
for row = 1:numel(fy)
    for column = 1:numel(fx)
        expected(row,column) = sum(input.*exp(-2i*pi*(fx(column)*xx+fy(row)*yy)),'all')*0.07*0.11;
    end
end
verifyLessThan(testCase,max(abs(actual-expected),[],'all'),1e-12);
end

function testAdaptiveObservesExactEventAndKeepsSourceGrid(testCase)
params = Bessel_Simulation_app_engine('defaults');
params.simulation.N = 65;
params.simulation.sizeMm = 1;
params.simulation.zRangeMm = 40;
params.simulation.dzMm = 10;
params.simulation.adaptiveOutputN = 64;
params.simulation.adaptiveOutputSizeMm = 0.3;
params.beam.waistRadiusMm = 0.15;
params.beam.beamQualityM2 = 1;
params.phase.axiconRadialCycles = 0;
params.phase.helicalGamma = 0;
params.optics.lens1PositionMm = 10;
params.optics.lens1FocalLengthMm = 20;
params.optics.lens2PositionMm = 34;
params.optics.lens2FocalLengthMm = 4;
params.optics.sampleEnabled = false;
results = Bessel_Simulation_app_engine('run',params);
verifyEqual(testCase,results.grid.N,65);
verifyEqual(testCase,results.observationGrid.N,64);
verifyEqual(testCase,results.propagation.lens2AppliedAtMm,34);
verifyTrue(testCase,any(results.propagation.zValuesMm == 34));
verifyEmpty(testCase,results.propagation.E3D);
verifySize(testCase,results.propagation.intensity3D,[64 64 6]);
verifyTrue(testCase,all(isfinite(results.propagation.intensity3D),'all'));
verifyGreaterThan(testCase,max(results.propagation.intensity3D,[],'all'),0);
end

function testInputPowerCalibrationIgnoresOutputCrop(testCase)
params = Bessel_Simulation_app_engine('defaults');
params.simulation.N = 65;
params.simulation.sizeMm = 1;
params.simulation.zRangeMm = 0;
params.simulation.adaptiveOutputN = 32;
params.simulation.adaptiveOutputSizeMm = 0.15;
params.beam.waistRadiusMm = 0.15;
params.beam.beamQualityM2 = 1;
params.phase.axiconRadialCycles = 0;
params.phase.helicalGamma = 0;
params.optics.lens1Enabled = false;
params.optics.lens2Enabled = false;
params.optics.sampleEnabled = false;
results = Bessel_Simulation_app_engine('run',params);
sourceIntegral = sum(abs(results.inputEnvelope).^2,'all')*results.grid.dxMm^2;
verifyEqual(testCase,results.postprocess.pixelPowerDensityWPerMm2,1/sourceIntegral,'RelTol',1e-12);
verifyLessThan(testCase,results.propagation.diagnostics.roiPowerFraction(end),1);
end

function testAdaptiveCalibrationPreservesAperturePowerLoss(testCase)
params = Bessel_Simulation_app_engine('defaults');
params.simulation.N = 65;
params.simulation.sizeMm = 1;
params.simulation.zRangeMm = 0;
params.simulation.adaptiveOutputN = 65;
params.simulation.adaptiveOutputSizeMm = 1;
params.beam.waistRadiusMm = 0.15;
params.beam.beamQualityM2 = 1;
params.phase.axiconRadialCycles = 0;
params.phase.helicalGamma = 0;
params.optics.lens1Enabled = false;
params.optics.lens2Enabled = false;
params.optics.sampleEnabled = false;
unapertured = Bessel_Simulation_app_engine('run',params);
params.phase.apertureRadiusMm = 0.12;
apertured = Bessel_Simulation_app_engine('run',params);
transmission = apertured.postprocess.apertureTransmission;
verifyLessThan(testCase,transmission,1);
verifyEqual(testCase,apertured.postprocess.pixelPowerDensityWPerMm2* ...
    sum(apertured.inputIntensity,'all')*apertured.grid.dxMm^2,transmission,'RelTol',1e-12);
verifyEqual(testCase,double(apertured.postprocess.onAxisPeakPowerDensityWPerMm2(1)), ...
    double(unapertured.postprocess.onAxisPeakPowerDensityWPerMm2(1)),'RelTol',1e-6);
end

function testFourFImageHasCorrectDemagnificationAndAmplitude(testCase)
params = Bessel_Simulation_app_engine('defaults');
params.simulation.N = 129;
params.simulation.sizeMm = 1;
params.simulation.zRangeMm = 48;
params.simulation.dzMm = 24;
params.simulation.adaptiveOutputN = 129;
params.simulation.adaptiveOutputSizeMm = 0.2;
params.beam.waistRadiusMm = 0.15;
params.beam.beamQualityM2 = 1;
params.phase.axiconRadialCycles = 0;
params.phase.helicalGamma = 0;
params.optics.lens1PositionMm = 20;
params.optics.lens2PositionMm = 44;
params.optics.lens1FocalLengthMm = 20;
params.optics.lens2FocalLengthMm = 4;
params.optics.sampleEnabled = false;
results = Bessel_Simulation_app_engine('run',params);
[xx,yy] = meshgrid(results.observationGrid.xValuesMm);
expected = 25*exp(-2*(xx.^2+yy.^2)/(0.03^2));
relativeError = max(abs(double(results.propagation.finalIntensity)-expected),[],'all')/ ...
    max(expected,[],'all');
verifyLessThan(testCase,relativeError,1e-5);
end

function testObservationGridDoesNotChangePhysicalSource(testCase)
params = Bessel_Simulation_app_engine('defaults');
params.simulation.N = 65;
params.simulation.zRangeMm = 0;
params.simulation.adaptiveOutputN = 32;
params.beam.beamQualityM2 = 1;
params.optics.lens1Enabled = false;
params.optics.lens2Enabled = false;
params.optics.sampleEnabled = false;
params.simulation.adaptiveOutputSizeMm = 0.4;
first = Bessel_Simulation_app_engine('run',params);
params.simulation.adaptiveOutputSizeMm = 0.8;
second = Bessel_Simulation_app_engine('run',params);
verifyEqual(testCase,first.inputField,second.inputField,'AbsTol',0);
verifyEqual(testCase,first.derived.axicon.krRadPerMm, ...
    second.derived.axicon.krRadPerMm,'AbsTol',0);
end

function testAdaptivePropagatesCoherentAndIncoherentHgModes(testCase)
params = Bessel_Simulation_app_engine('defaults');
params.simulation.N = 65;
params.simulation.sizeMm = 1;
params.simulation.zRangeMm = 35;
params.simulation.dzMm = 35;
params.simulation.adaptiveOutputN = 64;
params.simulation.adaptiveOutputSizeMm = 0.3;
params.beam.waistRadiusMm = 0.15;
params.beam.beamQualityM2 = 1.2;
params.phase.axiconRadialCycles = 0;
params.phase.helicalGamma = 0;
params.optics.lens1PositionMm = 10;
params.optics.lens1FocalLengthMm = 20;
params.optics.lens2PositionMm = 34;
params.optics.lens2FocalLengthMm = 4;
params.optics.sampleEnabled = false;

params.beam.beamQualityModel = 'coherentHG';
coherent = Bessel_Simulation_app_engine('run',params);
verifyTrue(testCase,all(isfinite(coherent.propagation.intensity3D),'all'));
verifyNotEmpty(testCase,coherent.propagation.finalField);
verifyEqual(testCase,abs(coherent.propagation.finalField).^2, ...
    double(coherent.propagation.finalIntensity),'RelTol',1e-6);

params.beam.beamQualityModel = 'incoherentHG';
incoherent = Bessel_Simulation_app_engine('run',params);
verifyTrue(testCase,all(isfinite(incoherent.propagation.intensity3D),'all'));
verifyGreaterThan(testCase,max(incoherent.propagation.finalIntensity,[],'all'),0);
verifyEmpty(testCase,incoherent.propagation.finalField);
verifyGreaterThan(testCase,numel(incoherent.propagation.modeSummaries),1);
end

function testTelescopeLockMovesLensAndSample(testCase)
params = Bessel_Simulation_app_engine('defaults');
params.simulation.N = 65;
params.simulation.zRangeMm = 0;
params.beam.beamQualityM2 = 1;
params.optics.lens2FocalLengthMm = 5;
params.optics.layoutMode = 'telescopeLocked';
results = Bessel_Simulation_app_engine('run',params);
verifyEqual(testCase,results.params.optics.lens2PositionMm,605);
verifyEqual(testCase,results.params.optics.samplePositionMm,625);
verifyTrue(testCase,results.derived.optics.isAfocalLayout);
end

function testUnlensedAdaptiveAgreesWithLegacyOnSharedGrid(testCase)
params = Bessel_Simulation_app_engine('defaults');
params.simulation.N = 65;
params.simulation.sizeMm = 1;
params.simulation.zRangeMm = 100;
params.simulation.dzMm = 100;
params.simulation.adaptiveOutputN = 65;
params.simulation.adaptiveOutputSizeMm = 1;
params.beam.waistRadiusMm = 0.15;
params.beam.beamQualityM2 = 1;
params.phase.axiconRadialCycles = 0;
params.phase.helicalGamma = 0;
params.optics.lens1Enabled = false;
params.optics.lens2Enabled = false;
params.optics.sampleEnabled = false;
adaptive = Bessel_Simulation_app_engine('run',params);
params.simulation.propagationMethod = 'legacyASM';
legacy = Bessel_Simulation_app_engine('run',params);
difference = abs(double(adaptive.propagation.intensity3D(:,:,end))- ...
    abs(legacy.propagation.E3D(:,:,end)).^2);
relativeError = max(difference,[],'all')/max(abs(legacy.propagation.E3D(:,:,end)).^2,[],'all');
verifyLessThan(testCase,relativeError,5e-3);
end

function testAdaptiveExportsNativeCoordinatesAndDisplayMetadata(testCase)
params = Bessel_Simulation_app_engine('defaults');
params.simulation.N = 33;
params.simulation.zRangeMm = 0;
params.simulation.adaptiveOutputN = 32;
params.simulation.adaptiveOutputSizeMm = 0.2;
params.beam.beamQualityM2 = 1;
params.optics.lens1Enabled = false;
params.optics.lens2Enabled = false;
params.optics.sampleEnabled = false;
results = Bessel_Simulation_app_engine('run',params);
folder = tempname(tempdir);
mkdir(folder);
cleanup = onCleanup(@()localRemoveTemporaryExport(folder));
exportParams = results.params;
exportParams.output.outputDir = folder;
exportParams.output.write3DIntensity = true;
exportParams.output.writeRawIntensity = true;
Bessel_Simulation_app_engine('export',struct('results',results,'params',exportParams));
rawFiles = dir(fullfile(folder,'Bessel_raw_intensity_*.mat'));
tiffFiles = dir(fullfile(folder,'*.tif'));
jsonFiles = dir(fullfile(folder,'*.json'));
verifyNumElements(testCase,rawFiles,1);
verifyNumElements(testCase,tiffFiles,1);
verifyNumElements(testCase,jsonFiles,1);
raw = load(fullfile(folder,rawFiles(1).name));
metadata = jsondecode(fileread(fullfile(folder,jsonFiles(1).name)));
verifyEqual(testCase,raw.xMm,results.observationGrid.xValuesMm,'AbsTol',0);
verifyEqual(testCase,raw.yMm,results.observationGrid.yValuesMm,'AbsTol',0);
verifyEqual(testCase,raw.zMm,results.propagation.zValuesMm,'AbsTol',0);
verifyEqual(testCase,raw.rawIntensity,results.propagation.intensity3D,'AbsTol',0);
verifyEqual(testCase,metadata.zMm(:).',results.propagation.zValuesMm,'AbsTol',0);
clear cleanup;
end

function testBandLimitReportsDiscardedAngularPower(testCase)
params = Bessel_Simulation_app_engine('defaults');
params.simulation.N = 65;
params.simulation.sizeMm = 1;
params.simulation.zRangeMm = 100;
params.simulation.dzMm = 100;
params.simulation.adaptiveOutputN = 64;
params.simulation.adaptiveOutputSizeMm = 1;
params.beam.waistRadiusMm = 0.15;
params.beam.beamQualityM2 = 1;
params.phase.axiconMode = 'coneAngle';
params.phase.axiconConeAngleDeg = 1.6;
params.phase.helicalGamma = 0;
params.optics.lens1Enabled = false;
params.optics.lens2Enabled = false;
params.optics.sampleEnabled = false;
results = Bessel_Simulation_app_engine('run',params);
verifyGreaterThan(testCase,results.propagation.diagnostics.maxAsmSpectralPowerRemovedFraction,0.9);
end

function testExtendingSourceWindowKeepsPhysicalPhaseDefinition(testCase)
params = Bessel_Simulation_app_engine('defaults');
params.simulation.useBPM = false;
params.simulation.N = 64;
params.simulation.sizeMm = 8.64;
params.beam.beamQualityM2 = 1;
params.phase.axiconMode = 'radialPeriodPx';
params.phase.axiconRadialPeriodPx = 17.2;
params.phase.curvedMaxShiftXMm = 0.1;
params.phase.checkerboardBesselEnabled = true;
params.phase.checkerboardTileSizePx = 5;
first = Bessel_Simulation_app_engine('run',params);
params.simulation.N = 128;
params.simulation.sizeMm = 17.28;
second = Bessel_Simulation_app_engine('run',params);
verifyEqual(testCase,first.derived.axicon.krRadPerMm, ...
    second.derived.axicon.krRadPerMm,'AbsTol',0);
verifyEqual(testCase,first.phase.maxPropagationMm,second.phase.maxPropagationMm,'AbsTol',0);
verifyEqual(testCase,first.phase.checkerboardMask, ...
    second.phase.checkerboardMask(33:96,33:96));
verifyEqual(testCase,first.inputField,second.inputField(33:96,33:96),'AbsTol',1e-10);
end

function testOldCompleteParameterSnapshotKeepsItsPhaseScale(testCase)
params = Bessel_Simulation_app_engine('defaults');
params.simulation.N = 80;
params.simulation.sizeMm = 10;
params.simulation.useBPM = false;
params.beam.beamQualityM2 = 1;
params.phase = rmfield(params.phase,{'referenceRadiusMm','referencePixelPitchMm'});
results = Bessel_Simulation_app_engine('run',params);
verifyEqual(testCase,results.params.phase.referenceRadiusMm,5);
verifyEqual(testCase,results.params.phase.referencePixelPitchMm,0.125);
verifyEqual(testCase,results.derived.axicon.krRadPerMm, ...
    2*pi*params.phase.axiconRadialCycles/5,'RelTol',1e-12);
end

function localRemoveTemporaryExport(folder)
if ~startsWith(folder,tempdir) || ~isfolder(folder)
    return;
end
files = dir(folder);
for index = 1:numel(files)
    if ~files(index).isdir
        delete(fullfile(folder,files(index).name));
    end
end
rmdir(folder);
end
