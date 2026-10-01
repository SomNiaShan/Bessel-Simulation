function params = Bessel_Simulation_app_defaults()
%BESSEL_SIMULATION_APP_DEFAULTS App preset captured from the live UI on 2026-10-01.
% Used by both app startup and the Defaults button.

params = Bessel_Simulation_app_engine('defaults');

params.simulation.zRangeMm = 250;
params.simulation.dzMm = 1;
params.simulation.zSamplingMode = 'local';
params.simulation.zRefinementRegionsMm = [220, 225, 0.01];
params.simulation.adaptiveOutputSizeMm = 0.1;

params.phase.axiconConeAngleDeg = 0.13660812224994015;
params.phase.axiconRadialPeriodMm = 0.43200000000000005;
params.phase.axiconRadialPeriodPx = 54.000000000000007;
params.phase.axiconAngleDeg = 0.31865098822996241;
params.phase.helicalGamma = 0;

params.optics.lens2FocalLengthMm = 10;
params.optics.lens1PositionMm = 0;
params.optics.lens2PositionMm = 210;
params.optics.samplePositionMm = 215;
params.optics.layoutMode = 'telescopeLocked';
params.optics.sampleOffsetFromLens2Mm = 5;
params.optics.sampleEnabled = false;

params.output.write3DIntensity = true;
end
