function tests = test_z_sampling_ui
tests = functiontests(localfunctions);
end

function setupOnce(testCase)
testCase.TestData.sourceDir = fullfile(fileparts(fileparts(mfilename('fullpath'))),'src');
addpath(testCase.TestData.sourceDir);
end

function teardownOnce(testCase)
rmpath(testCase.TestData.sourceDir);
end

function testUiSamplingRoundTripPreviewBackendAndPlots(testCase)
app = Bessel_Simulation_app;
app.UIFigure.Visible = 'off';
cleanup = onCleanup(@()delete(app));
fig = app.UIFigure;
mode = findall(fig,'Tag','zSamplingMode');
regions = findall(fig,'Tag','zRefinementRegionsMm');
extra = findall(fig,'Tag','zExtraPlanesMm');
preview = findall(fig,'Tag','zPreview');
info = findall(fig,'Tag','zSamplingPreview');
defaults = Bessel_Simulation_app_defaults();
verifyEqual(testCase,mode.Value,defaults.simulation.zSamplingMode);
verifyEqual(testCase,regions.Data,defaults.simulation.zRefinementRegionsMm);
verifyEqual(testCase,regions.Enable,matlab.lang.OnOffSwitchState.on);
p = Bessel_Simulation_app_engine('defaults');
p.simulation.N = 33; p.simulation.adaptiveOutputN = 32;
p.simulation.zRangeMm = 2; p.simulation.dzMm = 1;
p.optics.lens1Enabled = false; p.optics.lens2Enabled = false; p.optics.sampleEnabled = false;
p.phase.helicalGamma = 0; p.phase.axiconRadialCycles = 0;
groups = {'simulation','optics','phase'};
for g = 1:numel(groups)
    group = groups{g}; fields = fieldnames(p.(group));
    for k = 1:numel(fields)
        control = findall(fig,'Tag',[group '__' fields{k}]);
        if numel(control)==1, control.Value = p.(group).(fields{k}); end
    end
end
mode.Value = 'local'; feval(mode.ValueChangedFcn,mode,[]);
regions.Data = [.2,.8,.2;1.1,1.9,.2]; extra.Value = '0.35, 1.2345678901234567';
feval(preview.ButtonPushedFcn,preview,[]);
verifyTrue(testCase,contains(strjoin(string(info.Value)),'Mode: local'));
verifyTrue(testCase,contains(strjoin(string(info.Value)),'estimated total'));
remove = findall(fig,'Tag','zRemoveRegion');
feval(regions.CellSelectionCallback,regions,struct('Indices',[2 1]));
feval(remove.ButtonPushedFcn,remove,[]);
verifyEqual(testCase,regions.Data,[.2,.8,.2]);
add = findall(fig,'Tag','zAddRegion'); feval(add.ButtonPushedFcn,add,[]);
verifyEqual(testCase,regions.Data,[.2,.8,.2;0,2,1]);
regions.Data = [.2,.8,.2];
backend = findall(fig,'Tag','simulation__propagationMethod');
backend.Value = 'legacyASM'; feval(backend.ValueChangedFcn,backend,[]);
verifyEqual(testCase,mode.Value,'uniform');
verifyEqual(testCase,mode.Enable,matlab.lang.OnOffSwitchState.off);
verifyEqual(testCase,regions.Data,[.2,.8,.2]);
backend.Value = 'adaptiveCollins'; feval(backend.ValueChangedFcn,backend,[]);
run = findall(fig,'Type','uibutton','Text','Run');
% Exercise plotting on the same axes: uniform -> local -> uniform -> one plane.
feval(run.ButtonPushedFcn,run,[]);
localVerifyPlots(testCase,fig,false);
mode.Value = 'local'; feval(mode.ValueChangedFcn,mode,[]);
feval(run.ButtonPushedFcn,run,[]);
localVerifyPlots(testCase,fig,true);
verifyEqual(testCase,regions.Data,[.2,.8,.2]);
verifyEqual(testCase,bessel_parse_z_planes(extra.Value),[.35,1.2345678901234567],'AbsTol',0);
mode.Value = 'uniform'; feval(mode.ValueChangedFcn,mode,[]);
feval(run.ButtonPushedFcn,run,[]);
localVerifyPlots(testCase,fig,false);
range = findall(fig,'Tag','simulation__zRangeMm'); range.Value = 0;
feval(run.ButtonPushedFcn,run,[]);
localVerifyPlots(testCase,fig,false);
reset = findall(fig,'Type','uibutton','Text','Defaults'); feval(reset.ButtonPushedFcn,reset,[]);
verifyEqual(testCase,mode.Value,defaults.simulation.zSamplingMode);
verifyEqual(testCase,regions.Data,defaults.simulation.zRefinementRegionsMm);
verifyEqual(testCase,extra.Value,'');
clear cleanup;
end

function localVerifyPlots(testCase,fig,nonuniform)
axes = findall(fig,'Type','axes'); found = 0;
for k = 1:numel(axes)
    if contains(string(axes(k).Title.String),'Fixed x=0')
        found = found+1;
        verifyEqual(testCase,axes(k).View,[0,90]);
        verifyEqual(testCase,axes(k).YDir,'reverse');
        if nonuniform
            verifyNotEmpty(testCase,findall(axes(k),'Type','surface'));
        else
            verifyNotEmpty(testCase,findall(axes(k),'Type','image'));
        end
    end
end
verifyEqual(testCase,found,2);
% Run catches errors in a dialog; verify no such error was swallowed.
textAreas = findall(fig,'Type','uitextarea');
for k = 1:numel(textAreas)
    verifyFalse(testCase,contains(strjoin(string(textAreas(k).Value)),'ERROR:'));
end
end
