function tests = test_axicon_geometry
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

function testCircularGeometryPreservesOriginalFormula(testCase)
params = localSmallParams();
results = Bessel_Simulation_app_engine('run', params);
expected = results.derived.axicon.krRadPerMm * ...
    (results.grid.sizeMm / 2 - results.grid.r);

verifyEqual(testCase, results.phase.axicon, expected, 'AbsTol', 0);
verifyEqual(testCase, results.derived.axicon.geometry, 'circular');
end

function testLinearGeometryAlongX(testCase)
params = localSmallParams();
params.phase.axiconGeometry = 'linear1D';
params.phase.axiconOrientationDeg = 0;
results = Bessel_Simulation_app_engine('run', params);
expected = results.derived.axicon.krRadPerMm * ...
    (results.grid.sizeMm / 2 - abs(results.grid.x));

verifyEqual(testCase, results.phase.axicon, expected, 'AbsTol', 0);
verifyEqual(testCase, results.phase.axicon, ...
    repmat(results.phase.axicon(1, :), results.grid.N, 1), 'AbsTol', 0);

centerRow = results.postprocess.centerRowIndex;
centerColumn = results.postprocess.centerColumnIndex;
inputIntensity = abs(results.inputField) .^ 2;
verifyEqual(testCase, results.postprocess.normalCrossSectionIntensity(:, 1), ...
    inputIntensity(centerRow, :).', 'AbsTol', 1e-12);
verifyEqual(testCase, results.postprocess.tangentCrossSectionIntensity(:, 1), ...
    inputIntensity(:, centerColumn), 'AbsTol', 1e-12);
end

function testRotatedLinearGeometry(testCase)
params = localSmallParams();
params.phase.axiconGeometry = 'linear1D';
params.phase.axiconOrientationDeg = 37;
results = Bessel_Simulation_app_engine('run', params);
orientationRad = deg2rad(params.phase.axiconOrientationDeg);
u = results.grid.x .* cos(orientationRad) + results.grid.y .* sin(orientationRad);
expected = results.derived.axicon.krRadPerMm * ...
    (results.grid.sizeMm / 2 - abs(u));

verifyEqual(testCase, results.phase.axicon, expected, 'AbsTol', 1e-12);
verifySize(testCase, results.postprocess.normalCrossSectionIntensity, ...
    [params.simulation.N, 1]);
verifySize(testCase, results.postprocess.tangentCrossSectionIntensity, ...
    [params.simulation.N, 1]);
centerColumn = results.postprocess.centerColumnIndex;
inputIntensity = abs(results.inputField) .^ 2;
verifyEqual(testCase, results.postprocess.crossSectionIntensity(:, 1), ...
    inputIntensity(:, centerColumn), 'AbsTol', 1e-12);
end

function testLegacyParamsReceiveCircularDefault(testCase)
params = localSmallParams();
params.phase = rmfield(params.phase, ...
    {'apertureRadiusMm', 'axiconGeometry', 'axiconOrientationDeg'});
results = Bessel_Simulation_app_engine('run', params);

verifyEqual(testCase, results.params.phase.apertureRadiusMm, 0);
verifyEqual(testCase, results.params.phase.axiconGeometry, 'circular');
verifyEqual(testCase, results.params.phase.axiconOrientationDeg, 0);
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
