function outputFile = package_Bessel_Simulation_toolbox()
%PACKAGE_BESSEL_SIMULATION_TOOLBOX Build the distributable MATLAB toolbox file.
%
% Run this file from MATLAB to create release/Bessel_Simulation_App.mltbx.

scriptDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(scriptDir);
releaseDir = fullfile(repoRoot, 'release');

if exist(releaseDir, 'dir') ~= 7
    mkdir(releaseDir);
end

parameterDoc = dir(fullfile(repoRoot, 'docs', 'BPM_drill_AI_*.md'));
if isempty(parameterDoc)
    error('Could not find the parameter documentation file in the docs folder.');
end

identifier = 'bessel-simulation-app-1b9c9b7f-6d1d-4e91-a352-1e787c58d3a2';
outputFile = fullfile(releaseDir, 'Bessel_Simulation_App.mltbx');

opts = matlab.addons.toolbox.ToolboxOptions(repoRoot, identifier);
opts.ToolboxName = 'Bessel Simulation App';
opts.ToolboxVersion = '1.0.0';
opts.AuthorName = 'Shan';
opts.Summary = 'MATLAB UI for Bessel beam simulation and SLM phase export.';
opts.Description = [
    "Interactive MATLAB app for configuring and running the Bessel beam simulation. " + ...
    "The app previews input phase, propagation results, summary values, and exports SLM phase images and 3D intensity stacks."
    ];
opts.MinimumMatlabRelease = 'R2021a';
opts.OutputFile = outputFile;

opts.ToolboxFiles = string({
    fullfile(repoRoot, 'launch_Bessel_Simulation_app.m')
    fullfile(repoRoot, 'README.md')
    fullfile(repoRoot, 'src', 'Bessel_Simulation_app.m')
    fullfile(repoRoot, 'src', 'Bessel_Simulation_app_engine.m')
    fullfile(repoRoot, 'src', 'BPM_drill_AI.m')
    fullfile(parameterDoc(1).folder, parameterDoc(1).name)
    fullfile(repoRoot, 'docs', 'Bessel Beam.json')
    fullfile(repoRoot, 'outputs', '.gitkeep')
    });

opts.ToolboxMatlabPath = string({
    repoRoot
    fullfile(repoRoot, 'src')
    });
opts.AppGalleryFiles = string(fullfile(repoRoot, 'launch_Bessel_Simulation_app.m'));

matlab.addons.toolbox.packageToolbox(opts);
fprintf('Created toolbox installer: %s\n', outputFile);
end
