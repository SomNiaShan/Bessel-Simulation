function outputFile = package_BPM_drill_AI_toolbox()
%PACKAGE_BPM_DRILL_AI_TOOLBOX Build the distributable MATLAB toolbox file.
%
% Run this file from MATLAB to create release/BPM_Drill_AI_App.mltbx.

repoRoot = fileparts(mfilename('fullpath'));
releaseDir = fullfile(repoRoot, 'release');

if exist(releaseDir, 'dir') ~= 7
    mkdir(releaseDir);
end

parameterDoc = dir(fullfile(repoRoot, 'docs', 'BPM_drill_AI_*.md'));
if isempty(parameterDoc)
    error('Could not find the parameter documentation file in the docs folder.');
end

identifier = 'bpm-drill-ai-app-1b9c9b7f-6d1d-4e91-a352-1e787c58d3a2';
outputFile = fullfile(releaseDir, 'BPM_Drill_AI_App.mltbx');

opts = matlab.addons.toolbox.ToolboxOptions(repoRoot, identifier);
opts.ToolboxName = 'BPM Drill AI App';
opts.ToolboxVersion = '1.0.0';
opts.AuthorName = 'Shan';
opts.Summary = 'MATLAB UI for BPM drill-beam simulation and SLM phase export.';
opts.Description = [
    "Interactive MATLAB app for configuring and running the BPM drill-beam simulation. " + ...
    "The app previews input phase, propagation results, summary values, and exports SLM phase images and 3D intensity stacks."
    ];
opts.MinimumMatlabRelease = 'R2021a';
opts.OutputFile = outputFile;

opts.ToolboxFiles = string({
    fullfile(repoRoot, 'launch_BPM_drill_AI_app.m')
    fullfile(repoRoot, 'README.md')
    fullfile(repoRoot, 'src', 'BPM_drill_AI_app.m')
    fullfile(repoRoot, 'src', 'BPM_drill_AI_app_engine.m')
    fullfile(repoRoot, 'src', 'BPM_drill_AI.m')
    fullfile(parameterDoc(1).folder, parameterDoc(1).name)
    fullfile(repoRoot, 'docs', 'Bessel Beam.json')
    fullfile(repoRoot, 'outputs', '.gitkeep')
    });

opts.ToolboxMatlabPath = string({
    repoRoot
    fullfile(repoRoot, 'src')
    });
opts.AppGalleryFiles = string(fullfile(repoRoot, 'launch_BPM_drill_AI_app.m'));

matlab.addons.toolbox.packageToolbox(opts);
fprintf('Created toolbox installer: %s\n', outputFile);
end
