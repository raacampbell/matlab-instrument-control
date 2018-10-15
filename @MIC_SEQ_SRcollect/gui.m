function GuiFig = gui(obj)

% Ensure only one sequential microscope GUI is opened at a time.
h = findall(0, 'tag', 'SeqSRcollect.gui');
if ~(isempty(h))
    figure(h);
    return;
end

% Define reference parameters for the GUI dimensions.
ScreenSize = get(groot, 'ScreenSize'); % size of displaying screen
XSize = 760; % width of figure
YSize = 600; % height of figure
BottomLeftX = floor(ScreenSize(3)/2 - XSize/2); % ~centers figure on screen
BottomLeftY = floor(ScreenSize(4)/2 - YSize/2);
SmallPanelWidth = 210; % width of small uipanels
SmallPanelHeight = 135; % height of small uipanels
BigPanelWidth = 315; % width of big uipanels
BigPanelHeight = 325; % height of big uipanels
FirstRowStartPosition = [5, YSize-BigPanelHeight, 0, 0]; % start pos. row 1
SecondRowStartPosition = [5, YSize-SmallPanelHeight-BigPanelHeight, ...
    0, 0]; % start position of the 2nd row panels
ThirdRowStartPosition = [5, YSize-2*SmallPanelHeight-BigPanelHeight, ...
    0, 0]; % start position of the 3rd row panels

% Create the GUI figure.
GuiFig = figure('Units', 'pixels', ...
    'Position', [BottomLeftX, BottomLeftY, XSize, YSize], ...
    'MenuBar', 'none', 'ToolBar', 'none', 'Visible', 'on', ...
    'NumberTitle', 'off', 'UserData', 0, 'Tag', 'SeqSRcollect.gui', ...
    'HandleVisibility', 'off', 'name', 'SeqAutoCollect.gui');
obj.GuiFigureMain = GuiFig;
GuiFig.Color = get(0, 'defaultUicontrolBackgroundColor');
GuiFig.WindowScrollWheelFcn = @zPiezoControl; % mouse wheel for Z piezo
handles.output = GuiFig;
guidata(GuiFig, handles);

% Create a sample stage control panel and associated controls.
StageControlPanel = uipanel(GuiFig, 'Title', 'Sample Stage', ...
    'FontWeight', 'bold', 'Units', 'pixels', ...
    'Position', FirstRowStartPosition...
    + [0, 0, SmallPanelWidth, BigPanelHeight]);
handles.ButtonBigStepUp = uicontrol('Parent', StageControlPanel, ...
    'Style', 'PushButton', 'String', 'UP', ...
    'Position', [5, BigPanelHeight-70, 60, 50], ...
    'FontSize', 12, 'FontWeight', 'bold', ...
    'TooltipString', sprintf('Step size %gmm', obj.StepperLargeStep), ...
    'Callback', @stepperControl);
handles.ButtonSmallStepUp = uicontrol('Parent', StageControlPanel, ...
    'Style', 'PushButton', 'String', 'up', ...
    'Position', [17, BigPanelHeight-95, 36, 25], ...
    'FontSize', 10, ...
    'TooltipString', sprintf('Step size %gmm', obj.StepperSmallStep), ...
    'Callback', @stepperControl);
handles.ButtonSmallStepDown = uicontrol('Parent', StageControlPanel, ...
    'Style', 'PushButton', 'String', 'down', ...
    'Position', [17, BigPanelHeight-125, 36, 25], ...
    'FontSize', 10, ...
    'TooltipString', sprintf('Step size %gmm', obj.StepperSmallStep), ...
    'Callback', @stepperControl);
handles.ButtonBigStepDown = uicontrol('Parent', StageControlPanel, ...
    'Style', 'PushButton', 'String', 'DOWN', ...
    'Position', [5, BigPanelHeight-175, 60, 50], ...
    'FontSize', 12, 'FontWeight', 'bold', ...
    'TooltipString', sprintf('Step size %gmm', obj.StepperLargeStep), ...
    'Callback', @stepperControl);
uicontrol('Parent', StageControlPanel, 'Style', 'Text', ...
    'String', 'Stepper Position (mm)', ...
    'Position', [SmallPanelWidth-120, BigPanelHeight-40, 110, 15]);
