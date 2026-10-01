function tests = test_z_sampling
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.sourceDir = fullfile(fileparts(fileparts(mfilename('fullpath'))),'src');
addpath(testCase.TestData.sourceDir);
end

function teardownOnce(testCase)
rmpath(testCase.TestData.sourceDir);
end

function p = localParams()
p = Bessel_Simulation_app_engine('defaults');
p.simulation.zRangeMm = 250; p.simulation.dzMm = 1;
p.optics.lens1PositionMm = 0; p.optics.lens2PositionMm = 210;
p.optics.lens2FocalLengthMm = 10; p.optics.sampleEnabled = false;
end

function testUniformMatchesPreviousAdaptiveGrid(testCase)
p = localParams(); p.simulation.dzMm = 7;
p.optics.lens2PositionMm = 210.1;
old = unique([0:7:250,250,0,210.1]);
q = Bessel_Simulation_app_engine('plan',p);
verifyEqual(testCase,q.zPlan.zValuesMm,old,'AbsTol',0);
verifyEqual(testCase,q.zPlan.addedPlaneCount,0);
verifyFalse(testCase,q.zPlan.isUniformZ);
p.optics.lens1Enabled = false; p.optics.lens2Enabled = false;
p.simulation.zRangeMm = 2;
for h = [.07,.1,.3,.02]
    p.simulation.dzMm = h;
    q = bessel_build_z_plan(p);
    verifyEqual(testCase,q.zValuesMm,unique([0:h:2,2]),'AbsTol',0);
end
end

function testOldSnapshotGetsUniformDefaults(testCase)
p = localParams();
p.simulation = rmfield(p.simulation,{'zSamplingMode','zRefinementRegionsMm','zExtraPlanesMm','maxZPlanes'});
q = Bessel_Simulation_app_engine('plan',p);
verifyEqual(testCase,q.zPlan.zValuesMm,0:250);
verifyEqual(testCase,q.params.simulation.zSamplingMode,'uniform');
end

function testExpectedCountsAndMemory(testCase)
p = localParams(); p.simulation.zSamplingMode = 'local';
steps = [.05,.02,.01]; counts = [346,496,746];
for k = 1:3
    p.simulation.zRefinementRegionsMm = [218,223,steps(k)];
    p.simulation.zExtraPlanesMm = 220.5;
    q = Bessel_Simulation_app_engine('plan',p);
    verifyEqual(testCase,q.zPlan.planeCount,counts(k));
    verifyEqual(testCase,q.zPlan.basePlaneCount,251);
    verifyEqual(testCase,q.memory.intensityStackGiB,512^2*counts(k)*4/2^30,'AbsTol',1e-14);
    verifyEqual(testCase,q.memory,bessel_estimate_adaptive_memory(q.params,q.zPlan));
    verifyTrue(testCase,all(diff(q.zPlan.zValuesMm)>0));
end
end

function testOverlapUsesSmallestStepAndIsOrderIndependent(testCase)
p = localParams(); p.simulation.zSamplingMode = 'local';
p.simulation.zRefinementRegionsMm = [218,222,.1;220,223,.03];
a = bessel_build_z_plan(p);
verifyEqual(testCase,a.effectiveSegmentsMm,[218,220,.1;220,223,.03]);
p.simulation.zRefinementRegionsMm = [220,223,.03;218,222,.1;218,222,.1];
b = bessel_build_z_plan(p);
verifyEqual(testCase,a.zValuesMm,b.zValuesMm,'AbsTol',0);
z = a.zValuesMm(a.zValuesMm>=220 & a.zValuesMm<=223);
verifyLessThanOrEqual(testCase,max(diff(z)),.03+1e-12);
verifyTrue(testCase,any(z==222)); % internal original border stays exact
end

function testNonintegralBordersAndExtraPlanesAreExact(testCase)
p = localParams(); p.simulation.zSamplingMode = 'local';
p.simulation.zRefinementRegionsMm = [218.13,222.87,.07];
p.simulation.zExtraPlanesMm = [221.0531,220.5];
q = bessel_build_z_plan(p);
verifyTrue(testCase,all(ismember([218.13,222.87,221.0531,220.5],q.zValuesMm)));
z = q.zValuesMm(q.zValuesMm>=218.13 & q.zValuesMm<=222.87);
verifyLessThanOrEqual(testCase,max(diff(z)),.07+1e-12);
verifyTrue(testCase,all(ismember(0:250,q.zValuesMm)));
end

