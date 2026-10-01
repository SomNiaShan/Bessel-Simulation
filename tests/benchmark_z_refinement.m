function report = benchmark_z_refinement()
%BENCHMARK_Z_REFINEMENT Reproduce the user's small-f2 case at full source N.
% Run separately from unit tests; keeps only two stacks at any one time.
addpath(fullfile(fileparts(fileparts(mfilename('fullpath'))),'src'));
p = Bessel_Simulation_app_engine('defaults');
p.simulation.N = 1080; p.simulation.sizeMm = 8.64;
p.simulation.zRangeMm = 250; p.simulation.dzMm = 1;
p.simulation.adaptiveOutputN = 512; p.simulation.adaptiveOutputSizeMm = 0;
p.simulation.maxWorkingGiB = 3;
p.optics.lens1FocalLengthMm = 200; p.optics.lens2FocalLengthMm = 10;
p.optics.lens1PositionMm = 0; p.optics.lens2PositionMm = 210;
p.optics.samplePositionMm = 220; p.optics.layoutMode = 'manual';
p.optics.sampleEnabled = false;
p.phase.axiconRadialCycles = 20; p.phase.helicalGamma = 0;
p.phase.checkerboardBesselEnabled = false;
steps = [NaN,.02,.01]; report = struct([]);
previousStack = []; previousZ = [];
for k = 1:3
    if k > 1
        p.simulation.zSamplingMode = 'local';
        p.simulation.zRefinementRegionsMm = [218,223,steps(k)];
        p.simulation.zExtraPlanesMm = 220.5;
    end
    q = Bessel_Simulation_app_engine('plan',p);
    timer = tic; r = Bessel_Simulation_app_engine('run',p); elapsed = toc(timer);
    z = r.propagation.zValuesMm;
    axisPeak = double(r.postprocess.onAxisPeakPowerDensityWPerMm2(:).');
    [peak,index] = max(axisPeak);
    commonError = 0;
    if k > 1
        % Floating representations of identical fine-grid coordinates can
        % differ by a few ulps; use the scheduler's tolerance for matching.
        nearest = interp1(z,1:numel(z),previousZ,'nearest','extrap');
        assert(all(abs(z(nearest)-previousZ) <= q.zPlan.mergeToleranceMm));
        for j=1:numel(previousZ)
            a = double(previousStack(:,:,j)); b = double(r.propagation.intensity3D(:,:,nearest(j)));
            commonError = max(commonError,max(abs(a-b),[],'all')/max(max(a,[],'all'),realmin));
        end
    end
    width = localFwhm(z,axisPeak,index);
    report(k).localDzMm = steps(k);
    report(k).planeCount = numel(z);
    report(k).stackGiB = q.memory.intensityStackGiB;
    report(k).estimatedTotalGiB = q.memory.totalGiB;
    report(k).elapsedSeconds = elapsed;
    report(k).peakZMm = z(index);
    report(k).peakWPerMm2 = peak;
    report(k).singleLobeFwhmMm = width;
    report(k).commonPlaneRelativeError = commonError;
    fprintf('dz=%g, planes=%d, time=%.2fs, peak z=%.6f, peak=%.9g, FWHM=%.6g, shared error=%.3g\n', ...
        steps(k),numel(z),elapsed,z(index),peak,width,commonError);
    assert(commonError < 1e-6);
    if k > 1, assert(z(index)>218 && z(index)<223); end
    previousStack = r.propagation.intensity3D; previousZ = z;
    clear r;
end
assert(abs(report(3).peakZMm-report(2).peakZMm) <= .02+1e-10);
assert(abs(report(3).peakWPerMm2/report(2).peakWPerMm2-1) < .01);
assert(abs(report(3).singleLobeFwhmMm/report(2).singleLobeFwhmMm-1) < .05);
end

function width = localFwhm(z,p,index)
half = p(index)/2;
left = index; right = index;
while left > 1 && p(left)>=half, left = left-1; end
while right < numel(p) && p(right)>=half, right = right+1; end
if left==1 && p(left)>=half || right==numel(p) && p(right)>=half
    width = NaN; return;
end
a = z(left)+(half-p(left))*(z(left+1)-z(left))/(p(left+1)-p(left));
b = z(right-1)+(half-p(right-1))*(z(right)-z(right-1))/(p(right)-p(right-1));
width = b-a;
end