handles.TextStepperX = uicontrol('Parent', StageControlPanel, ...
    'Style', 'Text', 'String', 'X: 1.000', ...
    'Position', [SmallPanelWidth-120, BigPanelHeight-55, 110, 15]);
handles.TextStepperY = uicontrol('Parent', StageControlPanel, ...
    'Style', 'Text', 'String', 'Y: 1.000', ...
    'Position', [SmallPanelWidth-120, BigPanelHeight-70, 110, 15]);
handles.TextStepperZ = uicontrol('Parent', StageControlPanel, ...
    'Style', 'Text', 'String', 'Z: 1.000', ...
    'Position', [SmallPanelWidth-120, BigPanelHeight-85, 110, 15]);
uicontrol('Parent', StageControlPanel, 'Style', 'Text', ...
    'String', 'Piezo Position (um)', ...
    'Position', [SmallPanelWidth-120, BigPanelHeight-120, 110, 15], ...
    'TooltipString', 'Control z piezo with mousewheel');
handles.TextPiezoX = uicontrol('Parent', StageControlPanel, ...
    'Style', 'Text', 'String', 'X: 10.000', ...
    'Position', [SmallPanelWidth-120, BigPanelHeight-135, 110, 15]);
handles.TextPiezoY = uicontrol('Parent', StageControlPanel, ...
    'Style', 'Text', 'String', 'Y: 10.000', ...
    'Position', [SmallPanelWidth-120, BigPanelHeight-150, 110, 15]);
handles.TextPiezoZ = uicontrol('Parent', StageControlPanel, ...
    'Style', 'Text', 'String', 'Z: 10.000', ...
    'Position', [SmallPanelWidth-120, BigPanelHeight-165, 110, 15], ...
    'TooltipString', 'Control z piezo with mousewheel');
TopButtonPosition = ...
    [floor(SmallPanelWidth/2 - 125/2), BigPanelHeight-215, 125, 25];
handles.ButtonLoadSample = uicontrol('Parent', StageControlPanel, ...
    'Style', 'pushbutton', 'String', 'Load Sample', ...
    'Position', TopButtonPosition, ...
    'Callback', @loadSample);
handles.ButtonUnloadSample = uicontrol('Parent', StageControlPanel, ...
    'Style', 'pushbutton', 'String', 'Unload Sample', ...
    'Position', TopButtonPosition + [0, -25, 0, 0], ...
    'Callback', @unloadSample);
handles.ButtonResetPiezos = uicontrol('Parent', StageControlPanel, ...
    'Style', 'pushbutton', 'String', 'Reset Piezos', ...
    'Position', TopButtonPosition + [0, -50, 0, 0], ...
    'Callback', @resetPiezos);

% Create a control panel for the main sCMOS camera.
SCMOSControlPanel = uipanel(GuiFig, 'Title', 'Hamamatsu sCMOS', ...
    'FontWeight', 'bold', 'Units', 'pixels', ...
    'Position', FirstRowStartPosition ...
    + [SmallPanelWidth+10, 0, SmallPanelWidth, BigPanelHeight]);
uicontrol('Parent', SCMOSControlPanel,'Style', 'Text', ...
    'String', 'Exposure Time (seconds)', ...
    'Position', [5, BigPanelHeight-40, 200, 15], ...
    'HorizontalAlignment', 'left');
handles.TextExposureTimeLampFocus = uicontrol(...
    'Parent', SCMOSControlPanel, 'Style', 'Text', ...
    'String', 'Lamp focus:', ...
    'Position', [25, BigPanelHeight-55, 100, 15], ...
    'HorizontalAlignment', 'left');
handles.EditExposureTimeLampFocus = uicontrol(...
    'Parent', SCMOSControlPanel, 'Style', 'Edit', ...
    'Position', [150, BigPanelHeight-55, 50, 15], ...
    'HorizontalAlignment', 'left', ...
    'Callback', {@changeSCMOSExposureTime, 'LampFocus'});
