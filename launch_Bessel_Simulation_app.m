function app = launch_Bessel_Simulation_app()
% Launch the Bessel Simulation app without changing the original script.

repoRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(repoRoot, 'src'));
app = Bessel_Simulation_app();
end