function testOpticalEventsAndCloselySpacedProtectedPlanes(testCase)
p = localParams(); p.optics.sampleEnabled = true; p.optics.samplePositionMm = 211.123;
p.optics.lens2PositionMm = 210.123;
q = bessel_build_z_plan(p);
verifyTrue(testCase,all(ismember([0,210.123,211.123],q.zValuesMm)));
p.optics.sampleEnabled = false; p.optics.lens2PositionMm = 251;
q = bessel_build_z_plan(p);
verifyEqual(testCase,q.opticalEventZMm,0);
p.simulation.zSamplingMode = 'local';
p.simulation.zExtraPlanesMm = [220.5,220.5+eps(220.5)];
q = bessel_build_z_plan(p);
verifyTrue(testCase,all(ismember(p.simulation.zExtraPlanesMm,q.zValuesMm)));
verifyTrue(testCase,all(diff(q.zValuesMm)>0));
end

function testInvalidRegions(testCase)
p = localParams(); p.simulation.zSamplingMode = 'local';
bad = {[1,2], [1,2,NaN], [1,2,Inf], [-1,2,.1], [2,1,.1], ...
    [1,251,.1], [1,2,0], [1,2,-.1], [1,2,2], [1,1,.1], complex([1,2,.1],1)};
for k = 1:numel(bad)
    p.simulation.zRefinementRegionsMm = bad{k};
    verifyError(testCase,@()bessel_build_z_plan(p),'Bessel:ZPlan:InvalidRegion');
end
end

function testInvalidExtraAndMode(testCase)
p = localParams(); p.simulation.zSamplingMode = 'local';
bad = {NaN,Inf,-1,251,ones(2,2),1i};
for k = 1:numel(bad)
    p.simulation.zExtraPlanesMm = bad{k};
    verifyError(testCase,@()bessel_build_z_plan(p),'Bessel:ZPlan:InvalidExtraPlane');
end
p.simulation.zExtraPlanesMm = [];
verifyError(testCase,@()bessel_build_z_plan(p),'Bessel:ZPlan:InvalidRegion');
p.simulation.zSamplingMode = 'automatic';
verifyError(testCase,@()bessel_build_z_plan(p),'Bessel:ZPlan:InvalidMode');
end

function testUniformRetainsInactiveRegionsButRejectsMalformedArrays(testCase)
p = localParams(); p.simulation.zRefinementRegionsMm = [218,1000,-.1];
p.simulation.zExtraPlanesMm = [-10,1000];
q = bessel_build_z_plan(p); verifyEqual(testCase,q.planeCount,251);
p.simulation.zRefinementRegionsMm = [1,2,NaN];
verifyError(testCase,@()bessel_build_z_plan(p),'Bessel:ZPlan:InvalidRegion');
end

function testNoPropagationAndZeroRange(testCase)
p = localParams(); p.simulation.useBPM = false;
p.simulation.zRangeMm = 1e12; p.simulation.dzMm = 1e-20;
p.simulation.zSamplingMode = 'local';
q = Bessel_Simulation_app_engine('plan',p);
verifyEqual(testCase,q.zPlan.zValuesMm,0); verifyEmpty(testCase,q.memory);
p.simulation.useBPM = true; p.simulation.zRangeMm = 0; p.simulation.dzMm = 1;
p.simulation.zExtraPlanesMm = 0;
q = bessel_build_z_plan(p); verifyEqual(testCase,q.zValuesMm,0);
p.simulation.zRefinementRegionsMm = [0,1,.1];
verifyError(testCase,@()bessel_build_z_plan(p),'Bessel:ZPlan:InvalidRegion');
end