handles.TextExposureTimeLampCapture = uicontrol(...
    'Parent', SCMOSControlPanel, 'Style', 'Text', ...
    'String', 'Lamp capture:', ...
    'Position', [25, BigPanelHeight-70, 100, 15], ...
    'HorizontalAlignment', 'left');
handles.EditExposureTimeLampCapture = uicontrol(...
    'Parent', SCMOSControlPanel, 'Style', 'Edit', ...
    'Position', [150, BigPanelHeight-70, 50, 15], ...
    'HorizontalAlignment', 'left', ...
    'Callback', {@changeSCMOSExposureTime, 'LampCapture'});
handles.TextExposureTimeLaserFocus = uicontrol(...
    'Parent', SCMOSControlPanel, 'Style', 'Text', ...
    'String', 'Laser focus:', ...
    'Position', [25, BigPanelHeight-85, 100, 15], ...
    'HorizontalAlignment', 'left');
handles.EditExposureTimeLaserFocus = uicontrol(...
    'Parent', SCMOSControlPanel, 'Style', 'Edit', ...
    'Position', [150, BigPanelHeight-85, 50, 15], ...
    'HorizontalAlignment', 'left', ...
    'Callback', {@changeSCMOSExposureTime, 'LaserFocus'});
handles.TextExposureTimeLaserSequence = uicontrol(...
    'Parent', SCMOSControlPanel, 'Style', 'Text', ...
    'String', 'Laser sequence:', ...
    'Position', [25, BigPanelHeight-100, 100, 15], ...
    'HorizontalAlignment', 'left');
handles.EditExposureTimeLaserSequence = uicontrol(...
    'Parent', SCMOSControlPanel, 'Style', 'Edit', ...
    'Position', [150, BigPanelHeight-100, 50, 15], ...
    'HorizontalAlignment', 'left', ...
    'Callback', {@changeSCMOSExposureTime, 'LaserSequence'});
TopButtonPosition = ...
    [floor(SmallPanelWidth/2 - 125/2), BigPanelHeight-215, 125, 25];
handles.ButtonFindCoverslip = uicontrol('Parent', SCMOSControlPanel, ...
    'Style', 'pushbutton', 'String', 'Find Coverslip', ...
    'Position', TopButtonPosition, ...
    'Callback', @findCoverslip);
handles.ButtonResetSCMOS = uicontrol('Parent', SCMOSControlPanel, ...
    'Style', 'pushbutton', 'String', 'Reset sCMOS', ...
    'Position', TopButtonPosition + [0, -25, 0, 0], ...
    'Callback', @resetSCMOS);
handles.ButtonAbortAcquisition = uicontrol('Parent', SCMOSControlPanel, ...
    'Style', 'pushbutton', 'String', 'Abort Acquisition', ...
    'Position', TopButtonPosition + [0, -50, 0, 0], ...
    'Callback', @abortAcquisition);

% Create a control panel for the ROI selection tool and add the sub-ROI 
% selection buttons.
ROISelectionPanel = uipanel(GuiFig, 'Title', 'ROI Selection Tool', ...
    'FontWeight', 'bold', 'Units', 'pixels', ...
    'Position', FirstRowStartPosition ...
    + [2*(SmallPanelWidth+10), 0, BigPanelWidth, BigPanelHeight]);
for ii = 1:10
    for jj = 1:10
        ButtonString = sprintf('%d,%d', ii, jj);
        uicontrol('Parent', ROISelectionPanel, 'Style', 'pushbutton', ...
            'String', ButtonString, 'BackgroundColor', [0, 1, 0], ...
            'Position', [5 + 30*(jj-1), 275 - 30*(ii-1), 30, 30], ...
            'TooltipString', ...
            sprintf('%2i cell(s) selected in this subregion', 0), ...
            'Callback', @exposeGridPoint);
    end
end

% Create a control panel for laser controls and add the needed controls.
LaserControlPanel = uipanel(GuiFig, 'Title', 'Lasers', ...
    'FontWeight', 'bold', 'Units', 'pixels', ...
    'Position', SecondRowStartPosition ...
    + [0, 0, SmallPanelWidth, SmallPanelHeight]);
