function memory = bessel_estimate_adaptive_memory(params,zPlan)
%BESSEL_ESTIMATE_ADAPTIVE_MEMORY Shared conservative working-array estimate.
% This is an estimate, not a measurement of MATLAB's peak process memory.
s = params.simulation;
nSource = double(s.N); nOutput = double(s.adaptiveOutputN);
sourceGiB = 20*nSource^2*8/2^30;
stackGiB = nOutput^2*double(zPlan.planeCount)*4/2^30;
cztGiB = 5*2^nextpow2(2*nSource+nOutput-2)*max(nSource,nOutput)*16/2^30;
memory = struct('sourceGiB',sourceGiB, 'intensityStackGiB',stackGiB, ...
    'cztWorkGiB',cztGiB, 'totalGiB',sourceGiB+stackGiB+cztGiB, ...
    'budgetGiB',double(s.maxWorkingGiB), ...
    'withinBudget',sourceGiB+stackGiB+cztGiB <= s.maxWorkingGiB);
end