function testSpacingAndCountGuardBeforeAllocation(testCase)
p = localParams(); p.simulation.zSamplingMode = 'local';
p.simulation.zRefinementRegionsMm = [218,223,eps(250)];
verifyError(testCase,@()bessel_build_z_plan(p),'Bessel:ZPlan:SpacingTooSmall');
p.simulation.zRefinementRegionsMm = [218,223,1e-8];
verifyError(testCase,@()bessel_build_z_plan(p),'Bessel:ZPlan:TooManyPlanes');
p.simulation.zSamplingMode = 'uniform'; p.simulation.zRangeMm = 1e12;
verifyError(testCase,@()bessel_build_z_plan(p),'Bessel:ZPlan:TooManyPlanes');
p = localParams(); p.simulation.maxZPlanes = 250;
verifyError(testCase,@()bessel_build_z_plan(p),'Bessel:ZPlan:TooManyPlanes');
end

function testMemoryRejectedBeforeBuildingSource(testCase)
p = localParams(); p.simulation.dzMm = .02;
q = Bessel_Simulation_app_engine('plan',p);
verifyEqual(testCase,q.zPlan.planeCount,12501);
verifyFalse(testCase,q.memory.withinBudget);
verifyError(testCase,@()Bessel_Simulation_app_engine('run',p),'Bessel:Memory:BudgetExceeded');
end

function testLegacyLocalRejectedAndUniformEndUnchanged(testCase)
p = localParams(); p.simulation.propagationMethod = 'legacyASM';
p.simulation.dzMm = 7;
q = Bessel_Simulation_app_engine('plan',p);
verifyEqual(testCase,q.zPlan.zValuesMm,0:7:250);
p.simulation.zSamplingMode = 'local'; p.simulation.zExtraPlanesMm = 220.5;
verifyError(testCase,@()Bessel_Simulation_app_engine('plan',p),'Bessel:ZPlan:UnsupportedBackend');
end

function testPlanResolvesLockedOpticsWithoutSideEffects(testCase)
p = localParams(); p.optics.layoutMode = 'telescopeLocked';
p.optics.lens1PositionMm = 1.23; p.optics.sampleEnabled = true;
p.output.outputDir = tempname; p.output.writeProgressLog = true;
q = Bessel_Simulation_app_engine('plan',p);
verifyEqual(testCase,q.params.optics.lens2PositionMm,211.23,'AbsTol',1e-12);
verifyTrue(testCase,ismember(q.params.optics.samplePositionMm,q.zPlan.zValuesMm));
verifyFalse(testCase,isfolder(p.output.outputDir));
end

function testSafeExtraPlaneParser(testCase)
verifyEqual(testCase,bessel_parse_z_planes('220.5, 2.2105e2; +.02 -1'),[220.5,221.05,.02,-1]);
verifyEmpty(testCase,bessel_parse_z_planes('   '));
bad = {'1:4','[1 2]','NaN','Inf','1+2','system(''dir'')','1e999'};
for k=1:numel(bad)
    verifyError(testCase,@()bessel_parse_z_planes(bad{k}),'Bessel:ZPlan:InvalidExtraPlane');
end
end

function p = localSmallParams()
p = localParams(); p.simulation.N = 65; p.simulation.sizeMm = 1;
p.simulation.zRangeMm = 48; p.simulation.dzMm = 12;
p.simulation.adaptiveOutputN = 64; p.simulation.adaptiveOutputSizeMm = .2;
p.beam.waistRadiusMm = .15; p.beam.beamQualityM2 = 1;
p.phase.axiconRadialCycles = 0; p.phase.helicalGamma = 0;
p.optics.lens1PositionMm = 20; p.optics.lens2PositionMm = 44;
p.optics.lens1FocalLengthMm = 20; p.optics.lens2FocalLengthMm = 4;
end