uicontrol('Parent', LaserControlPanel,'Style', 'Text', ...
    'String', '647nm Laser', ...
    'Position', [5, SmallPanelHeight-40, 200, 15], ...
    'HorizontalAlignment', 'left');
uicontrol('Parent', LaserControlPanel, 'Style', 'Text', ...
    'String', 'Sequence Power (mW):', ...
    'Position', [25, SmallPanelHeight-55, 125, 15], ...
    'HorizontalAlignment', 'left');
handles.Edit647PowerSequence = uicontrol(...
    'Parent', LaserControlPanel, 'Style', 'Edit', ...
    'Position', [150, SmallPanelHeight-55, 50, 15], ...
    'HorizontalAlignment', 'left', ...
    'Callback', {@setLaserPower, 'LaserPowerSequence'});
uicontrol('Parent', LaserControlPanel, 'Style', 'Text', ...
    'String', 'Focus Power (mW):', ...
    'Position', [25, SmallPanelHeight-70, 125, 15], ...
    'HorizontalAlignment', 'left');
handles.Edit647PowerFocus = uicontrol(...
    'Parent', LaserControlPanel, 'Style', 'Edit', ...
    'Position', [150, SmallPanelHeight-70, 50, 15], ...
    'HorizontalAlignment', 'left', ...
    'Callback', {@setLaserPower, 'LaserPowerFocus'});
uicontrol('Parent', LaserControlPanel, 'Style', 'Text', ...
    'String', '405nm Laser', ...
    'Position', [5, SmallPanelHeight-100, 200, 15], ...
    'HorizontalAlignment', 'left');
uicontrol('Parent', LaserControlPanel, 'Style', 'Text', ...
    'String', 'Activation Power (mW):', ...
    'Position', [25, SmallPanelHeight-130, 125, 15], ...
    'HorizontalAlignment', 'left');
handles.Edit405PowerActivate = uicontrol(...
    'Parent', LaserControlPanel, 'Style', 'Edit', ...
    'Position', [150, SmallPanelHeight-115, 50, 15], ...
    'HorizontalAlignment', 'left', ...
    'Callback', {@setLaserPower, 'LaserPower405Activate'});
uicontrol('Parent', LaserControlPanel, 'Style', 'Text', ...
    'String', 'Bleaching Power (mW):', ...
    'Position', [25, SmallPanelHeight-115, 125, 15], ...
    'HorizontalAlignment', 'left');
handles.Edit405PowerBleach = uicontrol(...
    'Parent', LaserControlPanel, 'Style', 'Edit', ...
    'Position', [150, SmallPanelHeight-130, 50, 15], ...
    'HorizontalAlignment', 'left', ...
    'Callback', {@setLaserPower, 'LaserPower405Bleach'});

% Create a control panel for alignment/registration controls and add the 
% needed controls.
RegistrationControlPanel = uipanel(GuiFig, ...
    'Title', 'Alignment/Registration', 'FontWeight', 'bold', ...
    'Units', 'pixels', ...
    'Position', SecondRowStartPosition ...
    + [SmallPanelWidth+10, 0, SmallPanelWidth, SmallPanelHeight]);
uicontrol('Parent', RegistrationControlPanel, 'Style', 'text', ...
    'String', 'Use Active Registration', ...
    'Position', [5, SmallPanelHeight-40, 125, 15], ...
    'HorizontalAlignment', 'left');
handles.CheckboxActiveReg = uicontrol(...
    'Parent', RegistrationControlPanel, 'Style', 'checkbox', ...
    'Position', [5+125, SmallPanelHeight-40, 15, 15], ...
    'Callback', @useActiveReg);
uicontrol('Parent', RegistrationControlPanel, 'Style', 'text', ...
    'String', 'Use Periodic Registration', ...
    'Position', [5, SmallPanelHeight-70, 125, 15]);
handles.CheckboxPeriodicReg = uicontrol(...
    'Parent', RegistrationControlPanel, 'Style', 'checkbox', ...
    'Position', [5+125, SmallPanelHeight-70, 15, 15], ...
    'Callback', @usePeriodicReg); 
uicontrol('Parent', RegistrationControlPanel, 'Style', 'text', ...
    'String', 'after every         sequence(s)', ...
    'Position', [15, SmallPanelHeight-85, 150, 15]);
