function app = launch_BPM_drill_AI_app()
% Launch the copied App version without changing the original script.

repoRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(repoRoot, 'src'));
app = BPM_drill_AI_app();
end