function testRefinementDoesNotChangeSharedPlanesForAllModeModels(testCase)
p = localSmallParams(); p.beam.beamQualityM2 = 1.2;
models = {'effectiveGaussian','coherentHG','incoherentHG'};
for k=1:numel(models)
    p.beam.beamQualityModel = models{k}; p.simulation.zSamplingMode = 'uniform';
    coarse = Bessel_Simulation_app_engine('run',p);
    p.simulation.zSamplingMode = 'local'; p.simulation.zRefinementRegionsMm = [45,48,.2];
    fine = Bessel_Simulation_app_engine('run',p);
    [included,index] = ismember(coarse.propagation.zValuesMm,fine.propagation.zValuesMm);
    verifyTrue(testCase,all(included));
    verifyEqual(testCase,fine.propagation.intensity3D(:,:,index),coarse.propagation.intensity3D,'AbsTol',single(0));
    verifyEqual(testCase,fine.inputField,coarse.inputField,'AbsTol',0);
    verifyEqual(testCase,fine.propagation.zPlan.zValuesMm,fine.propagation.zValuesMm);
end
end

function testExactImagePlaneInRefinedGaussianCase(testCase)
p = localSmallParams(); p.simulation.N = 129; p.simulation.adaptiveOutputN = 128;
p.simulation.dzMm = 13; p.simulation.zSamplingMode = 'local';
p.simulation.zExtraPlanesMm = 48;
r = Bessel_Simulation_app_engine('run',p);
[x,y] = meshgrid(r.observationGrid.xValuesMm);
expected = 25*exp(-2*(x.^2+y.^2)/.03^2);
verifyLessThan(testCase,max(abs(double(r.propagation.finalIntensity)-expected),[],'all')/25,.003);
end

function testNonuniformExportRetainsActualRunPlan(testCase)
p = localSmallParams(); p.simulation.N = 33; p.simulation.adaptiveOutputN = 32;
p.simulation.zRangeMm = 1; p.simulation.dzMm = 1;
p.optics.lens1Enabled = false; p.optics.lens2Enabled = false;
p.simulation.zSamplingMode = 'local'; p.simulation.zRefinementRegionsMm = [.2,.8,.2];
p.simulation.zExtraPlanesMm = .35;
r = Bessel_Simulation_app_engine('run',p);
folder = tempname(tempdir); mkdir(folder);
cleanup = onCleanup(@()localRemoveTemporaryExport(folder));
e = r.params; fields = fieldnames(e.output);
for k = 1:numel(fields)
    if islogical(e.output.(fields{k})), e.output.(fields{k}) = false; end
end
e.output.outputDir = folder; e.output.write3DIntensity = true; e.output.writeRawIntensity = true;
% Editing export parameters must not replace the completed run's sampling.
e.simulation.zSamplingMode = 'uniform'; e.simulation.dzMm = 100;
Bessel_Simulation_app_engine('export',struct('results',r,'params',e));
mf = dir(fullfile(folder,'*.mat')); jf = dir(fullfile(folder,'*.json')); tf = dir(fullfile(folder,'*.tif'));
raw = load(fullfile(folder,mf(1).name)); meta = jsondecode(fileread(fullfile(folder,jf(1).name)));
verifyEqual(testCase,raw.zMm,r.propagation.zValuesMm,'AbsTol',0);
verifyEqual(testCase,raw.rawIntensity,r.propagation.intensity3D,'AbsTol',0);
verifyEqual(testCase,raw.zSamplingMetadata,r.propagation.zPlan);
verifyEqual(testCase,meta.zSamplingMetadata.zValuesMm(:).',raw.zMm,'AbsTol',0);
verifyFalse(testCase,meta.zSamplingMetadata.isUniformZ);
verifyEqual(testCase,numel(imfinfo(fullfile(folder,tf(1).name))),numel(raw.zMm));
lo = double(min(raw.rawIntensity,[],'all')); hi = double(max(raw.rawIntensity,[],'all'));
for k=1:numel(raw.zMm)
    expected = uint8(255*(double(raw.rawIntensity(:,:,k))-lo)/max(hi-lo,eps));
    verifyEqual(testCase,imread(fullfile(folder,tf(1).name),k),expected);
end
clear cleanup;
end

function localRemoveTemporaryExport(folder)
if ~startsWith(folder,tempdir) || ~isfolder(folder), return; end
files = dir(folder);
for k=1:numel(files)
    if ~files(k).isdir, delete(fullfile(folder,files(k).name)); end
end
rmdir(folder);
end