handles.EditboxPeriodicReg = uicontrol(...
    'Parent', RegistrationControlPanel, 'Style', 'edit', ...
    'String', obj.NSeqBeforePeriodicReg, ...
    'Position', [75, SmallPanelHeight-85, 20, 15]);
TopButtonPosition = ...
    [floor(SmallPanelWidth/2 - 125/2), SmallPanelHeight-125, 125, 25];
handles.ButtonFindCoverslipOffset = uicontrol(...
    'Parent', RegistrationControlPanel, ...
    'Style', 'pushbutton', 'String', 'Find Coverslip Offset', ...
    'Position', TopButtonPosition, 'Callback', @findCoverslipOffset);

% Create a control panel for the directory/filename controls and add the
% needed controls.
FileSavePanel = uipanel(GuiFig, 'Title', 'Directory/File Options', ...
    'FontWeight', 'bold', 'Units', 'pixels', ...
    'Position', SecondRowStartPosition ...
    + [2*(SmallPanelWidth+10), 0, BigPanelWidth, SmallPanelHeight]);
uicontrol('Parent', FileSavePanel, 'Style', 'edit', ...
    'String', 'Save Directory:', 'Enable', 'off', ...
    'Position', [5, SmallPanelHeight-50, 85, 20]);
handles.EditSaveDirectory = uicontrol('Parent', FileSavePanel, ...
    'Style', 'edit', ...
    'Position', [5+85, SmallPanelHeight-50, BigPanelWidth-95, 20]);
uicontrol('Parent', FileSavePanel, 'Style', 'edit', ...
    'String', 'Coverslip Name:', 'Enable', 'off', ...
    'Position', [5, SmallPanelHeight-80, 85, 20]);
handles.EditCoverslipName = uicontrol('Parent', FileSavePanel, ...
    'Style', 'edit', ...
    'Position', [5+85, SmallPanelHeight-80, BigPanelWidth-95, 20]);
uicontrol('Parent', FileSavePanel, 'Style', 'edit', ...
    'String', 'Label Number:', 'Enable', 'off', ...
    'Position', [5, SmallPanelHeight-110, 85, 20]);
handles.EditLabelNumber = uicontrol('Parent', FileSavePanel, ...
    'Style', 'edit', 'Position', [5+85, SmallPanelHeight-110, 25, 20]);
uicontrol('Parent', FileSavePanel, 'Style', 'text', ...
    'String', 'Indicate Photobleaching Round', ...
    'Position', [5+140, SmallPanelHeight-113, 150, 20], ...
    'TooltipString', 'Select to add _bleaching tag to the filename');
handles.CheckboxPhotobleach = uicontrol('Parent', FileSavePanel, ...
    'Style', 'checkbox', ...
    'Position', [5+290, SmallPanelHeight-113, 25, 25], ...
    'TooltipString', 'Select to add _bleaching tag to the filename', ...
    'Callback', @updateIsBleach);

% Create a control panel for the final collection controls and add general 
% controls/displays related to workflow control/acquisition.
CollectionPanel = uipanel(GuiFig, 'Title', 'Acquisition/Status', ...
    'FontWeight', 'bold', 'Units', 'pixels', ...
    'Position', ThirdRowStartPosition + [0, 0, XSize-5, SmallPanelHeight]);
handles.ButtonFindAutocollect = uicontrol('Parent', CollectionPanel, ...
    'Style', 'pushbutton', 'String', 'Start Autocollect', ...
    'Position', [5, SmallPanelHeight-50, 125, 25], ...
    'Callback', @autoCollect);

% Set GUI parameter displays based on object properties.
properties2gui()

