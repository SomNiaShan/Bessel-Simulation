classdef BPM_drill_AI_app < matlab.apps.AppBase
    properties (Access = public)
        UIFigure
    end

    properties (Access = private)
        Controls
        Params
        Results
        ResultAxes
        RunButton
        ResetButton
        OutputDirButton
        LogFileButton
        OpenOutputButton
        RefreshLogButton
        StatusTextArea
        LogTextArea
        SummaryTextArea
    end

    methods (Access = public)
        function app = BPM_drill_AI_app
            app.Controls = struct();
            app.ResultAxes = struct();
            app.Params = BPM_drill_AI_app_engine('defaults');
            app.createComponents();
            app.populateControls(app.Params);
            app.appendStatus('App ready.');
            registerApp(app, app.UIFigure);

            if nargout == 0
                clear app
            end
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure);
            end
        end
    end

    methods (Access = private)
        function createComponents(app)
            app.UIFigure = uifigure( ...
                'Name', 'BPM Drill AI App', ...
                'Position', [80 80 1320 780]);

            mainGrid = uigridlayout(app.UIFigure, [1 2]);
            mainGrid.ColumnWidth = {440, '1x'};
            mainGrid.RowHeight = {'1x'};
            mainGrid.Padding = [8 8 8 8];
            mainGrid.ColumnSpacing = 8;

            leftGrid = uigridlayout(mainGrid, [3 1]);
            leftGrid.RowHeight = {'1x', 72, 130};
            leftGrid.Padding = [0 0 0 0];
            leftGrid.RowSpacing = 8;

            parameterTabs = uitabgroup(leftGrid);
            app.addParameterTab(parameterTabs, 'simulation', 'Simulation', {
                'N', 'N';
                'sizeMm', 'sizeMm (mm)';
                'zRangeMm', 'zRangeMm (mm)';
                'dzMm', 'dzMm (mm)';
                'useBPM', 'useBPM';
                'useGPU', 'useGPU'});

            app.addParameterTab(parameterTabs, 'laser', 'Laser', {
                'wavelengthMm', 'wavelengthMm (mm)';
                'powerW', 'powerW (W)';
                'repetitionRateHz', 'repetitionRateHz (Hz)';
                'pulseWidthS', 'pulseWidthS (s)'});

            app.addParameterTab(parameterTabs, 'beam', 'Beam', {
                'waistRadiusMm', 'waistRadiusMm (mm)';
                'fieldAmplitude', 'fieldAmplitude';
                'beamRadiusCm', 'beamRadiusCm (cm)'});

            app.addParameterTab(parameterTabs, 'phase', 'Phase', {
                'airyStrength', 'airyStrength';
                'airyScaleMm', 'airyScaleMm (mm)';
                'axiconIndex', 'axiconIndex';
                'axiconAngleDeg', 'axiconAngleDeg (deg)';
                'curvedMaxShiftMm', 'curvedMaxShiftMm (mm)';
                'compensationPhase', 'compensationPhase';
                'vortexCharge', 'vortexCharge';
                'helicalGamma', 'helicalGamma';
                'helicalOrder', 'helicalOrder';
                'helicalPhaseOffset', 'helicalPhaseOffset (deg)';
                'omegaInner', 'omegaInner';
                'omegaOuter', 'omegaOuter'});

            app.addParameterTab(parameterTabs, 'optics', 'Optics', {
                'lens1FocalLengthMm', 'lens1FocalLengthMm (mm)';
                'lens2FocalLengthMm', 'lens2FocalLengthMm (mm)';
                'lens1PositionMm', 'lens1PositionMm (mm)';
                'sampleOffsetFromLens2Mm', 'sampleOffsetFromLens2Mm (mm)';
                'lens1Enabled', 'lens1Enabled';
                'lens2Enabled', 'lens2Enabled';
                'sampleEnabled', 'sampleEnabled'});

            app.addParameterTab(parameterTabs, 'material', 'Material', {
                'backgroundIndex', 'backgroundIndex';
                'sampleIndex', 'sampleIndex';
                'damageThresholdWPerM2', 'damageThresholdWPerM2'});

            app.addParameterTab(parameterTabs, 'output', 'Output', {
                'write3DIntensity', 'write3DIntensity';
                'writeAllPhase', 'writeAllPhase';
                'writeHelicalPhase', 'writeHelicalPhase';
                'writeHelicalOffsetSlmBatch', 'writeHelicalOffsetSlmBatch';
                'helicalOffsetStartDeg', 'helicalOffsetStartDeg (deg)';
                'helicalOffsetEndDeg', 'helicalOffsetEndDeg (deg)';
                'helicalOffsetStepDeg', 'helicalOffsetStepDeg (deg)';
                'helicalOffsetSlmSubfolder', 'helicalOffsetSlmSubfolder';
                'writeRotatedSlmBatch', 'writeRotatedSlmBatch';
                'rotatedSlmStartAngleDeg', 'rotatedSlmStartAngleDeg (deg)';
                'rotatedSlmEndAngleDeg', 'rotatedSlmEndAngleDeg (deg)';
                'rotatedSlmStepDeg', 'rotatedSlmStepDeg (deg)';
                'rotatedSlmClockwise', 'rotatedSlmClockwise';
                'rotatedSlmSubfolder', 'rotatedSlmSubfolder';
                'plotFigures', 'plotFigures';
                'cropHalfWidthPixels', 'cropHalfWidthPixels';
                'referenceSliceIndex', 'referenceSliceIndex';
                'printProgress', 'printProgress';
                'progressIntervalSeconds', 'progressIntervalSeconds (s)';
                'writeProgressLog', 'writeProgressLog';
                'progressLogFile', 'progressLogFile';
                'outputDir', 'outputDir'});

            buttonGrid = uigridlayout(leftGrid, [2 3]);
            buttonGrid.RowHeight = {32, 32};
            buttonGrid.ColumnWidth = {'1x', '1x', '1x'};
            buttonGrid.Padding = [0 0 0 0];
            buttonGrid.RowSpacing = 6;
            buttonGrid.ColumnSpacing = 6;

            app.RunButton = uibutton(buttonGrid, 'push', ...
                'Text', 'Run', ...
                'ButtonPushedFcn', @(~, ~)app.runButtonPushed());
            app.ResetButton = uibutton(buttonGrid, 'push', ...
                'Text', 'Defaults', ...
                'ButtonPushedFcn', @(~, ~)app.resetButtonPushed());
            app.OpenOutputButton = uibutton(buttonGrid, 'push', ...
                'Text', 'Open Output', ...
                'ButtonPushedFcn', @(~, ~)app.openOutputButtonPushed());
            app.OutputDirButton = uibutton(buttonGrid, 'push', ...
                'Text', 'Output Dir', ...
                'ButtonPushedFcn', @(~, ~)app.outputDirButtonPushed());
            app.LogFileButton = uibutton(buttonGrid, 'push', ...
                'Text', 'Log File', ...
                'ButtonPushedFcn', @(~, ~)app.logFileButtonPushed());
            app.RefreshLogButton = uibutton(buttonGrid, 'push', ...
                'Text', 'Refresh Log', ...
                'ButtonPushedFcn', @(~, ~)app.refreshLogButtonPushed());

            app.StatusTextArea = uitextarea(leftGrid, 'Editable', 'off');

            rightTabs = uitabgroup(mainGrid);
            inputTab = uitab(rightTabs, 'Title', 'Input and phase');
            propagationTab = uitab(rightTabs, 'Title', 'Propagation');
            summaryTab = uitab(rightTabs, 'Title', 'Summary and log');

            inputGrid = uigridlayout(inputTab, [2 3]);
            inputGrid.Padding = [8 8 8 8];
            inputGrid.RowHeight = {'1x', '1x'};
            inputGrid.ColumnWidth = {'1x', '1x', '1x'};
            app.ResultAxes.slmPhase = app.addSquareAxes(inputGrid);
            app.ResultAxes.inputIntensity = app.addSquareAxes(inputGrid);
            app.ResultAxes.angularSpectrum = app.addSquareAxes(inputGrid);
            app.ResultAxes.helicalPhase = app.addSquareAxes(inputGrid);
            app.ResultAxes.axiconPhase = app.addSquareAxes(inputGrid);
            app.ResultAxes.vortexPhase = app.addSquareAxes(inputGrid);

            propagationGrid = uigridlayout(propagationTab, [3 1]);
            propagationGrid.Padding = [8 8 8 8];
            propagationGrid.RowHeight = {'1x', '1x', '1x'};
            app.ResultAxes.peakLog = uiaxes(propagationGrid);
            app.ResultAxes.peakLinear = uiaxes(propagationGrid);
            app.ResultAxes.onAxis = uiaxes(propagationGrid);

            summaryGrid = uigridlayout(summaryTab, [2 1]);
            summaryGrid.Padding = [8 8 8 8];
            summaryGrid.RowHeight = {150, '1x'};
            app.SummaryTextArea = uitextarea(summaryGrid, 'Editable', 'off');
            app.LogTextArea = uitextarea(summaryGrid, 'Editable', 'off');
        end

        function ax = addSquareAxes(app, parent)
            panel = uipanel(parent, 'BorderType', 'none');
            panel.AutoResizeChildren = 'off';
            ax = uiaxes(panel, 'Units', 'pixels');
            panel.SizeChangedFcn = @(src, ~)app.resizeSquareAxes(src, ax);
            app.resizeSquareAxes(panel, ax);
        end

        function resizeSquareAxes(~, panel, ax)
            if ~isvalid(panel) || ~isvalid(ax)
                return;
            end

            panelSize = panel.Position(3:4);
            inset = 6;
            sideLength = max(20, min(panelSize) - 2 * inset);
            left = (panelSize(1) - sideLength) / 2;
            bottom = (panelSize(2) - sideLength) / 2;
            ax.Position = [left, bottom, sideLength, sideLength];
        end

        function addParameterTab(app, parent, groupName, titleText, specs)
            tab = uitab(parent, 'Title', titleText);
            tabGrid = uigridlayout(tab, [1 1]);
            tabGrid.Padding = [6 6 6 6];

            panel = uipanel(tabGrid, 'BorderType', 'none');
            try
                panel.Scrollable = 'on';
            catch
            end

            rowCount = size(specs, 1);
            grid = uigridlayout(panel, [rowCount 2]);
            grid.RowHeight = repmat({30}, 1, rowCount);
            grid.ColumnWidth = {190, '1x'};
            grid.Padding = [0 0 0 0];
            grid.RowSpacing = 5;
            grid.ColumnSpacing = 8;

            for index = 1:rowCount
                fieldName = specs{index, 1};
                labelText = specs{index, 2};
                value = app.Params.(groupName).(fieldName);
                tooltip = sprintf('params.%s.%s', groupName, fieldName);

                label = uilabel(grid, 'Text', labelText, 'Tooltip', tooltip);
                label.HorizontalAlignment = 'right';

                if islogical(value)
                    control = uicheckbox(grid, 'Text', '', 'Value', value, 'Tooltip', tooltip);
                elseif ischar(value) || isstring(value)
                    control = uieditfield(grid, 'text', 'Value', char(string(value)), 'Tooltip', tooltip);
                else
                    control = uieditfield(grid, 'numeric', 'Value', double(value), 'Tooltip', tooltip);
                    control.ValueDisplayFormat = '%.12g';
                end

                app.Controls.(app.controlKey(groupName, fieldName)) = control;
            end
        end

        function runButtonPushed(app)
            app.setRunningState(true);
            runStarted = tic;
            try
                params = app.collectParams();
                app.LogTextArea.Value = {'Run started. Waiting for progress messages...'};
                params.runtimeProgressCallback = @(message)app.appendLog(message);
                app.appendStatus(sprintf('Run started: %s', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))));
                drawnow;

                results = BPM_drill_AI_app_engine('run', params);
                if isfield(results.params, 'runtimeProgressCallback')
                    results.params = rmfield(results.params, 'runtimeProgressCallback');
                end
                app.Results = results;
                app.Params = results.params;
                app.populateControls(app.Params);
                app.updateResultPreview(results);
                app.updateSummary(results);
                app.refreshLogButtonPushed();

                assignin('base', 'BPM_drill_AI_app_results', results);
                assignin('base', 'BPM_drill_AI_app_params', app.Params);
                app.appendStatus(sprintf('Run finished in %.2f s.', toc(runStarted)));
                app.appendStatus(sprintf('Output directory: %s', app.Params.output.outputDir));
            catch ME
                app.appendStatus(sprintf('ERROR: %s', ME.message));
                uialert(app.UIFigure, getReport(ME, 'extended', 'hyperlinks', 'off'), 'BPM Drill AI App');
            end
            app.setRunningState(false);
        end

        function resetButtonPushed(app)
            app.Params = BPM_drill_AI_app_engine('defaults');
            app.populateControls(app.Params);
            app.appendStatus('Parameters reset to defaults.');
        end

        function outputDirButtonPushed(app)
            currentValue = app.getTextControlValue('output', 'outputDir');
            if strlength(string(currentValue)) == 0 || exist(currentValue, 'dir') ~= 7
                currentValue = pwd;
            end
            selectedFolder = uigetdir(currentValue, 'Select output directory');
            if isequal(selectedFolder, 0)
                return;
            end
            app.Controls.(app.controlKey('output', 'outputDir')).Value = selectedFolder;
            app.appendStatus(sprintf('Output directory set: %s', selectedFolder));
        end

        function logFileButtonPushed(app)
            currentValue = app.getTextControlValue('output', 'progressLogFile');
            if strlength(string(currentValue)) == 0
                currentValue = fullfile(app.getTextControlValue('output', 'outputDir'), 'BPM_drill_AI_progress.log');
            end
            [fileName, pathName] = uiputfile({'*.log;*.txt', 'Log files (*.log, *.txt)'; '*.*', 'All files'}, ...
                'Select progress log file', currentValue);
            if isequal(fileName, 0)
                return;
            end
            logFile = fullfile(pathName, fileName);
            app.Controls.(app.controlKey('output', 'progressLogFile')).Value = logFile;
            app.appendStatus(sprintf('Progress log file set: %s', logFile));
        end

        function openOutputButtonPushed(app)
            params = app.collectParams();
            outputDir = params.output.outputDir;
            if strlength(string(outputDir)) == 0
                outputDir = BPM_drill_AI_app_engine('defaults');
                outputDir = outputDir.output.outputDir;
            end
            if exist(outputDir, 'dir') ~= 7
                mkdir(outputDir);
            end

            if ispc
                winopen(outputDir);
            else
                web(outputDir, '-browser');
            end
            app.appendStatus(sprintf('Opened output directory: %s', outputDir));
        end

        function refreshLogButtonPushed(app)
            params = app.collectParams();
            logFile = params.output.progressLogFile;
            if strlength(string(logFile)) == 0
                defaults = BPM_drill_AI_app_engine('defaults');
                logFile = defaults.output.progressLogFile;
            end

            if exist(logFile, 'file') ~= 2
                app.LogTextArea.Value = {sprintf('Log file does not exist yet: %s', logFile)};
                return;
            end

            logText = string(fileread(logFile));
            logLines = splitlines(logText);
            logLines(logLines == "") = [];
            if numel(logLines) > 300
                logLines = logLines(end-299:end);
            end
            app.LogTextArea.Value = cellstr(logLines);
        end

        function params = collectParams(app)
            params = app.Params;
            groups = app.groupNames();
            for groupIndex = 1:numel(groups)
                groupName = groups{groupIndex};
                fields = fieldnames(params.(groupName));
                for fieldIndex = 1:numel(fields)
                    fieldName = fields{fieldIndex};
                    key = app.controlKey(groupName, fieldName);
                    if ~isfield(app.Controls, key)
                        continue;
                    end

                    control = app.Controls.(key);
                    oldValue = params.(groupName).(fieldName);
                    if islogical(oldValue)
                        params.(groupName).(fieldName) = logical(control.Value);
                    elseif ischar(oldValue) || isstring(oldValue)
                        params.(groupName).(fieldName) = char(string(control.Value));
                    else
                        params.(groupName).(fieldName) = control.Value;
                    end
                end
            end
            params = app.normalizeAndValidateParams(params);
        end

        function params = normalizeAndValidateParams(app, params)
            integerFields = {
                'simulation', 'N';
                'output', 'cropHalfWidthPixels';
                'output', 'referenceSliceIndex'};

            for index = 1:size(integerFields, 1)
                groupName = integerFields{index, 1};
                fieldName = integerFields{index, 2};
                params.(groupName).(fieldName) = round(params.(groupName).(fieldName));
            end

            numericPaths = app.numericParameterPaths(params);
            for index = 1:size(numericPaths, 1)
                groupName = numericPaths{index, 1};
                fieldName = numericPaths{index, 2};
                value = params.(groupName).(fieldName);
                if ~isnumeric(value) || ~isscalar(value) || ~isfinite(value)
                    error('params.%s.%s must be a finite scalar number.', groupName, fieldName);
                end
            end

            if params.simulation.N < 2
                error('params.simulation.N must be at least 2.');
            end
            if params.simulation.sizeMm <= 0 || params.simulation.dzMm <= 0 || params.simulation.zRangeMm < 0
                error('Simulation sizeMm and dzMm must be positive, and zRangeMm must be nonnegative.');
            end
            if params.phase.airyScaleMm == 0
                error('params.phase.airyScaleMm must be nonzero.');
            end
            if params.output.helicalOffsetStepDeg == 0
                error('params.output.helicalOffsetStepDeg must be nonzero.');
            end
            if params.output.rotatedSlmStepDeg == 0
                error('params.output.rotatedSlmStepDeg must be nonzero.');
            end
            if params.output.cropHalfWidthPixels < 0
                error('params.output.cropHalfWidthPixels must be nonnegative.');
            end
            if params.output.referenceSliceIndex < 1
                error('params.output.referenceSliceIndex must be at least 1.');
            end
        end

        function populateControls(app, params)
            groups = app.groupNames();
            for groupIndex = 1:numel(groups)
                groupName = groups{groupIndex};
                fields = fieldnames(params.(groupName));
                for fieldIndex = 1:numel(fields)
                    fieldName = fields{fieldIndex};
                    key = app.controlKey(groupName, fieldName);
                    if ~isfield(app.Controls, key)
                        continue;
                    end

                    control = app.Controls.(key);
                    value = params.(groupName).(fieldName);
                    if islogical(value)
                        control.Value = logical(value);
                    elseif ischar(value) || isstring(value)
                        control.Value = char(string(value));
                    else
                        control.Value = double(value);
                    end
                end
            end
        end

        function updateResultPreview(app, results)
            app.showImage(app.ResultAxes.slmPhase, angle(results.inputField), 'Phase on SLM');
            app.showImage(app.ResultAxes.inputIntensity, abs(results.inputField).^2, 'Input beam |E|^2');
            app.showImage(app.ResultAxes.angularSpectrum, abs(results.angularSpectrum).^2, 'Angular spectrum |F|^2');
            app.showImage(app.ResultAxes.helicalPhase, results.phase.helical, 'Helical phase');
            app.showImage(app.ResultAxes.axiconPhase, angle(exp(1i * results.phase.axicon)), 'Axicon phase');
            app.showImage(app.ResultAxes.vortexPhase, angle(exp(1i * results.phase.vortex)), 'Vortex phase');

            app.showCrossSection(app.ResultAxes.peakLog, ...
                results.postprocess.zImageMm, ...
                results.postprocess.yImageMm, ...
                results.postprocess.crossSectionPeakPowerDensityLog, ...
                'Peak power density log scale', results);

            app.showCrossSection(app.ResultAxes.peakLinear, ...
                results.postprocess.zImageMm, ...
                results.postprocess.yImageMm, ...
                results.postprocess.crossSectionPeakPowerDensityWPerMm2, ...
                'Peak power density (W/mm^2)', results);

            ax = app.ResultAxes.onAxis;
            cla(ax);
            plot(ax, results.postprocess.zImageMm, results.postprocess.onAxisPeakPowerDensityWPerMm2);
            hold(ax, 'on');
            yline(ax, results.postprocess.thresholdWPerMm2, 'Color', 'r');
            hold(ax, 'off');
            title(ax, 'On-axis peak power density');
            xlabel(ax, 'z (mm)');
            ylabel(ax, 'W/mm^2');
            xlim(ax, [min(results.postprocess.zImageMm), max(results.postprocess.zImageMm)]);
            peakPowerDensity = max(results.postprocess.onAxisPeakPowerDensityWPerMm2);
            if isfinite(peakPowerDensity) && peakPowerDensity > 0
                ylim(ax, [0, peakPowerDensity * 1.5]);
            end
        end

        function showImage(app, ax, data, titleText)
            cla(ax);
            imagesc(ax, data);
            axis(ax, 'image');
            axis(ax, 'off');
            title(ax, titleText);
            colorbar(ax);
        end

        function showCrossSection(app, ax, zValues, yValues, data, titleText, results)
            cla(ax);
            imagesc(ax, zValues, yValues, data);
            axis(ax, 'on');
            title(ax, titleText);
            xlabel(ax, 'z (mm)');
            ylabel(ax, 'y (mm)');
            colorbar(ax);
            app.plotActiveMarkers(ax, results);
        end

        function plotActiveMarkers(app, ax, results)
            hold(ax, 'on');
            if results.params.optics.lens1Enabled
                xline(ax, results.derived.optics.lens1PositionMm, 'Color', 'r');
            end
            if results.params.optics.lens2Enabled
                xline(ax, results.derived.optics.lens2PositionMm, 'Color', 'r');
            end
            if results.params.optics.sampleEnabled
                xline(ax, results.derived.optics.samplePositionMm, 'Color', 'w');
            end
            hold(ax, 'off');
        end

        function updateSummary(app, results)
            lines = {
                sprintf('Elapsed: %.2f s', results.elapsedSeconds);
                sprintf('Output directory: %s', results.params.output.outputDir);
                sprintf('Grid: N=%d, size=%.12g mm, zRange=%.12g mm, dz=%.12g mm', ...
                    results.params.simulation.N, results.params.simulation.sizeMm, ...
                    results.params.simulation.zRangeMm, results.params.simulation.dzMm);
                sprintf('Z slices: %d', numel(results.propagation.zValuesMm));
                sprintf('Pulse peak power: %.12g W', results.derived.pulsePeakPowerW);
                sprintf('beta0=%.12g deg, beta1=%.12g deg, betaMaterial=%.12g deg', ...
                    results.derived.optics.beta0Deg, results.derived.optics.beta1Deg, ...
                    results.derived.optics.betaMaterialDeg);
                sprintf('Reference slice index: %d', results.postprocess.referenceSliceIndex);
                sprintf('Progress log: %s', results.params.output.progressLogFile)};
            app.SummaryTextArea.Value = lines;
        end

        function appendStatus(app, message)
            newLine = string(message);
            if isempty(app.StatusTextArea) || ~isvalid(app.StatusTextArea)
                return;
            end

            currentLines = string(app.StatusTextArea.Value);
            currentLines(currentLines == "") = [];
            currentLines = [currentLines; newLine];
            if numel(currentLines) > 80
                currentLines = currentLines(end-79:end);
            end
            app.StatusTextArea.Value = cellstr(currentLines);
            drawnow limitrate;
        end

        function appendLog(app, message)
            if isempty(app.LogTextArea) || ~isvalid(app.LogTextArea)
                return;
            end

            currentLines = string(app.LogTextArea.Value);
            currentLines(currentLines == "Run started. Waiting for progress messages...") = [];
            currentLines(currentLines == "") = [];
            currentLines = [currentLines; string(message)];
            if numel(currentLines) > 500
                currentLines = currentLines(end-499:end);
            end
            app.LogTextArea.Value = cellstr(currentLines);
            drawnow limitrate;
        end

        function setRunningState(app, isRunning)
            if isRunning
                app.RunButton.Enable = 'off';
                app.ResetButton.Enable = 'off';
            else
                app.RunButton.Enable = 'on';
                app.ResetButton.Enable = 'on';
            end
            drawnow limitrate;
        end

        function value = getTextControlValue(app, groupName, fieldName)
            control = app.Controls.(app.controlKey(groupName, fieldName));
            value = char(string(control.Value));
        end

        function key = controlKey(app, groupName, fieldName)
            key = sprintf('%s__%s', groupName, fieldName);
        end

        function groups = groupNames(app)
            groups = {'simulation', 'laser', 'beam', 'phase', 'optics', 'material', 'output'};
        end

        function paths = numericParameterPaths(app, params)
            paths = {};
            groups = app.groupNames();
            for groupIndex = 1:numel(groups)
                groupName = groups{groupIndex};
                fields = fieldnames(params.(groupName));
                for fieldIndex = 1:numel(fields)
                    fieldName = fields{fieldIndex};
                    value = params.(groupName).(fieldName);
                    if isnumeric(value)
                        paths(end + 1, :) = {groupName, fieldName}; %#ok<AGROW>
                    end
                end
            end
        end
    end
end
