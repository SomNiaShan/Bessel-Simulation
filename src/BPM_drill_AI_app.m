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
        RunButtonIdleText
        RunButtonIdleBackgroundColor
        RunButtonIdleFontColor
        ResetButton
        OutputDirButton
        StatusTextArea
        LogTextArea
        SummaryTextArea
        IsRunning = false
        IsSyncingAxiconControls = false
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
                'Position', [80 80 1380 820]);

            mainGrid = uigridlayout(app.UIFigure, [1 2]);
            mainGrid.ColumnWidth = {505, '1x'};
            mainGrid.RowHeight = {'1x'};
            mainGrid.Padding = [8 8 8 8];
            mainGrid.ColumnSpacing = 8;

            leftGrid = uigridlayout(mainGrid, [3 1]);
            leftGrid.RowHeight = {'1x', 40, 130};
            leftGrid.Padding = [0 0 0 0];
            leftGrid.RowSpacing = 8;

            parameterTabs = uitabgroup(leftGrid);
            app.addParameterTab(parameterTabs, 'simulation', 'Simulation', {
                'N', 'N';
                'sizeMm', 'sizeMm (mm)';
                'zRangeMm', 'zRangeMm (mm)';
                'dzMm', 'dzMm (mm)'});

            app.addParameterTab(parameterTabs, 'laser', 'Laser', {
                'wavelengthMm', 'Wavelength (nm)';
                'powerW', 'powerW (W)';
                'repetitionRateHz', 'repetitionRateHz (kHz)';
                'pulseWidthS', 'pulseWidthS (fs)'});

            app.addParameterTab(parameterTabs, 'beam', 'Beam', {
                'waistRadiusMm', 'waistRadiusMm (mm)';
                'fieldAmplitude', 'fieldAmplitude'});

            app.addParameterTab(parameterTabs, 'phase', 'Phase', {
                'airyStrength', 'airyStrength';
                'airyScaleMm', 'airyScaleMm (mm)';
                'axiconMode', 'Axicon definition';
                'axiconConeAngleDeg', 'Cone angle beta (deg)';
                'axiconRadialPeriodMm', 'Radial period (mm)';
                'axiconRadialPeriodPx', 'Radial period (px)';
                'axiconIndex', 'Axicon refractive index (n)';
                'axiconAngleDeg', 'Physical base angle alpha (deg)';
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
                'lens2PositionMm', 'lens2PositionMm (mm)';
                'samplePositionMm', 'samplePositionMm (mm)';
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
                'outputDir', 'outputDir'});

            buttonGrid = uigridlayout(leftGrid, [1 3]);
            buttonGrid.RowHeight = {32};
            buttonGrid.ColumnWidth = {'1x', '1x', '1x'};
            buttonGrid.Padding = [0 0 0 0];
            buttonGrid.ColumnSpacing = 6;

            app.RunButton = uibutton(buttonGrid, 'push', ...
                'Text', 'Run', ...
                'ButtonPushedFcn', @(~, ~)app.runButtonPushed());
            app.RunButtonIdleText = app.RunButton.Text;
            app.RunButtonIdleBackgroundColor = app.RunButton.BackgroundColor;
            app.RunButtonIdleFontColor = app.RunButton.FontColor;
            app.ResetButton = uibutton(buttonGrid, 'push', ...
                'Text', 'Defaults', ...
                'ButtonPushedFcn', @(~, ~)app.resetButtonPushed());
            app.OutputDirButton = uibutton(buttonGrid, 'push', ...
                'Text', 'Output Dir', ...
                'ButtonPushedFcn', @(~, ~)app.outputDirButtonPushed());

            app.StatusTextArea = uitextarea(leftGrid, 'Editable', 'off');

            rightTabs = uitabgroup(mainGrid);
            propagationTab = uitab(rightTabs, 'Title', 'Propagation');
            inputTab = uitab(rightTabs, 'Title', 'Input and phase');
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
            grid = uigridlayout(panel, [rowCount 3]);
            grid.RowHeight = repmat({30}, 1, rowCount);
            grid.ColumnWidth = {190, 20, '1x'};
            grid.Padding = [0 0 0 0];
            grid.RowSpacing = 5;
            grid.ColumnSpacing = 6;
            try
                grid.Scrollable = 'on';
            catch
            end

            for index = 1:rowCount
                fieldName = specs{index, 1};
                labelText = specs{index, 2};
                value = app.Params.(groupName).(fieldName);
                tooltip = app.controlTooltip(groupName, fieldName);
                displayValue = app.paramValueToControlValue(groupName, fieldName, value);

                label = uilabel(grid, 'Text', labelText, 'Tooltip', tooltip);
                label.HorizontalAlignment = 'right';
                label.Layout.Row = index;
                label.Layout.Column = 1;

                infoLabel = uilabel(grid, 'Text', 'i', 'Tooltip', tooltip);
                infoLabel.HorizontalAlignment = 'center';
                infoLabel.FontWeight = 'bold';
                infoLabel.FontColor = [0.2 0.45 0.85];
                infoLabel.Layout.Row = index;
                infoLabel.Layout.Column = 2;

                if strcmp(groupName, 'phase') && strcmp(fieldName, 'axiconMode')
                    control = uidropdown(grid, ...
                        'Items', app.axiconModeOptions(), ...
                        'Value', char(string(displayValue)), ...
                        'Tooltip', tooltip, ...
                        'ValueChangedFcn', @(~, ~)app.axiconModeChanged());
                elseif islogical(value)
                    control = uicheckbox(grid, 'Text', '', 'Value', logical(displayValue), 'Tooltip', tooltip);
                elseif ischar(value) || isstring(value)
                    control = uieditfield(grid, 'text', 'Value', char(string(displayValue)), 'Tooltip', tooltip);
                else
                    control = uieditfield(grid, 'numeric', 'Value', double(displayValue), 'Tooltip', tooltip);
                    control.ValueDisplayFormat = '%.12g';
                end
                if app.isAxiconSyncControl(groupName, fieldName) && ...
                        ~(strcmp(groupName, 'phase') && strcmp(fieldName, 'axiconMode'))
                    control.ValueChangedFcn = @(~, ~)app.axiconParameterChanged();
                end
                control.Layout.Row = index;
                control.Layout.Column = 3;

                app.Controls.(app.controlKey(groupName, fieldName)) = control;
            end
        end

        function runButtonPushed(app)
            if app.IsRunning
                return;
            end
            app.setRunningState(true);
            runStarted = tic;
            try
                params = app.collectParams();
                displayOutputDir = params.output.outputDir;
                params.output.writeProgressLog = false;
                params.output.progressLogFile = '';
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
                app.Params.output.outputDir = displayOutputDir;
                app.populateControls(app.Params);
                app.updateResultPreview(results);
                app.updateSummary(results);

                assignin('base', 'BPM_drill_AI_app_results', results);
                assignin('base', 'BPM_drill_AI_app_params', app.Params);
                app.appendStatus(sprintf('Run finished in %.2f s.', toc(runStarted)));
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
                        params.(groupName).(fieldName) = app.controlValueToParamValue(groupName, fieldName, control.Value);
                    end
                end
            end
            params = app.normalizeAndValidateParams(params);
        end

        function params = normalizeAndValidateParams(app, params)
            params.simulation.useBPM = true;

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
            if params.laser.wavelengthMm <= 0
                error('Wavelength must be positive.');
            end
            if params.phase.airyScaleMm == 0
                error('params.phase.airyScaleMm must be nonzero.');
            end
            if ~any(strcmp(params.phase.axiconMode, app.axiconModeOptions()))
                error('params.phase.axiconMode must be coneAngle, radialPeriodMm, radialPeriodPx, or physicalEquivalent.');
            end
            if params.material.backgroundIndex <= 0 || params.material.sampleIndex <= 0
                error('Material refractive indices must be positive.');
            end
            switch params.phase.axiconMode
                case 'coneAngle'
                    if params.phase.axiconConeAngleDeg <= 0 || params.phase.axiconConeAngleDeg >= 90
                        error('Axicon cone angle beta must be between 0 and 90 degrees.');
                    end
                case 'radialPeriodMm'
                    if params.phase.axiconRadialPeriodMm <= 0
                        error('Axicon radial period in mm must be positive.');
                    end
                case 'radialPeriodPx'
                    if params.phase.axiconRadialPeriodPx <= 0
                        error('Axicon radial period in pixels must be positive.');
                    end
                case 'physicalEquivalent'
                    if params.phase.axiconIndex <= 0
                        error('Axicon refractive index must be positive.');
                    end
                    if params.phase.axiconAngleDeg <= 0
                        error('Physical axicon base angle alpha must be positive.');
                    end
            end
            if params.optics.lens1FocalLengthMm <= 0 || params.optics.lens2FocalLengthMm <= 0
                error('Lens focal lengths must be positive.');
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
                        control.Value = double(app.paramValueToControlValue(groupName, fieldName, value));
                    end
                end
            end
            app.updateAxiconControlStates();
            app.syncAxiconEquivalentControls();
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
                'Center y-z peak power density log scale', results);

            app.showCrossSection(app.ResultAxes.peakLinear, ...
                results.postprocess.zImageMm, ...
                results.postprocess.yImageMm, ...
                results.postprocess.crossSectionPeakPowerDensityWPerMm2, ...
                'Center y-z peak power density (W/mm^2)', results);

            ax = app.ResultAxes.onAxis;
            app.clearAxesForRedraw(ax);
            plot(ax, results.postprocess.zImageMm, results.postprocess.onAxisPeakPowerDensityWPerMm2, ...
                'DisplayName', 'On-axis');
            hold(ax, 'on');
            plot(ax, results.postprocess.zImageMm, results.postprocess.slicePeakPowerDensityWPerMm2, ...
                '--', 'DisplayName', 'Slice peak');
            yline(ax, results.postprocess.thresholdWPerMm2, 'Color', 'r', 'DisplayName', 'Threshold');
            title(ax, 'On-axis and slice-peak power density');
            xlabel(ax, 'z (mm)');
            ylabel(ax, 'W/mm^2');
            xlim(ax, [min(results.postprocess.zImageMm), max(results.postprocess.zImageMm)]);
            peakPowerDensity = max([results.postprocess.onAxisPeakPowerDensityWPerMm2(:); results.postprocess.slicePeakPowerDensityWPerMm2(:)]);
            if isfinite(peakPowerDensity) && peakPowerDensity > 0
                ylim(ax, [0, peakPowerDensity * 1.5]);
            end
            app.plotActiveMarkers(ax, results);
            app.addBlankColorbarSlot(ax);
            hold(ax, 'off');
            legend(ax, 'Location', 'northeast');
        end

        function showImage(~, ax, data, titleText)
            cla(ax);
            imagesc(ax, data);
            axis(ax, 'image');
            axis(ax, 'off');
            title(ax, titleText);
            colorbar(ax);
        end

        function showCrossSection(app, ax, zValues, yValues, data, titleText, results)
            app.clearAxesForRedraw(ax);
            imagesc(ax, zValues, yValues, data);
            axis(ax, 'on');
            title(ax, titleText);
            xlabel(ax, 'z (mm)');
            ylabel(ax, 'y (mm)');
            colorbar(ax);
            xlim(ax, [min(zValues), max(zValues)]);
            ylim(ax, [min(yValues), max(yValues)]);
            app.plotActiveMarkers(ax, results);
        end

        function clearAxesForRedraw(~, ax)
            delete(findall(ax, 'Type', 'ConstantLine'));
            cla(ax);
        end

        function addBlankColorbarSlot(~, ax)
            slotColor = ax.Color;
            figureHandle = ancestor(ax, 'figure');
            if ~isempty(figureHandle) && isnumeric(figureHandle.Color) && numel(figureHandle.Color) == 3
                slotColor = figureHandle.Color;
            end
            if ~isnumeric(slotColor) || numel(slotColor) ~= 3
                slotColor = [0 0 0];
            end

            try
                colormap(ax, repmat(slotColor, 256, 1));
            catch
            end

            colorbarHandle = colorbar(ax);
            colorbarHandle.Limits = [0 1];
            colorbarHandle.Ticks = linspace(0, 1, 6);
            colorbarHandle.TickLabels = {'0', '2', '4', '6', '8', '10'};
            colorbarHandle.Color = slotColor;
            colorbarHandle.Box = 'off';
            colorbarHandle.Label.String = '';
        end

        function plotActiveMarkers(app, ax, results)
            hold(ax, 'on');
            if results.params.optics.lens1Enabled
                app.plotOpticMarker(ax, results.derived.optics.lens1PositionMm, 'Lens 1', 'r');
            end
            if results.params.optics.lens2Enabled
                app.plotOpticMarker(ax, results.derived.optics.lens2PositionMm, 'Lens 2', 'r');
            end
            if results.params.optics.sampleEnabled
                app.plotOpticMarker(ax, results.derived.optics.samplePositionMm, 'Sample', 'w');
            end
            hold(ax, 'off');
        end

        function plotOpticMarker(~, ax, zPositionMm, labelText, lineColor)
            marker = xline(ax, zPositionMm, ...
                'Color', lineColor, ...
                'LineWidth', 1, ...
                'Label', labelText, ...
                'LabelOrientation', 'aligned', ...
                'LabelVerticalAlignment', 'top', ...
                'LabelHorizontalAlignment', 'center', ...
                'HandleVisibility', 'off');

            try
                marker.FontWeight = 'bold';
            catch
            end
        end

        function updateSummary(app, results)
            lines = {
                sprintf('Elapsed: %.2f s', results.elapsedSeconds);
                sprintf('Output directory: %s', results.params.output.outputDir);
                sprintf('Grid: N=%d, size=%.12g mm, zRange=%.12g mm, dz=%.12g mm', ...
                    results.params.simulation.N, results.params.simulation.sizeMm, ...
                    results.params.simulation.zRangeMm, results.params.simulation.dzMm);
                sprintf('Wavelength: %.12g nm', app.mmToNm(results.params.laser.wavelengthMm));
                sprintf('Axicon mode: %s', results.derived.axicon.mode);
                sprintf('Axicon effective beta: %.12g deg, kr=%.12g rad/mm', ...
                    results.derived.axicon.coneAngleDeg, results.derived.axicon.krRadPerMm);
                sprintf('Axicon radial period: %.12g mm (%.12g px)', ...
                    results.derived.axicon.radialPeriodMm, results.derived.axicon.radialPeriodPx);
                sprintf('Physical-equivalent fields: n=%.12g, alpha=%.12g deg', ...
                    results.derived.axicon.physicalIndex, results.derived.axicon.physicalBaseAngleDeg);
                sprintf('Z slices: %d', numel(results.propagation.zValuesMm));
                sprintf('Pulse peak power: %.12g W', results.derived.pulsePeakPowerW);
                sprintf('M=%.12g, M2=%.12g', ...
                    results.derived.optics.M, results.derived.optics.M2);
                sprintf('beta0=%.12g deg, beta1=%.12g deg, betaMaterial=%.12g deg', ...
                    results.derived.optics.beta0Deg, results.derived.optics.beta1Deg, ...
                    results.derived.optics.betaMaterialDeg);
                sprintf('Reference slice index: %d', results.postprocess.referenceSliceIndex);
                sprintf('Center pixel: row=%d, col=%d, x=%.12g mm, y=%.12g mm', ...
                    results.postprocess.centerRowIndex, results.postprocess.centerColumnIndex, ...
                    results.postprocess.centerXMm, results.postprocess.centerYMm);
                sprintf('On-axis max: %.12g W/mm^2 at z=%.12g mm', ...
                    results.postprocess.onAxisMaxPeakPowerDensityWPerMm2, results.postprocess.onAxisMaxZMm);
                sprintf('Slice-peak max: %.12g W/mm^2 at z=%.12g mm', ...
                    results.postprocess.sliceMaxPeakPowerDensityWPerMm2, results.postprocess.sliceMaxZMm)};
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
            app.scrollTextAreaToBottom(app.StatusTextArea);
            drawnow limitrate;
        end

        function scrollTextAreaToBottom(~, textArea)
            try
                scroll(textArea, 'bottom');
            catch
            end
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
            app.IsRunning = isRunning;
            if isRunning
                app.RunButton.Enable = 'on';
                app.RunButton.Text = 'Running...';
                app.RunButton.BackgroundColor = [1.0 0.78 0.12];
                app.RunButton.FontColor = [0.05 0.05 0.05];
                app.ResetButton.Enable = 'off';
            else
                app.RunButton.Enable = 'on';
                app.RunButton.Text = app.RunButtonIdleText;
                app.RunButton.BackgroundColor = app.RunButtonIdleBackgroundColor;
                app.RunButton.FontColor = app.RunButtonIdleFontColor;
                app.ResetButton.Enable = 'on';
            end
            drawnow limitrate;
        end

        function value = getTextControlValue(app, groupName, fieldName)
            control = app.Controls.(app.controlKey(groupName, fieldName));
            value = char(string(control.Value));
        end

        function axiconModeChanged(app)
            app.updateAxiconControlStates();
            app.syncAxiconEquivalentControls();
            modeControlKey = app.controlKey('phase', 'axiconMode');
            if isfield(app.Controls, modeControlKey)
                app.appendStatus(sprintf('Axicon definition mode: %s', char(string(app.Controls.(modeControlKey).Value))));
            end
        end

        function axiconParameterChanged(app)
            app.syncAxiconEquivalentControls();
        end

        function updateAxiconControlStates(app)
            modeKey = app.controlKey('phase', 'axiconMode');
            if ~isfield(app.Controls, modeKey)
                return;
            end

            mode = char(string(app.Controls.(modeKey).Value));
            axiconFields = {'axiconConeAngleDeg', 'axiconRadialPeriodMm', ...
                'axiconRadialPeriodPx', 'axiconIndex', 'axiconAngleDeg'};
            for index = 1:numel(axiconFields)
                key = app.controlKey('phase', axiconFields{index});
                if isfield(app.Controls, key)
                    app.Controls.(key).Enable = 'off';
                end
            end

            switch mode
                case 'coneAngle'
                    activeFields = {'axiconConeAngleDeg'};
                case 'radialPeriodMm'
                    activeFields = {'axiconRadialPeriodMm'};
                case 'radialPeriodPx'
                    activeFields = {'axiconRadialPeriodPx'};
                case 'physicalEquivalent'
                    activeFields = {'axiconIndex', 'axiconAngleDeg'};
                otherwise
                    activeFields = {};
            end

            for index = 1:numel(activeFields)
                key = app.controlKey('phase', activeFields{index});
                if isfield(app.Controls, key)
                    app.Controls.(key).Enable = 'on';
                end
            end
        end

        function syncAxiconEquivalentControls(app)
            if app.IsSyncingAxiconControls
                return;
            end
            requiredKeys = {
                app.controlKey('phase', 'axiconMode');
                app.controlKey('phase', 'axiconConeAngleDeg');
                app.controlKey('phase', 'axiconRadialPeriodMm');
                app.controlKey('phase', 'axiconRadialPeriodPx');
                app.controlKey('phase', 'axiconIndex');
                app.controlKey('phase', 'axiconAngleDeg');
                app.controlKey('simulation', 'N');
                app.controlKey('simulation', 'sizeMm');
                app.controlKey('laser', 'wavelengthMm');
                app.controlKey('material', 'backgroundIndex')};
            for index = 1:numel(requiredKeys)
                if ~isfield(app.Controls, requiredKeys{index})
                    return;
                end
            end

            app.IsSyncingAxiconControls = true;
            cleanup = onCleanup(@()app.clearAxiconSyncFlag());
            try
                mode = char(string(app.Controls.(app.controlKey('phase', 'axiconMode')).Value));
                sampleCount = round(app.Controls.(app.controlKey('simulation', 'N')).Value);
                gridSizeMm = app.Controls.(app.controlKey('simulation', 'sizeMm')).Value;
                wavelengthMm = app.nmToMm(app.Controls.(app.controlKey('laser', 'wavelengthMm')).Value);
                backgroundIndex = app.Controls.(app.controlKey('material', 'backgroundIndex')).Value;
                axiconIndex = app.Controls.(app.controlKey('phase', 'axiconIndex')).Value;

                if sampleCount <= 0 || gridSizeMm <= 0 || wavelengthMm <= 0 || ...
                        backgroundIndex <= 0 || axiconIndex <= 0
                    return;
                end

                gridPixelPitchMm = gridSizeMm / sampleCount;
                kBackground = 2 * pi * backgroundIndex / wavelengthMm;
                [coneAngleRad, krRadPerMm] = app.resolveAxiconControlsToConeAndKr(mode, kBackground, gridPixelPitchMm);
                if ~isfinite(coneAngleRad) || ~isfinite(krRadPerMm) || ...
                        coneAngleRad <= 0 || coneAngleRad >= pi / 2 || ...
                        krRadPerMm <= 0 || krRadPerMm >= kBackground
                    return;
                end

                coneAngleDeg = rad2deg(coneAngleRad);
                radialPeriodMm = 2 * pi / krRadPerMm;
                radialPeriodPx = radialPeriodMm / gridPixelPitchMm;
                physicalBaseAngleDeg = app.equivalentPhysicalBaseAngleDeg(coneAngleRad, axiconIndex, backgroundIndex);

                app.setAxiconEquivalentValue('axiconConeAngleDeg', coneAngleDeg, mode, 'coneAngle');
                app.setAxiconEquivalentValue('axiconRadialPeriodMm', radialPeriodMm, mode, 'radialPeriodMm');
                app.setAxiconEquivalentValue('axiconRadialPeriodPx', radialPeriodPx, mode, 'radialPeriodPx');
                if ~strcmp(mode, 'physicalEquivalent') && isfinite(physicalBaseAngleDeg)
                    app.Controls.(app.controlKey('phase', 'axiconAngleDeg')).Value = physicalBaseAngleDeg;
                end
            catch
            end
            clear cleanup;
        end

        function clearAxiconSyncFlag(app)
            app.IsSyncingAxiconControls = false;
        end

        function [coneAngleRad, krRadPerMm] = resolveAxiconControlsToConeAndKr(app, mode, kBackground, gridPixelPitchMm)
            switch mode
                case 'coneAngle'
                    coneAngleRad = deg2rad(app.Controls.(app.controlKey('phase', 'axiconConeAngleDeg')).Value);
                    krRadPerMm = kBackground * sin(coneAngleRad);
                case 'radialPeriodMm'
                    radialPeriodMm = app.Controls.(app.controlKey('phase', 'axiconRadialPeriodMm')).Value;
                    krRadPerMm = 2 * pi / radialPeriodMm;
                    coneAngleRad = asin(krRadPerMm / kBackground);
                case 'radialPeriodPx'
                    radialPeriodPx = app.Controls.(app.controlKey('phase', 'axiconRadialPeriodPx')).Value;
                    radialPeriodMm = radialPeriodPx * gridPixelPitchMm;
                    krRadPerMm = 2 * pi / radialPeriodMm;
                    coneAngleRad = asin(krRadPerMm / kBackground);
                case 'physicalEquivalent'
                    axiconIndex = app.Controls.(app.controlKey('phase', 'axiconIndex')).Value;
                    backgroundIndex = app.Controls.(app.controlKey('material', 'backgroundIndex')).Value;
                    physicalBaseAngleRad = deg2rad(app.Controls.(app.controlKey('phase', 'axiconAngleDeg')).Value);
                    coneAngleRad = asin((axiconIndex / backgroundIndex) * sin(physicalBaseAngleRad)) - physicalBaseAngleRad;
                    krRadPerMm = kBackground * sin(coneAngleRad);
                otherwise
                    coneAngleRad = NaN;
                    krRadPerMm = NaN;
            end
        end

        function baseAngleDeg = equivalentPhysicalBaseAngleDeg(~, coneAngleRad, axiconIndex, backgroundIndex)
            indexRatio = axiconIndex / backgroundIndex;
            denominator = indexRatio - cos(coneAngleRad);
            if denominator <= 0
                baseAngleDeg = NaN;
                return;
            end
            baseAngleDeg = rad2deg(atan2(sin(coneAngleRad), denominator));
        end

        function setAxiconEquivalentValue(app, fieldName, value, currentMode, fieldMode)
            if ~strcmp(currentMode, fieldMode) && isfinite(value)
                app.Controls.(app.controlKey('phase', fieldName)).Value = value;
            end
        end

        function options = axiconModeOptions(~)
            options = {'coneAngle', 'radialPeriodMm', 'radialPeriodPx', 'physicalEquivalent'};
        end

        function isMatch = isAxiconSyncControl(~, groupName, fieldName)
            paramPath = sprintf('%s.%s', groupName, fieldName);
            syncPaths = {
                'simulation.N';
                'simulation.sizeMm';
                'laser.wavelengthMm';
                'material.backgroundIndex';
                'phase.axiconMode';
                'phase.axiconConeAngleDeg';
                'phase.axiconRadialPeriodMm';
                'phase.axiconRadialPeriodPx';
                'phase.axiconIndex';
                'phase.axiconAngleDeg'};
            isMatch = any(strcmp(paramPath, syncPaths));
        end

        function key = controlKey(~, groupName, fieldName)
            key = sprintf('%s__%s', groupName, fieldName);
        end

        function tooltip = controlTooltip(app, groupName, fieldName)
            description = app.parameterDescription(groupName, fieldName);
            tooltip = description;
            if app.isWavelengthControl(groupName, fieldName)
                tooltip = sprintf('%s\nDisplayed in nm; stored internally in mm.', tooltip);
            elseif app.isRepetitionRateControl(groupName, fieldName)
                tooltip = sprintf('%s\nDisplayed in kHz; stored internally in Hz.', tooltip);
            elseif app.isPulseWidthControl(groupName, fieldName)
                tooltip = sprintf('%s\nDisplayed in fs; stored internally in s.', tooltip);
            end
        end

        function description = parameterDescription(~, groupName, fieldName)
            paramPath = sprintf('%s.%s', groupName, fieldName);
            switch paramPath
                case 'simulation.N'
                    description = 'Number of transverse samples. The computational plane is N x N; larger values improve resolution but increase runtime and memory use.';
                case 'simulation.sizeMm'
                    description = 'Physical width of the transverse simulation window, in mm. Larger values show a wider field; smaller values sample the center more densely.';
                case 'simulation.zRangeMm'
                    description = 'Total propagation distance along z, in mm. This controls how much axial evolution is simulated and exported.';
                case 'simulation.dzMm'
                    description = 'BPM propagation step size along z, in mm. Smaller values give more propagation detail but run more slowly.';

                case 'laser.wavelengthMm'
                    description = 'Laser wavelength. It affects the wave number, phase maps, propagation kernel, and propagation scale inside the sample.';
                case 'laser.powerW'
                    description = 'Average laser power used for peak-power-density estimates in post-processing. It does not change the normalized field shape.';
                case 'laser.repetitionRateHz'
                    description = 'Pulse repetition rate. At fixed average power, a higher repetition rate gives lower energy per pulse.';
                case 'laser.pulseWidthS'
                    description = 'Pulse duration used to estimate peak power. Shorter pulses give higher estimated peak power.';

                case 'beam.waistRadiusMm'
                    description = 'Input Gaussian beam waist radius, in mm. This controls the incident spot size and initial intensity envelope.';
                case 'beam.fieldAmplitude'
                    description = 'Scale factor for the input field amplitude. It scales the complex field amplitude and is mainly useful for quick debugging.';
                case 'phase.airyStrength'
                    description = 'Strength of the cubic Airy phase term. Set to 0 to disable the Airy phase.';
                case 'phase.airyScaleMm'
                    description = 'Transverse scale of the Airy phase, in mm. This controls how quickly the cubic phase changes with position.';
                case 'phase.axiconMode'
                    description = 'Selects which axicon parameter is active. The engine converts the selected definition to one radial phase slope and cone angle.';
                case 'phase.axiconConeAngleDeg'
                    description = 'Effective holographic axicon cone angle beta, in degrees. Active when axiconMode is coneAngle.';
                case 'phase.axiconRadialPeriodMm'
                    description = 'Radial 2pi phase period of the SLM axicon, in mm. Active when axiconMode is radialPeriodMm.';
                case 'phase.axiconRadialPeriodPx'
                    description = 'Radial 2pi phase period in pixels of the generated phase matrix. Active when axiconMode is radialPeriodPx.';
                case 'phase.axiconIndex'
                    description = 'Refractive index of the equivalent physical axicon. Active only when axiconMode is physicalEquivalent.';
                case 'phase.axiconAngleDeg'
                    description = 'Base angle alpha of the equivalent physical axicon, in degrees. Active only when axiconMode is physicalEquivalent.';
                case 'phase.curvedMaxShiftMm'
                    description = 'Target lateral shift at the end of the curved Bessel trajectory. Set to 0 to disable the curved trajectory.';
                case 'phase.compensationPhase'
                    description = 'Extra compensation phase hook. It is currently applied as an additional global phase term.';
                case 'phase.vortexCharge'
                    description = 'Topological charge l for the vortex phase. Set to 0 to disable the vortex phase.';
                case 'phase.helicalGamma'
                    description = 'Modulation depth of the helical phase term. This controls the strength of the helical contribution.';
                case 'phase.helicalOrder'
                    description = 'Angular order m of the helical phase. This controls the number of angular periods around one full turn.';
                case 'phase.helicalPhaseOffset'
                    description = 'Initial angular offset of the helical phase, in degrees. Batch scans vary this parameter.';
                case 'phase.omegaInner'
                    description = 'Radial chirp frequency parameter near the center. This affects phase oscillation near the beam axis.';
                case 'phase.omegaOuter'
                    description = 'Radial chirp frequency parameter near the edge. Together with omegaInner, it sets the radial frequency sweep.';

                case 'optics.lens1FocalLengthMm'
                    description = 'Focal length of lens 1, in mm.';
                case 'optics.lens2FocalLengthMm'
                    description = 'Focal length of lens 2, in mm.';
                case 'optics.lens1PositionMm'
                    description = 'z position of lens 1, in mm. BPM applies the lens-1 phase when propagation reaches this position.';
                case 'optics.lens2PositionMm'
                    description = 'z position of lens 2, in mm. BPM applies the lens-2 phase when propagation reaches this position.';
                case 'optics.samplePositionMm'
                    description = 'Absolute z position of the sample, in mm. BPM switches to sample propagation when it reaches this position.';
                case 'optics.lens1Enabled'
                    description = 'Applies lens 1 during BPM propagation. When off, the parameter is kept but the lens phase is not applied.';
                case 'optics.lens2Enabled'
                    description = 'Applies lens 2 during BPM propagation. When off, the lens-2 phase is not applied.';
                case 'optics.sampleEnabled'
                    description = 'Switches BPM propagation to the sample refractive index at the sample position. When off, propagation stays in the background medium.';

                case 'material.backgroundIndex'
                    description = 'Background refractive index used for the background wave number and phase calculations.';
                case 'material.sampleIndex'
                    description = 'Sample refractive index used after propagation switches into the sample medium.';
                case 'material.damageThresholdWPerM2'
                    description = 'Material damage threshold, in W/m^2. It is used as a reference threshold line in result plots.';

                case 'output.write3DIntensity'
                    description = 'Exports the 3D intensity stack as a multipage TIFF. If BPM is off, only one z=0 slice is available.';
                case 'output.writeAllPhase'
                    description = 'Exports the total SLM phase bitmap after all enabled phase terms have been combined.';
                case 'output.writeHelicalPhase'
                    description = 'Exports only the helical phase bitmap, useful for checking the helical term by itself.';
                case 'output.writeHelicalOffsetSlmBatch'
                    description = 'Batch-scans helicalPhaseOffset and exports one total SLM phase bitmap per offset.';
                case 'output.helicalOffsetStartDeg'
                    description = 'Start angle for the helicalPhaseOffset batch scan, in degrees.';
                case 'output.helicalOffsetEndDeg'
                    description = 'End angle for the helicalPhaseOffset batch scan, in degrees.';
                case 'output.helicalOffsetStepDeg'
                    description = 'Angular step for the helicalPhaseOffset batch scan, in degrees. Must not be 0.';
                case 'output.helicalOffsetSlmSubfolder'
                    description = 'Subfolder under the output directory where helical-offset batch SLM images are saved.';
                case 'output.writeRotatedSlmBatch'
                    description = 'Batch-exports geometrically rotated copies of the generated SLM bitmap. This is not a physical phase scan.';
                case 'output.rotatedSlmStartAngleDeg'
                    description = 'Start angle for rotated SLM bitmap batch export, in degrees.';
                case 'output.rotatedSlmEndAngleDeg'
                    description = 'End angle for rotated SLM bitmap batch export, in degrees.';
                case 'output.rotatedSlmStepDeg'
                    description = 'Angular step for rotated SLM bitmap batch export, in degrees. Must not be 0.';
                case 'output.rotatedSlmClockwise'
                    description = 'Rotation direction for batch export. On means clockwise; off means counterclockwise.';
                case 'output.rotatedSlmSubfolder'
                    description = 'Subfolder under the output directory where rotated SLM batch images are saved.';
                case 'output.plotFigures'
                    description = 'Also opens MATLAB figure windows. When off, the app still shows previews in the right-hand panels.';
                case 'output.cropHalfWidthPixels'
                    description = 'Half-width, in pixels, of the centered crop used when exporting 3D intensity. Larger values export a wider view.';
                case 'output.referenceSliceIndex'
                    description = 'Reference z-slice index used for power-density normalization. If it exceeds the stack length, the last slice is used.';
                case 'output.printProgress'
                    description = 'Prints BPM progress messages to the MATLAB or VS Code terminal.';
                case 'output.progressIntervalSeconds'
                    description = 'Time interval between BPM progress messages, in seconds. Smaller values report more frequently.';
                case 'output.outputDir'
                    description = 'Output directory. If empty, the app uses the project outputs folder.';
                otherwise
                    description = 'Controls the corresponding simulation, phase, optics, material, or output behavior.';
            end
        end

        function value = paramValueToControlValue(app, groupName, fieldName, value)
            if app.isWavelengthControl(groupName, fieldName)
                value = app.mmToNm(value);
            elseif app.isRepetitionRateControl(groupName, fieldName)
                value = app.hzToKHz(value);
            elseif app.isPulseWidthControl(groupName, fieldName)
                value = app.sToFs(value);
            end
        end

        function value = controlValueToParamValue(app, groupName, fieldName, value)
            if app.isWavelengthControl(groupName, fieldName)
                value = app.nmToMm(value);
            elseif app.isRepetitionRateControl(groupName, fieldName)
                value = app.kHzToHz(value);
            elseif app.isPulseWidthControl(groupName, fieldName)
                value = app.fsToS(value);
            end
        end

        function isMatch = isWavelengthControl(~, groupName, fieldName)
            isMatch = strcmp(groupName, 'laser') && strcmp(fieldName, 'wavelengthMm');
        end

        function isMatch = isRepetitionRateControl(~, groupName, fieldName)
            isMatch = strcmp(groupName, 'laser') && strcmp(fieldName, 'repetitionRateHz');
        end

        function isMatch = isPulseWidthControl(~, groupName, fieldName)
            isMatch = strcmp(groupName, 'laser') && strcmp(fieldName, 'pulseWidthS');
        end

        function valueNm = mmToNm(~, valueMm)
            valueNm = valueMm * 1e6;
        end

        function valueMm = nmToMm(~, valueNm)
            valueMm = valueNm / 1e6;
        end

        function valueKHz = hzToKHz(~, valueHz)
            valueKHz = valueHz / 1e3;
        end

        function valueHz = kHzToHz(~, valueKHz)
            valueHz = valueKHz * 1e3;
        end

        function valueFs = sToFs(~, valueS)
            valueFs = valueS * 1e15;
        end

        function valueS = fsToS(~, valueFs)
            valueS = valueFs / 1e15;
        end

        function groups = groupNames(~)
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