% Define the callback functions needed by the GUI controls/other GUI
% methods that we need.
    function gui2properties()
        % Set the object properties based on the GUI controls.
        obj.TopDir = handles.EditSaveDirectory.String;
        obj.CoverslipName = handles.EditCoverSlipName.String;
        obj.LabelIdx = str2double(handles.EditLabelNumber.String);
        obj.NSeqBeforePeriodicReg = ...
            str2double(handles.EditboxPeriodicReg.String);
    end

    function properties2gui()
        % Set the GUI controls/display based on object properties.
        handles.EditSaveDirectory.String = obj.TopDir;
        handles.EditCoverSlipName.String = obj.CoverslipName;
        handles.EditLabelNumber.String = obj.LabelIdx;

        % Update sample stage property displays.
        if ~isempty(obj.StageStepper)
            StepperPositionY = obj.StageStepper.getPosition(1);
            StepperPositionX = obj.StageStepper.getPosition(2);
            StepperPositionZ = obj.StageStepper.getPosition(3);
            handles.TextStepperY.String = ...
                sprintf('Y: %1.3f', StepperPositionY);
            handles.TextStepperX.String = ...
                sprintf('X: %1.3f', StepperPositionX);
            handles.TextStepperZ.String = ...
                sprintf('Z: %1.3f', StepperPositionZ);
        end
        if ~isempty(obj.StagePiezoX) && ~isempty(obj.StagePiezoY) && ...
                ~isempty(obj.StagePiezoZ)
            PiezoPositionY = obj.StagePiezoY.getPosition;
            PiezoPositionX = obj.StagePiezoX.getPosition;
            PiezoPositionZ = obj.StagePiezoZ.getPosition;
            handles.TextStepperY.String = ...
                sprintf('Y: %2.5f', PiezoPositionY);
            handles.TextStepperX.String = ...
                sprintf('X: %2.5f', PiezoPositionX);
            handles.TextStepperZ.String = ...
                sprintf('Z: %2.5f', PiezoPositionZ);
        end
        
        % Registration/alignment properties.
        handles.EditboxPeriodicReg.String = obj.NSeqBeforePeriodicReg;
        handles.CheckboxActiveReg.Value = obj.UseActiveReg;
        handles.CheckboxPeriodicReg.Value = obj.UsePeriodicReg;
        
        % Main sCMOS camera properties.
        handles.EditExposureTimeLampFocus.String = ...
            obj.ExposureTimeLampFocus;
        handles.EditExposureTimeLampCapture.String = ...
            obj.ExposureTimeCapture;
        handles.EditExposureTimeLaserFocus.String = ...
            obj.ExposureTimeLaserFocus;
        handles.EditExposureTimeLaserSequence.String = ...
            obj.ExposureTimeSequence;
        
        % Laser properties.
        handles.Edit647PowerSequence.String = obj.LaserPowerSequence;
        handles.Edit647PowerFocus.String = obj.LaserPowerFocus;
        handles.Edit405PowerActivate.String = obj.LaserPower405Activate;
        handles.Edit405PowerBleach.String = obj.LaserPower405Bleach;
    end

    function stepperControl(Source, ~)
        % Callback for uicontrol of the sample stage stepper along z.
        
        % Ensure the object properties are set based on the GUI.
        gui2properties();
        
        % Move the sample stage z stepper based on the uicontrol Event.
        switch Source.String
            case 'UP'
                PosStepZ = obj.StageStepper.getPosition(3);
                PosZ = PosStepZ + obj.StepperLargeStep;
                obj.StageStepper.moveToPosition(3, PosZ);
            case 'up'
                PosStepZ = obj.StageStepper.getPosition(3);
                PosZ = PosStepZ + obj.StepperSmallStep;
                obj.StageStepper.moveToPosition(3, PosZ);
            case 'down'
                PosStepZ = obj.StageStepper.getPosition(3);
                PosZ = PosStepZ - obj.StepperSmallStep;
                obj.StageStepper.moveToPosition(3, PosZ);
            case 'DOWN'
                PosStepZ = obj.StageStepper.getPosition(3);
                PosZ = PosStepZ - obj.StepperLargeStep;
                obj.StageStepper.moveToPosition(3, PosZ);
        end
        
        % Ensure the GUI reflects object properties.
        properties2gui();
    end

    function zPiezoControl(~, Event)
        % Callback for uicontrol of the sample stage piezo in the z
        % dimension.  This controlled by the mousewheel when the GUI figure
        % is the selected figure.
        
        % Ensure the object properties are set based on the GUI.
        gui2properties();
        
        % Move the z piezo based on the uicontrol Event.
        if Event.VerticalScrollCount>0 % Move Down
            obj.movePiezoDownSmall();
        else % Move up
            obj.movePiezoUpSmall();
        end
        
        % Ensure the GUI reflects object properties.
        properties2gui();
    end

    function loadSample(~, ~)
        % Callback for the Load Sample button, which will move the sample
        % stage such that the sample is sufficiently close to the objective
        % to allow for finding the coverslip.
        
        % Ensure the object properties are set based on the GUI.
        gui2properties();
        
        % Load the sample.
        obj.loadSample;
        
        % Ensure the GUI reflects object properties.
        properties2gui();
    end

    function unloadSample(~, ~)
        % Callback for the Unload Sample button, which will move the sample
        % stage to a position appropriate for removing the sample holder.
        
        % Ensure the object properties are set based on the GUI.
        gui2properties();
        
        % Unload the sample.
        obj.unloadSample();
        
        % Ensure the GUI reflects object properties.
        properties2gui();
    end

    function resetPiezos(~, ~)
        % Callback for the Reset Piezos button, which will attempt to close
        % and then re-open the connection to each individual piezo.
                
        % Ensure the object properties are set based on the GUI.
        gui2properties();
        
        % Ensure that the piezo objects exist and then proceed with the
        % reset.
        if ~isempty(obj.StagePiezoX) && ~isempty(obj.StagePiezoY) && ...
                ~isempty(obj.StagePiezoZ)
            obj.StagePiezoX.reset();
            obj.StagePiezoY.reset();
            obj.StagePiezoZ.reset();
        end
    
        % Ensure the GUI reflects object properties.
        properties2gui();
    end

    function changeSCMOSExposureTime(Source, ~, ExpTimeType)
        % Callback for edit boxes whose values determine the exposure
        % time(s) of the main sCMOS camera.
        
        % Ensure the object properties are set based on the GUI.
        gui2properties();
        
        % Set the appropriate object property based on the input
        % ExpTimeType.
        switch ExpTimeType
            case 'LampFocus'
                obj.ExposureTimeLampFocus = str2double(Source.String);
            case 'LampCapture'
                obj.ExposureTimeCapture = str2double(Source.String);
            case 'LaserFocus'
                obj.ExposureTimeLaserFocus = str2double(Source.String);
            case 'LaserSequence'
                obj.ExposureTimeSequence = str2double(Source.String);
        end
        
        % Ensure the GUI reflects object properties.
        properties2gui();
    end

    function setLaserPower(~, ~, LaserPowerType)
        % Callback for the edit boxes whose values determine the laser
        % power(s) of both the 647nm and the 405nm lasers.
        
        % Ensure the object properties are set based on the GUI.
        gui2properties();
        
        % Set the appropriate object property based on the input
        % LaserPowerType.
        switch LaserPowerType
            case 'LaserPowerSequence'
                obj.LaserPowerSequence = str2double(Source.String);
            case 'LaserPowerFocus'
                obj.LaserPowerFocus = str2double(Source.String);
            case 'LaserPower405Activate'
                obj.LaserPower405Activate = str2double(Source.String);
            case 'LaserPower405Bleach'
                obj.LaserPower405Bleach = str2double(Source.String);
        end
        
        % Ensure the GUI reflects object properties.
        properties2gui();
    end

    function findCoverslip(~, ~)
        % Callback for the Find Coverslip button, which illuminates the
        % sample and shows the camera view so that the user can move the
        % stage around and find the coverslip.
        
        % Ensure the object properties are set based on the GUI.
        gui2properties();
        
        % Call the appropriate method of obj. to begin the coverslip search
        % process.
        obj.findCoverSlipFocus()
        
        % Ensure the GUI reflects object properties.
        properties2gui();
    end

    function exposeGridPoint(Source, ~)
        % Callback for button click events on the ROI selection buttons.
        
        % Update object properties based on the GUI controls.
        gui2properties();
        
        % Determine how many cells have been selected prior to this button
        % click (to be used later).
        NumSelectedCells = obj.CurrentCellIdx;
        
        % Set the object property for the current grid index and then open
        % begin the cell selection workflow.
        CurrentGridIndex = sscanf(Source.String, '%d,%d');
        obj.CurrentGridIdx = CurrentGridIndex';
        obj.exposeGridPoint();
        
        % Add indicators to the GUI to show that this region has been
        % clicked and display relevant information about the selection.
        Source.BackgroundColor = [0, 1, 1]; % clicked box is now cyan
        if obj.CurrentCellIdx > NumSelectedCells
            % The user has selected a cell in the currently clicked
            % sub-region, update the tooltip string to reflect the
            % selection.
            NumCellsInCurrentROI = sscanf(Source.TooltipString, '%2i');
            Source.TooltipString = ...
                sprintf('%2i cell(s) selected in this subregion', ...
                NumCellsInCurrentROI + 1);
        end
        
        % Ensure the GUI reflects object properties.
        properties2gui();
    end

    function findCoverslipOffset(~, ~)
        % Callback for the Find Coverslip Offset button, used to find the
        % offset of the coverslip once it's been re-mounted onto the sample
        % stage.
        
        % Ensure the object properties are set based on the GUI.
        gui2properties();
        
        % Call the appropriate object method to find the coverslip offset
        % manually.
        obj.findCoverSlipOffset_Manual();
        
        % Ensure the GUI reflects object properties.
        properties2gui();
    end

    function autoCollect(~, ~)
        % Callback for the Start Autocollect button, which begins the
        % automated acquisiton process for all selected cells.
        
        % Ensure the object properties are set based on the GUI.
        gui2properties();
        
        % Begin the automated collection process.
        obj.autoCollect()
        
        % Ensure the GUI reflects object properties.
        properties2gui();
    end

    function resetSCMOS(~,~)
        % Callback for the Reset sCMOS button.
        
        % Ensure the object properties are set based on the GUI.
        gui2properties();
        
        % Call the cameras reset method.
        obj.CameraSCMOS.reset();
        
        % Ensure the GUI reflects object properties.
        properties2gui();
    end

    function abortAcquisition(~, ~)
        % Callback for the abort acquisition button.
        
        % Ensure the object properties are set based on the GUI.
        gui2properties();
        
        % Call the cameras abort method.
        obj.CameraSCMOS.abort();
        
        % Ensure the GUI reflects object properties.
        properties2gui();
    end

    function useActiveReg(Source, ~)
        % Callback which sets the UseActiveReg property of
        % MIC_SEQ_SRcollect to 1 when checked and 0 otherwise.
        
        % Ensure the object properties are set based on the GUI.
        gui2properties();
        
        % Set UseActiveReg to the desired value.
        obj.UseActiveReg = Source.Value; % ==1 if checked, ==0 otherwise
        
        % If using active registration, ensure periodic registration is
        % turned off.
        if Source.Value
            obj.UsePeriodicReg = 0;
            handles.CheckboxPeriodicReg.Value = 0;
        end
        
        % Ensure the GUI reflects object properties.
        properties2gui();
    end

    function usePeriodicReg(Source, ~)
        % Callback which sets the UsePeriodicReg property of
        % MIC_SEQ_SRcollect to 1 when checked and 0 otherwise..
        
        % Ensure the object properties are set based on the GUI.
        gui2properties();
        
        % Set UsePeriodicReg to the desired value.
        obj.UsePeriodicReg = Source.Value; % ==1 if checked, ==0 otherwise
        
        % If using periodic registration, ensure active registration is
        % turned off.
        if Source.Value
            obj.UseActiveReg = 0;
            handles.CheckboxActiveReg.Value = 0;
        end
        
        % Ensure the GUI reflects object properties.
        properties2gui();
    end

    function updateIsBleach(Source, ~)
        % Sets the IsBleach property of MIC_SEQ_SRcollect to 1 when
        % checked, otherwise it sets it to 0.
        
        % Ensure the object properties are set based on the GUI.
        gui2properties();
        
        % Set the object property IsBleach to the chosen value.
        obj.IsBleach = Source.Value; % ==1 if checked, ==0 otherwise
        
        % Ensure the GUI reflects object properties.
        properties2gui();
    end

end