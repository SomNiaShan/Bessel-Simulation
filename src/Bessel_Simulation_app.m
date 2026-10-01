classdef Bessel_Simulation_app < matlab.apps.AppBase
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
        OutputButton
        ResetButton
        OutputDirButton
        StatusTextArea
        LogTextArea
        SummaryTextArea
        BeamModelExplanationTextArea
        ZControls
        ZSelectedRows = []
        IsRunning = false
        IsSyncingAxiconControls = false
    end

    methods (Access = public)
        function app = Bessel_Simulation_app
            app.Controls = struct();
            app.ResultAxes = struct();
            app.ZControls = struct();
            app.Params = Bessel_Simulation_app_defaults();
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
                'Name', 'Bessel Simulation App', ...
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
                'dzMm', 'Base z spacing (mm)';
                'propagationMethod', 'Propagation method';
                'adaptiveOutputN', 'Focus ROI samples';
                'adaptiveOutputSizeMm', 'Focus ROI size (mm; 0 auto)';
                'bandLimitASM', 'Band-limit free-space ASM';
                'maxWorkingGiB', 'Memory budget (GiB)'});
            app.addZSamplingTab(parameterTabs);

            app.addParameterTab(parameterTabs, 'laser', 'Laser', {
                'wavelengthMm', 'Wavelength (nm)';
                'powerW', 'powerW (W)';
                'repetitionRateHz', 'repetitionRateHz (kHz)';
                'pulseWidthS', 'pulseWidthS (fs)'});

            app.addParameterTab(parameterTabs, 'beam', 'Beam', {
                'waistRadiusMm', 'waistRadiusMm (mm)';
                'fieldAmplitude', 'fieldAmplitude';
                'beamQualityM2', 'beamQualityM2';
                'beamQualityModel', 'M2 model';
                'hgCoherentPhaseXDeg', 'HG x phase (deg)';
                'hgCoherentPhaseYDeg', 'HG y phase (deg)'});

            app.addParameterTab(parameterTabs, 'phase', 'Phase', {
                'airyStrength', 'airyStrength';
                'airyScaleMm', 'airyScaleMm (mm)';
                'apertureRadiusMm', 'Aperture radius (mm)';
                'referenceRadiusMm', 'Phase reference radius (mm)';
                'referencePixelPitchMm', 'Phase reference pixel (mm)';
                'axiconGeometry', 'Axicon geometry';
                'axiconOrientationDeg', '1D normal angle (deg)';
                'axiconMode', 'Axicon definition';
                'axiconConeAngleDeg', 'Cone angle beta (deg)';
                'axiconRadialPeriodMm', 'Phase period (mm)';
                'axiconRadialPeriodPx', 'Phase period (px)';
                'axiconRadialCycles', 'Cycles to edge';
                'axiconIndex', 'Axicon refractive index (n)';
                'axiconAngleDeg', 'Physical base angle alpha (deg)';
                'curvedMaxShiftXMm', 'curvedMaxShiftX (mm)';
                'curvedMaxShiftYMm', 'curvedMaxShiftY (mm)';
                'compensationPhase', 'compensationPhase';
                'vortexCharge', 'vortexCharge';
                'checkerboardBesselEnabled', 'Checkerboard Bessel';
                'checkerboardTileSizePx', 'Checker tile (px)';
                'checkerboardTc1', 'TC_1';
                'checkerboardTc2', 'TC_2';
                'checkerboardBeta1Deg', 'beta_1 (deg)';
                'checkerboardBeta2Deg', 'beta_2 (deg)';
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
                'layoutMode', 'Lens layout';
                'sampleOffsetFromLens2Mm', 'Sample offset from L2 (mm)';
                'lens1Enabled', 'lens1Enabled';
                'lens2Enabled', 'lens2Enabled';
                'sampleEnabled', 'sampleEnabled'});

            app.addParameterTab(parameterTabs, 'material', 'Material', {
                'backgroundIndex', 'backgroundIndex';
                'sampleIndex', 'sampleIndex';
                'damageThresholdWPerM2', 'damageThresholdWPerM2'});

            app.addParameterTab(parameterTabs, 'output', 'Output', {
                'write3DIntensity', 'write3DIntensity';
                'writeRawIntensity', 'writeRawIntensity (MAT)';
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
                'assignResultsToBaseWorkspace', 'Assign results to base';
                'progressIntervalSeconds', 'progressIntervalSeconds (s)';
                'outputDir', 'outputDir'});

            buttonGrid = uigridlayout(leftGrid, [1 4]);
            buttonGrid.RowHeight = {32};
            buttonGrid.ColumnWidth = {'1x', '1x', '1x', '1x'};
            buttonGrid.Padding = [0 0 0 0];
            buttonGrid.ColumnSpacing = 6;

            app.RunButton = uibutton(buttonGrid, 'push', ...
                'Text', 'Run', ...
                'ButtonPushedFcn', @(~, ~)app.runButtonPushed());
            app.RunButtonIdleText = app.RunButton.Text;
            app.RunButtonIdleBackgroundColor = app.RunButton.BackgroundColor;
            app.RunButtonIdleFontColor = app.RunButton.FontColor;
            app.OutputButton = uibutton(buttonGrid, 'push', ...
                'Text', 'Output', ...
                'ButtonPushedFcn', @(~, ~)app.outputButtonPushed());
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

            inputGrid = uigridlayout(inputTab, [2 4]);
            inputGrid.Padding = [8 8 8 8];
            inputGrid.RowHeight = {'1x', '1x'};
            inputGrid.ColumnWidth = {'1x', '1x', '1x', '1x'};
            app.ResultAxes.slmPhase = app.addSquareAxes(inputGrid);
            app.ResultAxes.inputIntensity = app.addSquareAxes(inputGrid);
            app.ResultAxes.angularSpectrum = app.addSquareAxes(inputGrid);
            app.ResultAxes.checkerboardBesselPhase = app.addSquareAxes(inputGrid);
            app.ResultAxes.helicalPhase = app.addSquareAxes(inputGrid);
            app.ResultAxes.axiconPhase = app.addSquareAxes(inputGrid);
            app.ResultAxes.vortexPhase = app.addSquareAxes(inputGrid);
            app.ResultAxes.checkerboardMask = app.addSquareAxes(inputGrid);

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

        function addZSamplingTab(app,parent)
            tab = uitab(parent,'Title','Z sampling');
            grid = uigridlayout(tab,[9 2]);
            grid.ColumnWidth = {'1x','1x'};
            grid.RowHeight = {30,44,180,30,22,30,30,34,'1x'};
            grid.Scrollable = 'on';
            uilabel(grid,'Text','Sampling mode');
            app.ZControls.mode = uidropdown(grid,'Items',{'uniform','local'}, ...
                'Tag','zSamplingMode','ValueChangedFcn',@(~,~)app.zSamplingChanged());
            description = uilabel(grid,'Text', ...
                'Keep the base grid; add real calculated planes inside these regions. Overlaps use the smallest local dz.', ...
                'WordWrap','on');
            description.Layout.Row = 2; description.Layout.Column = [1 2];
            app.ZControls.regions = uitable(grid,'Data',zeros(0,3), ...
                'ColumnName',{'Start z (mm)','End z (mm)','Local dz (mm)'}, ...
                'ColumnEditable',[true true true],'RowName',[], ...
                'Tag','zRefinementRegionsMm', ...
                'CellSelectionCallback',@(~,event)app.zRegionSelected(event), ...
                'CellEditCallback',@(~,~)app.invalidateZPreview());
            app.ZControls.regions.Layout.Row = 3;
            app.ZControls.regions.Layout.Column = [1 2];
            app.ZControls.add = uibutton(grid,'Text','Add region','Tag','zAddRegion', ...
                'ButtonPushedFcn',@(~,~)app.addZRegion());
            app.ZControls.add.Layout.Row = 4; app.ZControls.add.Layout.Column = 1;
            app.ZControls.remove = uibutton(grid,'Text','Remove selected','Tag','zRemoveRegion', ...
                'ButtonPushedFcn',@(~,~)app.removeZRegion());
            app.ZControls.remove.Layout.Row = 4; app.ZControls.remove.Layout.Column = 2;
            label = uilabel(grid,'Text','Extra exact planes (mm; e.g. 220.5, 221.05)');
            label.Layout.Row = 5; label.Layout.Column = [1 2];
            app.ZControls.extra = uieditfield(grid,'text','Tag','zExtraPlanesMm', ...
                'ValueChangedFcn',@(~,~)app.invalidateZPreview());
            app.ZControls.extra.Layout.Row = 6; app.ZControls.extra.Layout.Column = [1 2];
            label = uilabel(grid,'Text','Maximum z planes');
            label.Layout.Row = 7; label.Layout.Column = 1;
            app.ZControls.cap = uieditfield(grid,'numeric','Value',20000,'Limits',[1 Inf], ...
                'Tag','maxZPlanes','ValueChangedFcn',@(~,~)app.invalidateZPreview());
            app.ZControls.cap.Layout.Row = 7; app.ZControls.cap.Layout.Column = 2;
            app.ZControls.preview = uibutton(grid,'Text','Preview sampling','Tag','zPreview', ...
                'ButtonPushedFcn',@(~,~)app.previewZSampling());
            app.ZControls.preview.Layout.Row = 8; app.ZControls.preview.Layout.Column = [1 2];
            app.ZControls.info = uitextarea(grid,'Editable','off','Tag','zSamplingPreview', ...
                'Value',{'Click Preview sampling to check actual planes and memory.'});
            app.ZControls.info.Layout.Row = 9; app.ZControls.info.Layout.Column = [1 2];
        end

        function zRegionSelected(app,event)
            if isempty(event.Indices)
                app.ZSelectedRows = [];
            else
                app.ZSelectedRows = unique(event.Indices(:,1));
            end
        end

        function addZRegion(app)
            range = app.Controls.simulation__zRangeMm.Value;
            dz = app.Controls.simulation__dzMm.Value;
            if range <= 0, return; end
            app.ZControls.regions.Data(end+1,:) = [0,range,dz];
            app.invalidateZPreview();
        end

        function removeZRegion(app)
            rows = app.ZSelectedRows;
            rows = rows(rows >= 1 & rows <= size(app.ZControls.regions.Data,1));
            if isempty(rows), return; end
            app.ZControls.regions.Data(rows,:) = [];
            app.ZSelectedRows = [];
            app.invalidateZPreview();
        end

        function zSamplingChanged(app)
            if strcmp(app.Controls.simulation__propagationMethod.Value,'legacyASM') && ...
                    strcmp(app.ZControls.mode.Value,'local')
                app.ZControls.mode.Value = 'uniform';
                app.appendStatus('legacyASM requires uniform z sampling. Refinement settings are retained.');
            end
            app.updateZControlStates();
            app.invalidateZPreview();
        end

        function updateZControlStates(app)
            if isempty(fieldnames(app.ZControls)), return; end
            enabled = ~app.IsRunning;
            legacy = strcmp(app.Controls.simulation__propagationMethod.Value,'legacyASM');
            app.ZControls.mode.Enable = app.onOff(enabled && ~legacy);
            app.ZControls.cap.Enable = app.onOff(enabled);
            app.ZControls.preview.Enable = app.onOff(enabled);
            local = enabled && ~legacy && strcmp(app.ZControls.mode.Value,'local');
            app.ZControls.regions.Enable = app.onOff(local);
            app.ZControls.extra.Enable = app.onOff(local);
            app.ZControls.add.Enable = app.onOff(local && app.Controls.simulation__zRangeMm.Value > 0);
            app.ZControls.remove.Enable = app.onOff(local);
        end

        function value = onOff(~,condition)
            if condition, value = 'on'; else, value = 'off'; end
        end

        function invalidateZPreview(app)
            app.ZControls.info.Value = {'Sampling settings changed. Click Preview sampling.'};
        end

        function previewZSampling(app)
            try
                preflight = Bessel_Simulation_app_engine('plan',app.collectParams());
                plan = preflight.zPlan;
                lines = {sprintf('Mode: %s; planes: %d (base %d, added %d)', ...
                    plan.mode,plan.planeCount,plan.basePlaneCount,plan.addedPlaneCount)};
                if ~isempty(plan.zSpacingMm)
                    lines{end+1} = sprintf('Actual spacing: %.9g to %.9g mm',plan.minSpacingMm,plan.maxSpacingMm);
                end
                for k = 1:size(plan.effectiveSegmentsMm,1)
                    lines{end+1} = sprintf('%.9g to %.9g mm: dz <= %.9g mm',plan.effectiveSegmentsMm(k,:)); %#ok<AGROW>
                end
                if ~isempty(preflight.memory)
                    m = preflight.memory;
                    lines{end+1} = sprintf('ROI stack: %.3f GiB; estimated total: %.3f / %.3f GiB', ...
                        m.intensityStackGiB,m.totalGiB,m.budgetGiB);
                    if ~m.withinBudget, lines{end+1} = 'Over memory budget: Run will reject these settings.'; end
                end
                app.ZControls.info.Value = lines;
            catch exception
                app.ZControls.info.Value = {exception.message};
            end
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
            colorbarReserve = 58;
            sideLength = max(20, min(panelSize(2) - 2 * inset, panelSize(1) - 2 * inset - colorbarReserve));
            left = (panelSize(1) - sideLength - colorbarReserve) / 2;
            bottom = (panelSize(2) - sideLength) / 2;
            ax.Position = [max(0, left), max(0, bottom), sideLength, sideLength];
        end

        function addParameterTab(app, parent, groupName, titleText, specs)
            tab = uitab(parent, 'Title', titleText);
            isBeamTab = strcmp(groupName, 'beam');
            rowCount = size(specs, 1);
            if isBeamTab
                tabGrid = uigridlayout(tab, [2 1]);
                tabGrid.RowHeight = {rowCount * 35 + 8, '1x'};
                tabGrid.RowSpacing = 8;
            else
                tabGrid = uigridlayout(tab, [1 1]);
            end
            tabGrid.Padding = [6 6 6 6];

            panel = uipanel(tabGrid, 'BorderType', 'none');
            panel.Layout.Row = 1;
            panel.Layout.Column = 1;
            try
                panel.Scrollable = 'on';
            catch
            end

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

                if strcmp(groupName, 'phase') && strcmp(fieldName, 'axiconGeometry')
                    control = uidropdown(grid, ...
                        'Items', app.axiconGeometryOptions(), ...
                        'Value', char(string(displayValue)), ...
                        'Tooltip', tooltip, ...
                        'ValueChangedFcn', @(~, ~)app.axiconGeometryChanged());
                elseif strcmp(groupName, 'phase') && strcmp(fieldName, 'axiconMode')
                    control = uidropdown(grid, ...
                        'Items', app.axiconModeOptions(), ...
                        'Value', char(string(displayValue)), ...
                        'Tooltip', tooltip, ...
                        'ValueChangedFcn', @(~, ~)app.axiconModeChanged());
                elseif strcmp(groupName, 'beam') && strcmp(fieldName, 'beamQualityModel')
                    control = uidropdown(grid, ...
                        'Items', app.beamQualityModelOptions(), ...
                        'Value', char(string(displayValue)), ...
                        'Tooltip', tooltip, ...
                        'ValueChangedFcn', @(~, ~)app.beamQualityModelChanged());
                elseif strcmp(groupName, 'simulation') && strcmp(fieldName, 'propagationMethod')
                    control = uidropdown(grid, 'Items', {'adaptiveCollins','legacyASM'}, ...
                        'Value', char(string(displayValue)), 'Tooltip', tooltip, ...
                        'ValueChangedFcn',@(~,~)app.zSamplingChanged());
                elseif strcmp(groupName, 'optics') && strcmp(fieldName, 'layoutMode')
                    control = uidropdown(grid, 'Items', {'manual','telescopeLocked'}, ...
                        'Value', char(string(displayValue)), 'Tooltip', tooltip);
                elseif islogical(value)
                    control = uicheckbox(grid, 'Text', '', 'Value', logical(displayValue), 'Tooltip', tooltip);
                elseif ischar(value) || isstring(value)
                    control = uieditfield(grid, 'text', 'Value', char(string(displayValue)), 'Tooltip', tooltip);
                else
                    control = uieditfield(grid, 'numeric', 'Value', double(displayValue), 'Tooltip', tooltip);
                    control.ValueDisplayFormat = '%.12g';
                end
                if strcmp(groupName, 'phase') && strcmp(fieldName, 'checkerboardBesselEnabled')
                    control.ValueChangedFcn = @(~, ~)app.checkerboardBesselEnabledChanged();
                elseif app.isAxiconSyncControl(groupName, fieldName) && ...
                        ~(strcmp(groupName, 'phase') && strcmp(fieldName, 'axiconMode'))
                    control.ValueChangedFcn = @(~, ~)app.axiconParameterChanged();
                elseif app.isBeamExplanationControl(groupName, fieldName) && ...
                        ~(strcmp(groupName, 'beam') && strcmp(fieldName, 'beamQualityModel'))
                    control.ValueChangedFcn = @(~, ~)app.beamQualityParameterChanged();
                end
                control.Layout.Row = index;
                control.Layout.Column = 3;

                app.Controls.(app.controlKey(groupName, fieldName)) = control;
                control.Tag = app.controlKey(groupName, fieldName);
                if strcmp(groupName,'simulation') && ~strcmp(fieldName,'propagationMethod')
                    control.ValueChangedFcn = @(~,~)app.zSamplingChanged();
                end
            end

            if isBeamTab
                app.BeamModelExplanationTextArea = uitextarea(tabGrid, ...
                    'Editable', 'off', ...
                    'Value', {'Select an M^2 model to see how it is simulated.'});
                app.BeamModelExplanationTextArea.Layout.Row = 2;
                app.BeamModelExplanationTextArea.Layout.Column = 1;
                app.BeamModelExplanationTextArea.FontSize = 12;
            end
        end

        function runButtonPushed(app)
            if app.IsRunning
                return;
            end
            app.setRunningState(true);
            runningStateCleanup = onCleanup(@()app.setRunningState(false));
            runStarted = tic;
            try
                app.Results = [];
                params = app.collectParams();
                interactiveOutputParams = params.output;
                runParams = app.suppressRunOutput(params);
                app.LogTextArea.Value = {'Run started. Waiting for progress messages...'};
                runParams.runtimeProgressCallback = @(message)app.appendLog(message);
                app.appendStatus(sprintf('Run started: %s', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))));
                app.appendStatus(app.simulationEstimateMessage(runParams));
                drawnow;

                results = Bessel_Simulation_app_engine('run', runParams);
                if isfield(results.params, 'runtimeProgressCallback')
                    results.params = rmfield(results.params, 'runtimeProgressCallback');
                end
                app.Params = results.params;
                app.Params.output = interactiveOutputParams;
                app.populateControls(app.Params);
                app.appendStatus('Updating result preview...');
                app.updateResultPreview(results);
                app.updateSummary(results);
                app.Results = results;
                app.appendStatus(sprintf('Run finished in %.2f s.', toc(runStarted)));
            catch ME
                app.appendStatus(sprintf('ERROR: %s', ME.message));
                if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                    uialert(app.UIFigure, getReport(ME, 'extended', 'hyperlinks', 'off'), 'Bessel Simulation App');
                end
            end
            clear runningStateCleanup;
        end

        function resetButtonPushed(app)
            app.Results = [];
            app.Params = Bessel_Simulation_app_defaults();
            app.populateControls(app.Params);
            app.appendStatus('Parameters reset to defaults.');
        end

        function outputButtonPushed(app)
            if app.IsRunning
                return;
            end
            if isempty(app.Results) || ~isstruct(app.Results)
                app.appendStatus('ERROR: Run once before using Output.');
                uialert(app.UIFigure, 'Run the simulation once before exporting output files.', 'Bessel Simulation App');
                return;
            end

            app.setRunningState(true, 'Outputting...');
            runningStateCleanup = onCleanup(@()app.setRunningState(false));
            exportStarted = tic;
            try
                results = app.Results;
                exportParams = results.params;
                exportParams.output = app.collectOutputParams(exportParams.output);
                if ~app.hasSelectedOutputAction(exportParams.output)
                    error('No output option is selected. Enable at least one write* output option in the Output tab.');
                end

                exportParams.output.writeProgressLog = false;
                exportParams.output.progressLogFile = '';
                exportParams.runtimeProgressCallback = @(message)app.appendLog(message);
                app.appendStatus(sprintf('Output started: %s', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))));
                drawnow;

                payload = struct('results', results, 'params', exportParams);
                results = Bessel_Simulation_app_engine('export', payload);
                if isfield(results.params, 'runtimeProgressCallback')
                    results.params = rmfield(results.params, 'runtimeProgressCallback');
                end
                app.Results = results;
                app.Params.output = results.params.output;
                app.appendStatus(sprintf('Output finished in %.2f s. Directory: %s', ...
                    toc(exportStarted), results.params.output.outputDir));
            catch ME
                app.appendStatus(sprintf('ERROR: %s', ME.message));
                if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                    uialert(app.UIFigure, getReport(ME, 'extended', 'hyperlinks', 'off'), 'Bessel Simulation App');
                end
            end
            clear runningStateCleanup;
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
            params.simulation.zSamplingMode = app.ZControls.mode.Value;
            params.simulation.zRefinementRegionsMm = app.ZControls.regions.Data;
            params.simulation.zExtraPlanesMm = bessel_parse_z_planes(app.ZControls.extra.Value);
            params.simulation.maxZPlanes = app.ZControls.cap.Value;
            params = app.normalizeAndValidateParams(params);
        end

        function outputParams = collectOutputParams(app, outputParams)
            fields = fieldnames(outputParams);
            for fieldIndex = 1:numel(fields)
                fieldName = fields{fieldIndex};
                key = app.controlKey('output', fieldName);
                if ~isfield(app.Controls, key)
                    continue;
                end

                control = app.Controls.(key);
                oldValue = outputParams.(fieldName);
                if islogical(oldValue)
                    outputParams.(fieldName) = logical(control.Value);
                elseif ischar(oldValue) || isstring(oldValue)
                    outputParams.(fieldName) = char(string(control.Value));
                else
                    outputParams.(fieldName) = app.controlValueToParamValue('output', fieldName, control.Value);
                end
            end

            outputParams.cropHalfWidthPixels = round(outputParams.cropHalfWidthPixels);
            outputParams.referenceSliceIndex = round(outputParams.referenceSliceIndex);

            numericFields = fieldnames(outputParams);
            for fieldIndex = 1:numel(numericFields)
                fieldName = numericFields{fieldIndex};
                value = outputParams.(fieldName);
                if isnumeric(value) && (~isscalar(value) || ~isfinite(value))
                    error('params.output.%s must be a finite scalar number.', fieldName);
                end
            end
            if outputParams.helicalOffsetStepDeg == 0
                error('params.output.helicalOffsetStepDeg must be nonzero.');
            end
            if outputParams.rotatedSlmStepDeg == 0
                error('params.output.rotatedSlmStepDeg must be nonzero.');
            end
            if outputParams.cropHalfWidthPixels < 0
                error('params.output.cropHalfWidthPixels must be nonnegative.');
            end
            if outputParams.referenceSliceIndex < 1
                error('params.output.referenceSliceIndex must be at least 1.');
            end
        end

        function params = suppressRunOutput(~, params)
            outputActionFields = {
                'write3DIntensity';
                'writeRawIntensity';
                'writeAllPhase';
                'writeHelicalPhase';
                'writeHelicalOffsetSlmBatch';
                'writeRotatedSlmBatch';
                'plotFigures';
                'printProgress';
                'writeProgressLog';
                'assignResultsToBaseWorkspace'};

            for fieldIndex = 1:numel(outputActionFields)
                fieldName = outputActionFields{fieldIndex};
                if isfield(params.output, fieldName)
                    params.output.(fieldName) = false;
                end
            end

            if isfield(params.output, 'progressLogFile')
                params.output.progressLogFile = '';
            end
        end

        function hasAction = hasSelectedOutputAction(~, outputParams)
            hasAction = outputParams.write3DIntensity || ...
                outputParams.writeRawIntensity || ...
                outputParams.writeAllPhase || ...
                outputParams.writeHelicalPhase || ...
                outputParams.writeHelicalOffsetSlmBatch || ...
                outputParams.writeRotatedSlmBatch || ...
                outputParams.assignResultsToBaseWorkspace;
        end

        function params = normalizeAndValidateParams(app, params)
            params.simulation.useBPM = true;

            integerFields = {
                'simulation', 'N';
                'simulation', 'adaptiveOutputN';
                'phase', 'checkerboardTileSizePx';
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
                if ~isnumeric(value) || ~isscalar(value) || ...
                        (~isfinite(value) && ~app.allowsInfiniteParameter(groupName, fieldName, value))
                    error('params.%s.%s must be a finite scalar number.', groupName, fieldName);
                end
            end

            if params.simulation.N < 2
                error('params.simulation.N must be at least 2.');
            end
            if params.simulation.sizeMm <= 0 || params.simulation.dzMm <= 0 || params.simulation.zRangeMm < 0
                error('Simulation sizeMm and dzMm must be positive, and zRangeMm must be nonnegative.');
            end
            if ~any(strcmp(params.simulation.propagationMethod, {'adaptiveCollins','legacyASM'}))
                error('propagationMethod must be adaptiveCollins or legacyASM.');
            end
            if params.simulation.adaptiveOutputN < 2 || params.simulation.adaptiveOutputSizeMm < 0 || ...
                    params.simulation.maxWorkingGiB <= 0
                error('Adaptive output N must be >=2, ROI size >=0, and memory budget >0.');
            end
            if params.laser.wavelengthMm <= 0
                error('Wavelength must be positive.');
            end
            if params.beam.waistRadiusMm <= 0
                error('params.beam.waistRadiusMm must be positive.');
            end
            if params.beam.beamQualityM2 < 1
                error('params.beam.beamQualityM2 must be at least 1.');
            end
            if ~any(strcmp(params.beam.beamQualityModel, app.beamQualityModelOptions()))
                error('params.beam.beamQualityModel must be effectiveGaussian, coherentHG, or incoherentHG.');
            end
            if params.phase.airyScaleMm == 0
                error('params.phase.airyScaleMm must be nonzero.');
            end
            if params.phase.apertureRadiusMm < 0
                error('params.phase.apertureRadiusMm must be nonnegative. Use 0 for a fully open aperture.');
            end
            if params.phase.referenceRadiusMm <= 0 || params.phase.referencePixelPitchMm <= 0
                error('Phase reference radius and pixel pitch must be positive.');
            end
            if params.phase.checkerboardBesselEnabled
                if params.phase.checkerboardTileSizePx < 1
                    error('params.phase.checkerboardTileSizePx must be at least 1 when checkerboard Bessel phase is enabled.');
                end
                if abs(params.phase.checkerboardBeta1Deg) >= 90 || abs(params.phase.checkerboardBeta2Deg) >= 90
                    error('Checkerboard Bessel beta_1 and beta_2 must be between -90 and 90 degrees.');
                end
            end
            if ~any(strcmp(params.phase.axiconMode, app.axiconModeOptions()))
                error('params.phase.axiconMode must be coneAngle, radialPeriodMm, radialPeriodPx, radialCycles, or physicalEquivalent.');
            end
            if ~any(strcmp(params.phase.axiconGeometry, app.axiconGeometryOptions()))
                error('params.phase.axiconGeometry must be circular or linear1D.');
            end
            if strcmp(params.phase.axiconGeometry, 'linear1D') && ...
                    (params.phase.curvedMaxShiftXMm ~= 0 || params.phase.curvedMaxShiftYMm ~= 0)
                error('Set curvedMaxShiftXMm and curvedMaxShiftYMm to 0 when axiconGeometry is linear1D.');
            end
            if params.material.backgroundIndex <= 0 || params.material.sampleIndex <= 0
                error('Material refractive indices must be positive.');
            end
            switch params.phase.axiconMode
                case 'coneAngle'
                    if abs(params.phase.axiconConeAngleDeg) >= 90
                        error('Axicon cone angle beta must be between -90 and 90 degrees.');
                    end
                case 'radialPeriodMm'
                    if params.phase.axiconRadialPeriodMm == 0
                        error('Axicon radial period in mm must be nonzero. Use Inf for beta = 0.');
                    end
                case 'radialPeriodPx'
                    if params.phase.axiconRadialPeriodPx == 0
                        error('Axicon radial period in pixels must be nonzero. Use Inf for beta = 0.');
                    end
                case 'radialCycles'
                    if ~isfinite(params.phase.axiconRadialCycles)
                        error('Axicon radial cycles must be finite. Use 0 for beta = 0.');
                    end
                case 'physicalEquivalent'
                    if params.phase.axiconIndex <= 0
                        error('Axicon refractive index must be positive.');
                    end
            end
            if params.optics.lens1FocalLengthMm <= 0 || params.optics.lens2FocalLengthMm <= 0
                error('Lens focal lengths must be positive.');
            end
            if ~any(strcmp(params.optics.layoutMode, {'manual','telescopeLocked'}))
                error('Lens layout must be manual or telescopeLocked.');
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
            % Resolve locked optics and validate arrays with the same planner as Run.
            preflight = Bessel_Simulation_app_engine('plan',params);
            params = preflight.params;
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
            app.ZControls.mode.Value = params.simulation.zSamplingMode;
            app.ZControls.regions.Data = params.simulation.zRefinementRegionsMm;
            app.ZControls.extra.Value = strjoin(arrayfun(@(z)sprintf('%.17g',z), ...
                params.simulation.zExtraPlanesMm,'UniformOutput',false),', ');
            app.ZControls.cap.Value = params.simulation.maxZPlanes;
            app.ZSelectedRows = [];
            app.zSamplingChanged();
            app.updateBeamQualityControlStates();
            app.updateBeamQualityDescription();
            app.updateAxiconGeometryControlStates();
            app.updateAxiconControlStates();
            app.syncAxiconEquivalentControls();
            app.updateCheckerboardBesselControlStates();
        end

        function updateResultPreview(app, results)
            app.showImage(app.ResultAxes.slmPhase, angle(results.inputField), 'Phase on SLM', 'wrappedPhase');
            app.showImage(app.ResultAxes.inputIntensity, app.resultInputIntensity(results), 'Input after aperture |E|^2', 'auto');
            app.showImage(app.ResultAxes.angularSpectrum, app.resultAngularSpectrumIntensity(results), 'Angular spectrum |F|^2', 'auto');
            app.showImage(app.ResultAxes.checkerboardBesselPhase, angle(exp(1i * results.phase.checkerboardBessel)), 'Checker Bessel phase', 'wrappedPhase');
            app.showImage(app.ResultAxes.helicalPhase, results.phase.helical, 'Helical phase', 'auto');
            app.showImage(app.ResultAxes.axiconPhase, angle(exp(1i * results.phase.axicon)), 'Axicon phase', 'wrappedPhase');
            app.showImage(app.ResultAxes.vortexPhase, angle(exp(1i * results.phase.vortex)), 'Vortex phase', 'wrappedPhase');
            app.showImage(app.ResultAxes.checkerboardMask, double(results.phase.checkerboardMask), 'Checker mask', 'mask');

            app.showCrossSection(app.ResultAxes.peakLog, ...
                results.postprocess.zImageMm, ...
                results.postprocess.yImageMm, ...
                results.postprocess.crossSectionPeakPowerDensityLog, ...
                'Fixed x=0 y-z peak power density log scale', 'y (mm)', results);

            app.showCrossSection(app.ResultAxes.peakLinear, ...
                results.postprocess.zImageMm, ...
                results.postprocess.yImageMm, ...
                results.postprocess.crossSectionPeakPowerDensityWPerMm2, ...
                'Fixed x=0 y-z peak power density (W/mm^2)', 'y (mm)', results);

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
            if numel(results.postprocess.zImageMm) == 1
                xlim(ax,results.postprocess.zImageMm(1)+[-0.5,0.5]);
            else
                xlim(ax, [min(results.postprocess.zImageMm), max(results.postprocess.zImageMm)]);
            end
            peakPowerDensity = max([results.postprocess.onAxisPeakPowerDensityWPerMm2(:); results.postprocess.slicePeakPowerDensityWPerMm2(:)]);
            if isfinite(peakPowerDensity) && peakPowerDensity > 0
                ylim(ax, [0, peakPowerDensity * 1.5]);
            end
            app.plotActiveMarkers(ax, results);
            app.addBlankColorbarSlot(ax);
            hold(ax, 'off');
            legend(ax, 'Location', 'northeast');
        end

        function intensity = resultInputIntensity(~, results)
            if isfield(results, 'inputIntensity') && ~isempty(results.inputIntensity)
                intensity = results.inputIntensity;
            else
                intensity = abs(results.inputField) .^ 2;
            end
        end

        function intensity = resultAngularSpectrumIntensity(~, results)
            if isfield(results, 'angularSpectrumIntensity') && ~isempty(results.angularSpectrumIntensity)
                intensity = results.angularSpectrumIntensity;
            else
                intensity = abs(results.angularSpectrum) .^ 2;
            end
        end

        function showImage(app, ax, data, titleText, scaleMode)
            cla(ax);
            imagesc(ax, data);
            axis(ax, 'image');
            axis(ax, 'off');
            title(ax, titleText);
            app.applyValueColorbar(ax, data, scaleMode);
        end

        function showCrossSection(app, ax, zValues, transverseValues, data, titleText, transverseLabel, results)
            app.clearAxesForRedraw(ax);
            if numel(zValues) > 2 && ...
                    any(abs(diff(zValues)-diff(zValues(1:2))) > 32*eps(max(1,max(zValues))))
                [zMesh,yMesh] = meshgrid(zValues,transverseValues);
                surface(ax,zMesh,yMesh,zeros(size(data)),data,'EdgeColor','none','FaceColor','interp');
                view(ax,2);
            else
                imagesc(ax, zValues, transverseValues, data);
            end
            view(ax,2);
            ax.YDir = 'reverse';
            axis(ax, 'on');
            title(ax, titleText);
            xlabel(ax, 'z (mm)');
            ylabel(ax, transverseLabel);
            app.applyValueColorbar(ax, data, 'auto');
            if numel(zValues) == 1
                xlim(ax,zValues(1)+[-0.5,0.5]);
            else
                xlim(ax, [min(zValues), max(zValues)]);
            end
            ylim(ax, [min(transverseValues), max(transverseValues)]);
            app.plotActiveMarkers(ax, results);
        end

        function applyValueColorbar(app, ax, data, scaleMode)
            [limits, ticks, tickLabels] = app.colorbarScaleSpec(data, scaleMode);
            ax.CLim = limits;
            colorbarHandle = colorbar(ax);
            colorbarHandle.Ticks = ticks;
            colorbarHandle.TickLabels = tickLabels;
            colorbarHandle.Color = app.colorbarTextColor(ax);
            colorbarHandle.FontSize = 9;
            colorbarHandle.Box = 'on';
            colorbarHandle.Label.String = '';
            try
                colorbarHandle.TickLabelInterpreter = 'none';
            catch
            end
        end

        function [limits, ticks, tickLabels] = colorbarScaleSpec(app, data, scaleMode)
            switch char(string(scaleMode))
                case 'wrappedPhase'
                    limits = [-pi, pi];
                    ticks = [-pi, -pi / 2, 0, pi / 2, pi];
                case 'mask'
                    limits = [0, 1];
                    ticks = [0, 1];
                otherwise
                    finiteValues = data(isfinite(data));
                    if isempty(finiteValues)
                        limits = [0, 1];
                        ticks = linspace(limits(1), limits(2), 5);
                    else
                        minValue = min(finiteValues(:));
                        maxValue = max(finiteValues(:));
                        if minValue == maxValue
                            padding = max(1, abs(minValue)) * 0.5;
                            limits = [minValue - padding, maxValue + padding];
                            ticks = minValue;
                        else
                            limits = [minValue, maxValue];
                            ticks = linspace(limits(1), limits(2), 5);
                        end
                    end
            end
            tickLabels = app.formatColorbarTickLabels(ticks);
        end

        function tickLabels = formatColorbarTickLabels(app, ticks)
            tickLabels = arrayfun(@(value)app.formatColorbarValue(value), ticks, 'UniformOutput', false);
        end

        function label = formatColorbarValue(~, value)
            if value == 0
                label = '0';
            elseif abs(value) >= 1e4 || abs(value) < 1e-3
                label = sprintf('%.2e', value);
            else
                label = sprintf('%.3f', value);
                label = regexprep(label, '(\.\d*?)0+$', '$1');
                label = regexprep(label, '\.$', '');
            end
        end

        function textColor = colorbarTextColor(~, ax)
            textColor = [0.15, 0.15, 0.15];
            try
                if isnumeric(ax.XColor) && numel(ax.XColor) == 3
                    textColor = ax.XColor;
                end
            catch
            end

            backgroundColor = ax.Color;
            try
                if ~(isnumeric(backgroundColor) && numel(backgroundColor) == 3)
                    figureHandle = ancestor(ax, 'figure');
                    if ~isempty(figureHandle) && isnumeric(figureHandle.Color) && numel(figureHandle.Color) == 3
                        backgroundColor = figureHandle.Color;
                    else
                        backgroundColor = [1, 1, 1];
                    end
                end
            catch
                backgroundColor = [1, 1, 1];
            end

            if mean(backgroundColor) < 0.35 && mean(textColor) < 0.5
                textColor = [0.86, 0.86, 0.86];
            elseif mean(backgroundColor) >= 0.35 && mean(textColor) > 0.65
                textColor = [0.15, 0.15, 0.15];
            end
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
                sprintf('Aperture: enabled=%d, radius=%.12g mm, transmission=%.6f%%', ...
                    results.aperture.enabled, results.aperture.radiusMm, ...
                    100 * results.aperture.transmission);
                sprintf('Aperture power: incident=%.12g W, transmitted=%.12g W', ...
                    results.aperture.incidentAveragePowerW, results.aperture.transmittedAveragePowerW);
                sprintf('Axicon mode: %s', results.derived.axicon.mode);
                sprintf('Axicon geometry: %s, normal angle: %.12g deg', ...
                    results.derived.axicon.geometry, results.derived.axicon.orientationDeg);
                sprintf('Axicon effective beta: %.12g deg, kr=%.12g rad/mm', ...
                    results.derived.axicon.coneAngleDeg, results.derived.axicon.krRadPerMm);
                sprintf('Axicon phase period: %.12g mm (%.12g px)', ...
                    results.derived.axicon.radialPeriodMm, results.derived.axicon.radialPeriodPx);
                sprintf('Axicon phase cycles center-to-reference-edge: %.12g', ...
                    results.derived.axicon.radialCycles);
                sprintf('Physical-equivalent fields: n=%.12g, alpha=%.12g deg', ...
                    results.derived.axicon.physicalIndex, results.derived.axicon.physicalBaseAngleDeg);
                sprintf('Checkerboard Bessel: enabled=%d, tile=%d px, TC1=%.12g, beta1=%.12g deg, TC2=%.12g, beta2=%.12g deg', ...
                    results.params.phase.checkerboardBesselEnabled, ...
                    results.params.phase.checkerboardTileSizePx, ...
                    results.params.phase.checkerboardTc1, ...
                    results.params.phase.checkerboardBeta1Deg, ...
                    results.params.phase.checkerboardTc2, ...
                    results.params.phase.checkerboardBeta2Deg);
                sprintf('Z slices: %d', numel(results.propagation.zValuesMm));
                sprintf('Pulse peak power: incident=%.12g W, transmitted=%.12g W', ...
                    results.aperture.incidentPulsePeakPowerW, results.aperture.transmittedPulsePeakPowerW);
                sprintf('Laser beam M2: %.12g, model: %s (%s)', ...
                    results.derived.beam.qualityM2, results.derived.beam.qualityModelKey, ...
                    results.derived.beam.qualityModel);
                sprintf('M2 mode weights: %s', results.derived.beam.modeSummaryText);
                sprintf('Effective Gaussian waist: %.12g mm, coherent phases: x=%.12g deg, y=%.12g deg', ...
                    results.derived.beam.effectiveWaistRadiusMm, ...
                    results.derived.beam.hgCoherentPhaseXDeg, results.derived.beam.hgCoherentPhaseYDeg);
                sprintf('Nominal f2/f1=%.12g, afocal lens spacing=%d, mode=%s', ...
                    results.derived.optics.M, results.derived.optics.isAfocalLayout, ...
                    results.params.optics.layoutMode);
                sprintf('beta0=%.12g deg, nominal beta1=%.12g deg, nominal betaMaterial=%.12g deg', ...
                    results.derived.optics.beta0Deg, results.derived.optics.beta1Deg, ...
                    results.derived.optics.betaMaterialDeg);
                sprintf('Axicon focus length: %.12g mm (signed focus %.12g mm)', ...
                    results.derived.optics.zFocusMm, results.derived.optics.zFocusSignedMm);
                sprintf('Reference slice index: %d', results.postprocess.referenceSliceIndex);
                sprintf('Center pixel: row=%d, col=%d, x=%.12g mm, y=%.12g mm', ...
                    results.postprocess.centerRowIndex, results.postprocess.centerColumnIndex, ...
                    results.postprocess.centerXMm, results.postprocess.centerYMm);
                sprintf('On-axis max over sampled planes: %.12g W/mm^2 at z=%.12g mm', ...
                    results.postprocess.onAxisMaxPeakPowerDensityWPerMm2, results.postprocess.onAxisMaxZMm);
                sprintf('ROI slice-peak max over sampled planes: %.12g W/mm^2 at z=%.12g mm', ...
                    results.postprocess.sliceMaxPeakPowerDensityWPerMm2, results.postprocess.sliceMaxZMm)};
            plan = results.propagation.zPlan;
            lines{end+1} = sprintf('Z sampling: %s, base %d, added %d, actual uniform=%d', ...
                plan.mode,plan.basePlaneCount,plan.addedPlaneCount,plan.isUniformZ);
            if ~isempty(plan.zSpacingMm)
                lines{end+1} = sprintf('Actual z spacing: %.9g to %.9g mm',plan.minSpacingMm,plan.maxSpacingMm);
            end
            for k = 1:size(plan.requestedRegionsMm,1)
                lines{end+1} = sprintf('Refinement region: %.9g to %.9g mm, dz <= %.9g mm', ...
                    plan.requestedRegionsMm(k,:)); %#ok<AGROW>
            end
            if isfield(results.propagation,'diagnostics')
                diagnostic = results.propagation.diagnostics;
                lines = [lines; {
                    sprintf('Backend: %s (scalar paraxial)',results.propagation.backend);
                    sprintf('Focus ROI: %.6g mm, N=%d, dx=%.6g um', ...
                        diagnostic.observationSizeMm, results.observationGrid.N, ...
                        diagnostic.observationDxMm*1000);
                    sprintf('ROI captured input-normalized power at final plane: %.3f%%', ...
                        100*diagnostic.roiPowerFraction(end));
                    sprintf('Source-window edge intensity fraction: %.3f%%', ...
                        100*diagnostic.sourceEdgePowerFraction);
                    sprintf('Final ROI edge intensity fraction: %.3f%%', ...
                        100*diagnostic.edgePowerFraction(end));
                    sprintf('Largest source phase step: %.3g rad',diagnostic.sourcePhaseStepRad);
                    sprintf('Max free-space ASM spectral power removed: %.4f%%', ...
                        100*diagnostic.maxAsmSpectralPowerRemovedFraction);
                    sprintf('Estimated J0 first-zero radius: %.2f ROI pixels (afocal approximation)', ...
                        diagnostic.estimatedBesselCorePixels);
                    sprintf('Largest Collins input phase step: %.3g rad',diagnostic.largestInputPhaseStepRad);
                    sprintf('Estimated working memory: %.2f GiB',diagnostic.estimatedWorkingGiB)}];
                if diagnostic.edgePowerFraction(end) > 0.02
                    lines{end+1} = 'ROI edge contains substantial light; enlarge Focus ROI size to inspect the outer field.';
                end
                if diagnostic.sourceEdgePowerFraction > 0.01
                    lines{end+1} = 'Source window clips illuminated field; enlarge source size while keeping phase reference scales fixed.';
                end
                if isfinite(diagnostic.afocalSpectrumOver10DegFraction)
                    lines{end+1} = sprintf('Afocal spectral proxy above 10 deg: %.3f%% at final plane, %.3f%% in air', ...
                        100*diagnostic.afocalSpectrumOver10DegFraction, ...
                        100*diagnostic.afocalAirSpectrumOver10DegFraction);
                    if diagnostic.afocalSpectrumOver10DegFraction > 0.01 || ...
                            diagnostic.afocalAirSpectrumOver10DegFraction > 0.01
                        lines{end+1} = 'Some angular-spectrum power lies outside the paraxial range; validate against a nonparaxial model.';
                    end
                elseif diagnostic.maxRayAngleEstimateDeg > 10
                    lines{end+1} = 'Conservative ray-angle bound exceeds 10 deg; scalar paraxial model needs validation.';
                end
                if diagnostic.sourcePhaseStepRad >= pi
                    lines{end+1} = 'Source phase exceeds the sampling limit; increase source N before trusting the result.';
                end
                if diagnostic.maxAsmSpectralPowerRemovedFraction > 0.01
                    lines{end+1} = 'Free-space band-limit removed significant power; enlarge the source/propagation window.';
                end
                if isfinite(diagnostic.estimatedBesselCorePixels) && ...
                        diagnostic.estimatedBesselCorePixels < 3
                    lines{end+1} = 'Bessel core is under-resolved in the ROI; increase Focus ROI samples.';
                end
            end
            if results.params.optics.lens1Enabled && results.params.optics.lens2Enabled && ...
                    ~results.derived.optics.isAfocalLayout
                lines{end+1} = 'Lens spacing differs from f1+f2; the displayed focal-length ratio is not the actual beam scale.';
            end
            app.SummaryTextArea.Value = lines;
        end

        function appendStatus(app, message)
            newLine = string(message);
            if isempty(app.StatusTextArea) || ~isvalid(app.StatusTextArea)
                return;
            end

            currentLines = string(app.StatusTextArea.Value);
            currentLines = currentLines(:);
            currentLines(currentLines == "") = [];
            currentLines = currentLines(:);
            currentLines = [currentLines; newLine(:)];
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
            currentLines = currentLines(:);
            currentLines(currentLines == "Run started. Waiting for progress messages...") = [];
            currentLines(currentLines == "") = [];
            currentLines = currentLines(:);
            newLines = string(message);
            currentLines = [currentLines; newLines(:)];
            if numel(currentLines) > 500
                currentLines = currentLines(end-499:end);
            end
            app.LogTextArea.Value = cellstr(currentLines);
            drawnow limitrate;
        end

        function setRunningState(app, isRunning, busyText)
            if nargin < 3
                busyText = 'Running...';
            end
            app.IsRunning = isRunning;
            if isempty(app.RunButton) || ~isvalid(app.RunButton)
                return;
            end
            if isRunning
                app.RunButton.Enable = 'on';
                app.RunButton.Text = busyText;
                app.RunButton.BackgroundColor = [1.0 0.78 0.12];
                app.RunButton.FontColor = [0.05 0.05 0.05];
                if ~isempty(app.OutputButton) && isvalid(app.OutputButton)
                    app.OutputButton.Enable = 'off';
                end
                if ~isempty(app.ResetButton) && isvalid(app.ResetButton)
                    app.ResetButton.Enable = 'off';
                end
            else
                app.RunButton.Enable = 'on';
                app.RunButton.Text = app.RunButtonIdleText;
                app.RunButton.BackgroundColor = app.RunButtonIdleBackgroundColor;
                app.RunButton.FontColor = app.RunButtonIdleFontColor;
                if ~isempty(app.OutputButton) && isvalid(app.OutputButton)
                    app.OutputButton.Enable = 'on';
                end
                if ~isempty(app.ResetButton) && isvalid(app.ResetButton)
                    app.ResetButton.Enable = 'on';
                end
            end
            app.updateZControlStates();
            drawnow limitrate;
        end

        function shouldAssign = shouldAssignResultsToBaseWorkspace(~, params)
            shouldAssign = isfield(params, 'output') && ...
                isfield(params.output, 'assignResultsToBaseWorkspace') && ...
                isscalar(params.output.assignResultsToBaseWorkspace) && ...
                logical(params.output.assignResultsToBaseWorkspace);
        end

        function isAllowed = allowsInfiniteParameter(~, groupName, fieldName, value)
            isAllowed = strcmp(groupName, 'phase') && ...
                (strcmp(fieldName, 'axiconRadialPeriodMm') || strcmp(fieldName, 'axiconRadialPeriodPx')) && ...
                isinf(value);
        end

        function message = simulationEstimateMessage(app, params)
            preflight = Bessel_Simulation_app_engine('plan',params);
            zSliceCount = preflight.zPlan.planeCount;
            if strcmp(char(string(params.simulation.propagationMethod)), 'adaptiveCollins')
                if isempty(preflight.memory)
                    message = 'Input plane only; propagation disabled.';
                else
                    m = preflight.memory;
                    message = sprintf('Z sampling: %s, %d planes (%d added); ROI stack %.3f GiB, estimated total %.3f / %.3f GiB.', ...
                        preflight.zPlan.mode,zSliceCount,preflight.zPlan.addedPlaneCount, ...
                        m.intensityStackGiB,m.totalGiB,m.budgetGiB);
                end
                return;
            end
            if isfield(params.simulation, 'useBPM') && ~params.simulation.useBPM
                zSliceCount = 1;
            end
            complexStackGiB = double(params.simulation.N) ^ 2 * double(zSliceCount) * 16 / 1024 ^ 3;
            model = '';
            if isfield(params.beam, 'beamQualityModel')
                model = char(string(params.beam.beamQualityModel));
            end
            if isfield(params.beam, 'beamQualityM2') && params.beam.beamQualityM2 > 1 && strcmp(model, 'incoherentHG')
                intensityStackGiB = double(params.simulation.N) ^ 2 * double(zSliceCount) * 8 / 1024 ^ 3;
                modeCount = app.beamQualityModeCount(params.beam.beamQualityM2);
                message = sprintf(['Estimated BPM stacks: %.2f GiB output intensity + %.2f GiB transient complex per HG mode ', ...
                    '(%d modes, %d z slices).'], intensityStackGiB, complexStackGiB, modeCount, zSliceCount);
            else
                message = sprintf('Estimated BPM field stack: %.2f GiB (%d z slices, M2 model=%s).', ...
                    complexStackGiB, zSliceCount, model);
            end
        end

        function modeCount = beamQualityModeCount(~, beamQualityM2)
            excessOrder = max(0, beamQualityM2 - 1);
            lowOrder = floor(excessOrder);
            highOrder = ceil(excessOrder);
            highWeight = excessOrder - lowOrder;
            if highWeight < 1e-12
                highOrder = lowOrder;
            elseif 1 - highWeight < 1e-12
                lowOrder = highOrder;
            end

            modeCount = 0;
            if lowOrder == 0
                modeCount = modeCount + 1;
            else
                modeCount = modeCount + 2;
            end
            if highOrder ~= lowOrder
                if highOrder == 0
                    modeCount = modeCount + 1;
                else
                    modeCount = modeCount + 2;
                end
            end
        end

        function value = getTextControlValue(app, groupName, fieldName)
            control = app.Controls.(app.controlKey(groupName, fieldName));
            value = char(string(control.Value));
        end

        function beamQualityModelChanged(app)
            app.updateBeamQualityControlStates();
            app.updateBeamQualityDescription();
            modelControlKey = app.controlKey('beam', 'beamQualityModel');
            if isfield(app.Controls, modelControlKey)
                app.appendStatus(sprintf('M2 model: %s', char(string(app.Controls.(modelControlKey).Value))));
            end
        end

        function beamQualityParameterChanged(app)
            app.updateBeamQualityDescription();
        end

        function updateBeamQualityControlStates(app)
            modelKey = app.controlKey('beam', 'beamQualityModel');
            phaseXKey = app.controlKey('beam', 'hgCoherentPhaseXDeg');
            phaseYKey = app.controlKey('beam', 'hgCoherentPhaseYDeg');
            if ~isfield(app.Controls, modelKey)
                return;
            end

            isCoherentHg = strcmp(char(string(app.Controls.(modelKey).Value)), 'coherentHG');
            phaseEnable = 'off';
            if isCoherentHg
                phaseEnable = 'on';
            end
            if isfield(app.Controls, phaseXKey)
                app.Controls.(phaseXKey).Enable = phaseEnable;
            end
            if isfield(app.Controls, phaseYKey)
                app.Controls.(phaseYKey).Enable = phaseEnable;
            end
        end

        function updateBeamQualityDescription(app)
            if isempty(app.BeamModelExplanationTextArea) || ~isvalid(app.BeamModelExplanationTextArea)
                return;
            end

            model = char(string(app.Params.beam.beamQualityModel));
            beamQualityM2 = app.Params.beam.beamQualityM2;
            phaseXDeg = app.Params.beam.hgCoherentPhaseXDeg;
            phaseYDeg = app.Params.beam.hgCoherentPhaseYDeg;

            modelKey = app.controlKey('beam', 'beamQualityModel');
            m2Key = app.controlKey('beam', 'beamQualityM2');
            phaseXKey = app.controlKey('beam', 'hgCoherentPhaseXDeg');
            phaseYKey = app.controlKey('beam', 'hgCoherentPhaseYDeg');
            if isfield(app.Controls, modelKey)
                model = char(string(app.Controls.(modelKey).Value));
            end
            if isfield(app.Controls, m2Key)
                beamQualityM2 = app.Controls.(m2Key).Value;
            end
            if isfield(app.Controls, phaseXKey)
                phaseXDeg = app.Controls.(phaseXKey).Value;
            end
            if isfield(app.Controls, phaseYKey)
                phaseYDeg = app.Controls.(phaseYKey).Value;
            end

            app.BeamModelExplanationTextArea.Value = ...
                app.beamQualityModelExplanation(model, beamQualityM2, phaseXDeg, phaseYDeg);
        end

        function lines = beamQualityModelExplanation(app, model, beamQualityM2, phaseXDeg, phaseYDeg)
            if ~isnumeric(beamQualityM2) || ~isscalar(beamQualityM2) || ~isfinite(beamQualityM2) || beamQualityM2 < 1
                lines = {
                    'M^2 model';
                    'Set beamQualityM2 to a finite value greater than or equal to 1 to see the mode interpretation.'};
                return;
            end

            modeText = app.beamQualityModeWeightText(beamQualityM2);
            switch char(string(model))
                case 'effectiveGaussian'
                    effectiveWaistText = 'not available';
                    waistKey = app.controlKey('beam', 'waistRadiusMm');
                    if isfield(app.Controls, waistKey)
                        waistRadiusMm = app.Controls.(waistKey).Value;
                        if isnumeric(waistRadiusMm) && isscalar(waistRadiusMm) && isfinite(waistRadiusMm)
                            effectiveWaistText = sprintf('%.6g mm', waistRadiusMm / beamQualityM2);
                        end
                    end
                    lines = {
                        'effectiveGaussian';
                        sprintf('Current M^2: %.6g. The app propagates one smooth HG00 Gaussian field.', beamQualityM2);
                        sprintf('It uses waistRadiusMm / M^2 as the effective waist, currently %s, so the angular spread is increased without adding higher-order lobes.', effectiveWaistText);
                        'Use this for a fast, stable approximation when you only need the overall divergence or spot-size effect of a non-ideal beam.';
                        'It does not model modal interference, asymmetric HG structure, or separate modal power.'};
                case 'coherentHG'
                    lines = {
                        'coherentHG';
                        sprintf('Current M^2: %.6g. The app builds a weighted Hermite-Gaussian mode set from M^2 - 1: %s.', beamQualityM2, modeText);
                        'The selected HG modes are added as complex fields before propagation, using sqrt(weight) for field amplitude.';
                        sprintf('HGn0 terms use HG x phase = %.6g deg, and HG0n terms use HG y phase = %.6g deg. These phases can create interference and asymmetric structure.', phaseXDeg, phaseYDeg);
                        'Use this when the higher-order content has a stable phase relationship to the fundamental mode.'};
                case 'incoherentHG'
                    lines = {
                        'incoherentHG';
                        sprintf('Current M^2: %.6g. The app builds this weighted Hermite-Gaussian mode set from M^2 - 1: %s.', beamQualityM2, modeText);
                        'Each HG mode is propagated separately, then the final intensities are summed with the listed weights.';
                        'There is no interference between modes, so HG x phase and HG y phase are ignored in this mode.';
                        'Use this for multimode beams where modal phases are unknown, drifting, or mutually incoherent. It is more conservative, but can run slower because multiple fields are propagated.'};
                otherwise
                    lines = {
                        'M^2 model';
                        'Select effectiveGaussian, coherentHG, or incoherentHG.'};
            end
        end

        function text = beamQualityModeWeightText(app, beamQualityM2)
            excessOrder = max(0, beamQualityM2 - 1);
            lowOrder = floor(excessOrder);
            highOrder = ceil(excessOrder);
            highWeight = excessOrder - lowOrder;
            if highWeight < 1e-12
                highWeight = 0;
                highOrder = lowOrder;
            elseif 1 - highWeight < 1e-12
                highWeight = 0;
                lowOrder = highOrder;
            end
            lowWeight = 1 - highWeight;

            parts = {};
            parts = app.appendBeamQualityModeWeightParts(parts, lowOrder, lowWeight);
            if highOrder ~= lowOrder && highWeight > 0
                parts = app.appendBeamQualityModeWeightParts(parts, highOrder, highWeight);
            end
            text = strjoin(parts, ', ');
        end

        function parts = appendBeamQualityModeWeightParts(~, parts, order, groupWeight)
            if groupWeight <= 0
                return;
            end
            if order == 0
                parts{end + 1} = sprintf('HG00=%.6g', groupWeight);
            else
                parts{end + 1} = sprintf('HG%d0=%.6g', order, groupWeight / 2);
                parts{end + 1} = sprintf('HG0%d=%.6g', order, groupWeight / 2);
            end
        end

        function axiconModeChanged(app)
            app.updateAxiconControlStates();
            app.syncAxiconEquivalentControls();
            modeControlKey = app.controlKey('phase', 'axiconMode');
            if isfield(app.Controls, modeControlKey)
                app.appendStatus(sprintf('Axicon definition mode: %s', char(string(app.Controls.(modeControlKey).Value))));
            end
        end

        function axiconGeometryChanged(app)
            app.updateAxiconGeometryControlStates();
            geometryKey = app.controlKey('phase', 'axiconGeometry');
            if isfield(app.Controls, geometryKey)
                app.appendStatus(sprintf('Axicon geometry: %s', ...
                    char(string(app.Controls.(geometryKey).Value))));
            end
        end

        function axiconParameterChanged(app)
            app.syncAxiconEquivalentControls();
        end

        function checkerboardBesselEnabledChanged(app)
            app.updateCheckerboardBesselControlStates();
            enabledKey = app.controlKey('phase', 'checkerboardBesselEnabled');
            if isfield(app.Controls, enabledKey)
                app.appendStatus(sprintf('Checkerboard Bessel enabled: %d', ...
                    logical(app.Controls.(enabledKey).Value)));
            end
        end

        function updateCheckerboardBesselControlStates(app)
            enabledKey = app.controlKey('phase', 'checkerboardBesselEnabled');
            if ~isfield(app.Controls, enabledKey)
                return;
            end

            controlEnable = 'off';
            if logical(app.Controls.(enabledKey).Value)
                controlEnable = 'on';
            end

            checkerboardFields = {'checkerboardTileSizePx', 'checkerboardTc1', ...
                'checkerboardTc2', 'checkerboardBeta1Deg', 'checkerboardBeta2Deg'};
            for index = 1:numel(checkerboardFields)
                key = app.controlKey('phase', checkerboardFields{index});
                if isfield(app.Controls, key)
                    app.Controls.(key).Enable = controlEnable;
                end
            end
        end

        function updateAxiconGeometryControlStates(app)
            geometryKey = app.controlKey('phase', 'axiconGeometry');
            orientationKey = app.controlKey('phase', 'axiconOrientationDeg');
            if ~isfield(app.Controls, geometryKey) || ~isfield(app.Controls, orientationKey)
                return;
            end

            orientationEnable = 'off';
            if strcmp(char(string(app.Controls.(geometryKey).Value)), 'linear1D')
                orientationEnable = 'on';
            end
            app.Controls.(orientationKey).Enable = orientationEnable;
        end

        function updateAxiconControlStates(app)
            modeKey = app.controlKey('phase', 'axiconMode');
            if ~isfield(app.Controls, modeKey)
                return;
            end

            mode = char(string(app.Controls.(modeKey).Value));
            axiconFields = {'axiconConeAngleDeg', 'axiconRadialPeriodMm', ...
                'axiconRadialPeriodPx', 'axiconRadialCycles', ...
                'axiconIndex', 'axiconAngleDeg'};
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
                case 'radialCycles'
                    activeFields = {'axiconRadialCycles'};
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
                app.controlKey('phase', 'axiconRadialCycles');
                app.controlKey('phase', 'axiconIndex');
                app.controlKey('phase', 'axiconAngleDeg');
                app.controlKey('phase', 'referenceRadiusMm');
                app.controlKey('phase', 'referencePixelPitchMm');
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
                gridRadiusMm = app.Controls.(app.controlKey('phase', 'referenceRadiusMm')).Value;
                gridPixelPitchMm = app.Controls.(app.controlKey('phase', 'referencePixelPitchMm')).Value;
                wavelengthMm = app.nmToMm(app.Controls.(app.controlKey('laser', 'wavelengthMm')).Value);
                backgroundIndex = app.Controls.(app.controlKey('material', 'backgroundIndex')).Value;
                axiconIndex = app.Controls.(app.controlKey('phase', 'axiconIndex')).Value;

                if gridRadiusMm <= 0 || gridPixelPitchMm <= 0 || wavelengthMm <= 0 || ...
                        backgroundIndex <= 0 || axiconIndex <= 0
                    return;
                end

                kBackground = 2 * pi * backgroundIndex / wavelengthMm;
                [coneAngleRad, krRadPerMm] = app.resolveAxiconControlsToConeAndKr(mode, kBackground, gridPixelPitchMm, gridRadiusMm);
                if ~isfinite(coneAngleRad) || ~isfinite(krRadPerMm) || ...
                        abs(coneAngleRad) >= pi / 2 || ...
                        abs(krRadPerMm) >= kBackground
                    return;
                end

                coneAngleDeg = rad2deg(coneAngleRad);
                radialPeriodMm = 2 * pi / krRadPerMm;
                radialPeriodPx = radialPeriodMm / gridPixelPitchMm;
                radialCycles = krRadPerMm * gridRadiusMm / (2 * pi);
                physicalBaseAngleDeg = app.equivalentPhysicalBaseAngleDeg(coneAngleRad, axiconIndex, backgroundIndex);

                app.setAxiconEquivalentValue('axiconConeAngleDeg', coneAngleDeg, mode, 'coneAngle');
                app.setAxiconEquivalentValue('axiconRadialPeriodMm', radialPeriodMm, mode, 'radialPeriodMm');
                app.setAxiconEquivalentValue('axiconRadialPeriodPx', radialPeriodPx, mode, 'radialPeriodPx');
                app.setAxiconEquivalentValue('axiconRadialCycles', radialCycles, mode, 'radialCycles');
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

        function [coneAngleRad, krRadPerMm] = resolveAxiconControlsToConeAndKr(app, mode, kBackground, gridPixelPitchMm, gridRadiusMm)
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
                case 'radialCycles'
                    radialCycles = app.Controls.(app.controlKey('phase', 'axiconRadialCycles')).Value;
                    krRadPerMm = 2 * pi * radialCycles / gridRadiusMm;
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
            options = {'coneAngle', 'radialPeriodMm', 'radialPeriodPx', 'radialCycles', 'physicalEquivalent'};
        end

        function options = axiconGeometryOptions(~)
            options = {'circular', 'linear1D'};
        end

        function options = beamQualityModelOptions(~)
            options = {'effectiveGaussian', 'coherentHG', 'incoherentHG'};
        end

        function isMatch = isAxiconSyncControl(~, groupName, fieldName)
            paramPath = sprintf('%s.%s', groupName, fieldName);
            syncPaths = {
                'simulation.N';
                'simulation.sizeMm';
                'phase.referenceRadiusMm';
                'phase.referencePixelPitchMm';
                'laser.wavelengthMm';
                'material.backgroundIndex';
                'phase.axiconMode';
                'phase.axiconConeAngleDeg';
                'phase.axiconRadialPeriodMm';
                'phase.axiconRadialPeriodPx';
                'phase.axiconRadialCycles';
                'phase.axiconIndex';
                'phase.axiconAngleDeg'};
            isMatch = any(strcmp(paramPath, syncPaths));
        end

        function isMatch = isBeamExplanationControl(~, groupName, fieldName)
            paramPath = sprintf('%s.%s', groupName, fieldName);
            explanationPaths = {
                'beam.waistRadiusMm';
                'beam.beamQualityM2';
                'beam.hgCoherentPhaseXDeg';
                'beam.hgCoherentPhaseYDeg'};
            isMatch = any(strcmp(paramPath, explanationPaths));
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
                    description = 'Physical width of the source sampling window. Phase reference dimensions remain fixed when this is changed.';
                case 'phase.referenceRadiusMm'
                    description = 'Fixed physical radius used by axicon cycles, curved-beam reference length, and helical radial chirp.';
                case 'phase.referencePixelPitchMm'
                    description = 'Fixed physical reference pixel pitch for axicon radialPeriodPx and checkerboard tile size.';
                case 'simulation.zRangeMm'
                    description = 'Total propagation distance along z, in mm. This controls how much axial evolution is simulated and exported.';
                case 'simulation.dzMm'
                    description = 'Spacing of observation planes. Optical elements are applied at their exact z position in adaptive mode.';
                case 'simulation.propagationMethod'
                    description = 'adaptiveCollins evaluates each focused ROI directly from the full input field; legacyASM uses a fixed grid.';
                case 'simulation.adaptiveOutputN'
                    description = 'Number of pixels per axis in the focused observation ROI.';
                case 'simulation.adaptiveOutputSizeMm'
                    description = 'Focused observation width in mm; zero estimates it from the lens focal-length ratio.';
                case 'simulation.maxWorkingGiB'
                    description = 'Estimated maximum memory for the adaptive observation stack and CZT work arrays.';
                case 'simulation.bandLimitASM'
                    description = 'Apply a 2-D transfer-function sampling bound before the first lens and report how much spectrum is removed.';
                case 'optics.layoutMode'
                    description = 'manual keeps positions independent; telescopeLocked sets L2 at L1+f1+f2 and sample at L2+offset.';
                case 'optics.sampleOffsetFromLens2Mm'
                    description = 'Sample distance after L2 when telescopeLocked layout is selected.';

                case 'laser.wavelengthMm'
                    description = 'Laser wavelength. It affects the wave number, phase maps, propagation kernel, and propagation scale inside the sample.';
                case 'laser.powerW'
                    description = 'Average laser power before the aperture, used for peak-power-density estimates. A finite aperture reduces the transmitted power by its calculated transmission.';
                case 'laser.repetitionRateHz'
                    description = 'Pulse repetition rate. At fixed average power, a higher repetition rate gives lower energy per pulse.';
                case 'laser.pulseWidthS'
                    description = 'Pulse duration used to estimate peak power. Shorter pulses give higher estimated peak power.';

                case 'beam.waistRadiusMm'
                    description = 'Input Gaussian beam waist radius, in mm. This controls the incident spot size and initial intensity envelope.';
                case 'beam.fieldAmplitude'
                    description = 'Scale factor for the input field amplitude. It scales the complex field amplitude and is mainly useful for quick debugging.';
                case 'beam.beamQualityM2'
                    description = 'Laser beam-quality factor M^2. How it changes the simulated field is selected by beamQualityModel.';
                case 'beam.beamQualityModel'
                    description = 'Selects how beamQualityM2 enters the simulation: effective Gaussian, coherent HG field sum, or incoherent HG intensity sum.';
                case 'beam.hgCoherentPhaseXDeg'
                    description = 'Relative phase, in degrees, applied to HGn0 terms when beamQualityModel is coherentHG. Ignored by the other M2 models.';
                case 'beam.hgCoherentPhaseYDeg'
                    description = 'Relative phase, in degrees, applied to HG0n terms when beamQualityModel is coherentHG. Ignored by the other M2 models.';
                case 'phase.airyStrength'
                    description = 'Strength of the cubic Airy phase term. Set to 0 to disable the Airy phase.';
                case 'phase.airyScaleMm'
                    description = 'Transverse scale of the Airy phase, in mm. This controls how quickly the cubic phase changes with position.';
                case 'phase.apertureRadiusMm'
                    description = 'Radius of a centered hard circular amplitude aperture at the SLM plane, in mm. Use 0 for fully open; outside a positive radius the complex field is set to zero.';
                case 'phase.axiconGeometry'
                    description = 'Selects circular phase variation in radius r or a one-dimensional biprism phase in |u| for light-sheet generation.';
                case 'phase.axiconOrientationDeg'
                    description = 'Normal direction u of the linear1D phase, in degrees. At 0 deg the phase varies along x and the light sheet extends in y-z.';
                case 'phase.axiconMode'
                    description = 'Selects which axicon parameter is active. The engine converts the selected definition to one transverse phase slope and cone angle.';
                case 'phase.axiconConeAngleDeg'
                    description = 'Signed effective holographic axicon cone angle beta, in degrees. Zero disables the axicon radial slope; negative values reverse the radial phase direction.';
                case 'phase.axiconRadialPeriodMm'
                    description = 'Signed 2pi phase period along the active axicon coordinate, in mm. Use Inf for beta = 0; negative values reverse the phase direction.';
                case 'phase.axiconRadialPeriodPx'
                    description = 'Signed 2pi phase period along the active axicon coordinate, in generated phase-map pixels. Use Inf for beta = 0.';
                case 'phase.axiconRadialCycles'
                    description = 'Signed number of 2pi axicon phase cycles from the beam axis to the reference half-width of the simulation window.';
                case 'phase.axiconIndex'
                    description = 'Refractive index of the equivalent physical axicon. Active only when axiconMode is physicalEquivalent.';
                case 'phase.axiconAngleDeg'
                    description = 'Base angle alpha of the equivalent physical axicon, in degrees. Active only when axiconMode is physicalEquivalent.';
                case 'phase.curvedMaxShiftXMm'
                    description = 'Target x-direction lateral shift at the end of the curved Bessel trajectory. Supported only for circular geometry; nonzero values require beta not equal to 0.';
                case 'phase.curvedMaxShiftYMm'
                    description = 'Target y-direction lateral shift at the end of the curved Bessel trajectory. Supported only for circular geometry; nonzero values require beta not equal to 0.';
                case 'phase.compensationPhase'
                    description = 'Extra compensation phase hook. It is currently applied as an additional global phase term.';
                case 'phase.vortexCharge'
                    description = 'Topological charge l for the vortex phase. Set to 0 to disable the vortex phase.';
                case 'phase.checkerboardBesselEnabled'
                    description = 'Adds a checkerboard-multiplexed Bessel vortex phase built from two TC/beta definitions.';
                case 'phase.checkerboardTileSizePx'
                    description = 'Checkerboard tile width in generated phase-map pixels. Same-parity tiles use beam 1; alternating tiles use beam 2.';
                case 'phase.checkerboardTc1'
                    description = 'Topological charge TC_1 for checkerboard Bessel vortex beam 1.';
                case 'phase.checkerboardTc2'
                    description = 'Topological charge TC_2 for checkerboard Bessel vortex beam 2.';
                case 'phase.checkerboardBeta1Deg'
                    description = 'Axicon cone angle beta_1, in degrees, for checkerboard Bessel vortex beam 1.';
                case 'phase.checkerboardBeta2Deg'
                    description = 'Axicon cone angle beta_2, in degrees, for checkerboard Bessel vortex beam 2.';
                case 'phase.helicalGamma'
                    description = 'Modulation depth of the helical phase term. This controls the strength of the helical contribution.';
                case 'phase.helicalOrder'
                    description = 'Angular order m of the helical phase. This controls the number of angular periods around one full turn.';
                case 'phase.helicalPhaseOffset'
                    description = 'Initial angular offset of the helical phase, in degrees. Batch scans vary this parameter.';
                case 'phase.omegaInner'
                    description = 'Radial chirp cycle density near the center in normalized radius rho. If omegaInner equals omegaOuter, that value is the center-to-edge radial cycle count.';
                case 'phase.omegaOuter'
                    description = 'Radial chirp cycle density near the edge in normalized radius rho. Together with omegaInner, it sets the radial cycle-density sweep.';

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
                    description = 'Exports an 8-bit display TIFF and a JSON file with the physical x, y, z coordinates.';
                case 'output.writeRawIntensity'
                    description = 'Exports native floating-point intensity and physical x, y, z axes to MAT for quantitative analysis.';
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
                case 'output.assignResultsToBaseWorkspace'
                    description = 'When enabled, exports the full results struct and large field arrays to the base workspace. Leave off for lower memory use in the app.';
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
                    if isnumeric(value) && ~any(strcmp(fieldName,{'zRefinementRegionsMm','zExtraPlanesMm'}))
                        paths(end + 1, :) = {groupName, fieldName}; %#ok<AGROW>
                    end
                end
            end
        end
    end
end
