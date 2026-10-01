function tests = test_aperture
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
repoRoot = fileparts(fileparts(mfilename('fullpath')));
sourceDir = fullfile(repoRoot, 'src');
addpath(sourceDir);
testCase.TestData.sourceDir = sourceDir;
end

function teardownOnce(testCase)
rmpath(testCase.TestData.sourceDir);
end

function testZeroRadiusIsFullyOpen(testCase)
params = localSmallParams();
results = Bessel_Simulation_app_engine('run', params);

verifyFalse(testCase, results.aperture.enabled);
verifyEqual(testCase, results.aperture.radiusMm, 0);
verifyTrue(testCase, all(results.aperture.mask, 'all'));
verifyEqual(testCase, results.aperture.transmission, 1, 'AbsTol', 0);
verifyEqual(testCase, results.aperture.transmittedAveragePowerW, params.laser.powerW, 'AbsTol', 0);
end

function testFiniteRadiusBlocksOutsideFieldAndPreservesPowerLoss(testCase)
params = localSmallParams();
params.phase.apertureRadiusMm = 2;
results = Bessel_Simulation_app_engine('run', params);

expectedMask = results.grid.r <= params.phase.apertureRadiusMm;
expectedTransmission = sum(abs(results.inputEnvelope(expectedMask)) .^ 2, 'all') / ...
    sum(abs(results.inputEnvelope) .^ 2, 'all');

verifyTrue(testCase, results.aperture.enabled);
verifyEqual(testCase, results.aperture.mask, expectedMask);
verifyEqual(testCase, results.inputField(~expectedMask), ...
    zeros(nnz(~expectedMask), 1), 'AbsTol', 0);
verifyEqual(testCase, abs(results.inputField(expectedMask)), ...
    abs(results.inputEnvelope(expectedMask)), 'AbsTol', 1e-12);
verifyEqual(testCase, results.aperture.transmission, expectedTransmission, 'RelTol', 1e-12);
verifyEqual(testCase, results.postprocess.apertureTransmission, expectedTransmission, 'RelTol', 1e-12);
verifyEqual(testCase, results.postprocess.transmittedAveragePowerW, ...
    params.laser.powerW * expectedTransmission, 'RelTol', 1e-12);

referenceIntensity = abs(results.propagation.E3D(:, :, 1)) .^ 2;
integratedPeakPowerW = sum(referenceIntensity, 'all') * ...
    results.postprocess.pixelPowerW * results.derived.pulsePeakPowerW;
verifyEqual(testCase, integratedPeakPowerW, ...
    results.aperture.transmittedPulsePeakPowerW, 'RelTol', 1e-12);
end

function testApertureAppliesToAllBeamQualityModels(testCase)
params = localSmallParams();
params.phase.apertureRadiusMm = 1.5;
models = {'effectiveGaussian', 'coherentHG', 'incoherentHG'};

for modelIndex = 1:numel(models)
    params.beam.beamQualityModel = models{modelIndex};
    results = Bessel_Simulation_app_engine('run', params);
    verifyEqual(testCase, results.inputIntensity(~results.aperture.mask), ...
        zeros(nnz(~results.aperture.mask), 1), 'AbsTol', 0);
    verifyGreaterThan(testCase, results.aperture.transmission, 0);
    verifyLessThan(testCase, results.aperture.transmission, 1);
end
end

function testLegacyParamsReceiveOpenApertureDefault(testCase)
params = localSmallParams();
params.phase = rmfield(params.phase, 'apertureRadiusMm');
results = Bessel_Simulation_app_engine('run', params);

verifyEqual(testCase, results.params.phase.apertureRadiusMm, 0);
verifyFalse(testCase, results.aperture.enabled);
verifyEqual(testCase, results.aperture.transmission, 1, 'AbsTol', 0);
end

function testNegativeRadiusIsRejected(testCase)
params = localSmallParams();
params.phase.apertureRadiusMm = -1;
caughtExpectedError = false;
try
    Bessel_Simulation_app_engine('run', params);
catch ME
    caughtExpectedError = contains(ME.message, ...
        'params.phase.apertureRadiusMm must be a finite nonnegative scalar number.');
end
verifyTrue(testCase, caughtExpectedError);
end

function params = localSmallParams()
params = Bessel_Simulation_app_engine('defaults');
params.simulation.N = 65;
params.simulation.useBPM = false;
params.phase.airyStrength = 0;
params.phase.curvedMaxShiftXMm = 0;
params.phase.curvedMaxShiftYMm = 0;
params.phase.compensationPhase = 0;
params.phase.vortexCharge = 0;
params.phase.checkerboardBesselEnabled = false;
params.phase.helicalGamma = 0;
end
