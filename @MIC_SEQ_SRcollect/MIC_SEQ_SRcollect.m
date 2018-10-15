classdef MIC_SEQ_SRcollect < MIC_Abstract
% MIC_SEQ_SRcollect SuperResolution data collection software.
% Super resolution data collection class for Sequential microscope
% Works with Matlab Instrument Control (MIC) classes since March 2017

%  usage: SRC=MIC_SEQ_SRcollect();
%
% REQUIRES:
%   Matlab 2014b or higher
%   MIC_Abstract
%   MIC_LightSource_Abstract
%   MIC_CrystaLaser405
%   MIC_TcubeLaserDiode
%   MIC_ThorlabsLED
%   MIC_MCLNanoDrive
%   MIC_MPBLaser
%   MIC_IMGSourceCamera
%   MIC_TCubePiezo
%   MIC_StepperMotor
%   MIC_ShutterTTL
%   MIC_FlipMountTTL

% First version: Sheng Liu 
% Second version: Farzin Farzam  
% MIC compatible version: Farzin Farzam
% Lidke Lab 2017
% old version of this code is named SeqAutoCollect.m and can be found at
% documents>MATLAB>Instrumentation>development>SeqAutoCollect
    properties
        % Hardware objects
        CameraSCMOS; % Main Data Collection Camera
        CameraIR; % Active Stabilization Camera
        StagePiezoX; % Linear Piezo Stage in X direction
        StagePiezoY; % Linear Piezo Stage in Y direction
        StagePiezoZ; % Linear Piezo Stage in Z direction
        StageStepper; % Stepper Motor Stage
        Lamp850; % LED Lamp at 850 nm
        Lamp660; % LED Lamp at 660 nm
        Laser647; % MPB 647 Laser
        Laser405; % ThorLabs 405 Diode Laser
        FlipMount; % FlipMount for Laser Attenuation
        Shutter; % Shutter for Laser Block
 
        % Static Instrument Settings (never changed during use of this class)
        SCMOS_UseDefectCorrection = 0;
        IRCamera_ExposureTime;
        IRCamera_ROI = [513, 768, 385, 640]; % IR Camera ROI Center 256
        Lamp850Power = 7;
        Lamp660Power = 14;
        SCMOS_PixelSize = .104; % microns
        
        % Operational properties.
        LampWait = 0.1; % Time to wait for full power to lamp (seconds)
        ExposureTimeLampFocus = 0.01;
        ExposureTimeLaserFocus = 0.2;
        ExposureTimeSequence = 0.01;
        ExposureTimeCapture = 0.2;
        NumberOfFrames = 2000;
        NumberOfSequences = 20;
        NumberOfPhotoBleachingIterations = 8;
        StabPeriod = 5; % Time between stabilization events (seconds)
        GridCorner = [1, 1] % 10x10 Full Frame Grid Corner (mm)
        SCMOS_ROI_Collect = [897, 1152, 897, 1152];
        SCMOS_ROI_Full = [1, 2048, 1, 2048];
        OffsetDZ = 5; % Micron
        OffsetSearchZ = 25; % Micron
        Use405 = 1;
        LaserPowerSequence = 300;
        LaserPowerFocus = 50;
        LaserPower405Activate = 11.84; % max power, for now
        LaserPower405Bleach = 11.84;
        IsBleach = 0; % boolean: 1 for a photobleach round, 0 otherwise
        StepperLargeStep = 0.05; % Large Stepper motor step (mm)
        StepperSmallStep = 0.002; % Small Stepper motor step (mm)
        PiezoStep = 0.1; % Piezo step (micron)
        UseManualFindCell = 0;
        
        % Misc. file directories, directories, and indices.
        TopDir;
        CoverslipName;
        LabelIdx = 1;
        CellGridIdx;
        CurrentCellIdx = 1;
        CurrentGridIdx = [1, 1];
        CoverSlipOffset = [0, 0, 0]; % Remounting error (mm)
        
        % Registration classes.
        ActiveReg; % Active registration with IR Camera
        AlignReg; % Active alignment object
        UseActiveReg = 1; % boolean: 1 uses active registration, 0 doesn't
        UsePeriodicReg = 0; % boolean: 1 periodically re-aligns, 0 doesn't
        NSeqBeforePeriodicReg = 3; % seq. collected before periodic reg.
        
        % Transient Properties
        GuiFigureStage
        GuiFigureMain
        
        % Misc. other properties.
        SaveDir = 'Y:\'; % Save Directory
        AbortNow = 0; % Flag for aborting acquisition
        SaveFileType = 'h5'; % .h5 currently only option
    end
    
    properties (SetAccess = protected)
        InstrumentName = 'MIC_SEQ_SRcollect';
    end
        
    properties (Hidden)
        % StartGUI == 1 will start the GUI on creation of a class instance.
        % StartGUI == 0 will not start the GUI on creation.
        StartGUI = 1;
    end
    
    methods
        function obj = MIC_SEQ_SRcollect(RunTestingMode)
            % Enable the autonaming feature of MIC_Abstract.
            obj = obj@MIC_Abstract(~nargout);
            
            % Check if the input RunTestingMode was passed, and if so
            % proceed to create the class without setup of the instruments.
            if exist('RunTestingMode', 'var') && RunTestingMode
                return
            end
            
            % Ask the user to confirm sample is not fixed to the stage,
            % throw an error as a reminder if they answer Yes.
            proceedstr = questdlg('Is the sample fixed on the stage?', ...
                'Warning', 'Yes', 'No', 'Yes'); % default selection 'Yes'
            if strcmp('Yes', proceedstr)
                error(['Sample is fixed on the stage!  ', ...
                    'Remove the sample and restart SeqSRcollect.']);
            end

            % Setup instruments, ensuring proper order is maintained.
            obj.setupSCMOS();
            obj.setupIRCamera();
            obj.setupStagePiezo();
            obj.setupLamps();
            obj.setupLasers();
            obj.setupStageStepper();
            obj.setupFlipMountTTL();
            obj.setupShutterTTL();
            obj.AlignReg = MIC_SeqReg3DTrans(obj.CameraSCMOS, ...
                obj.StagePiezoX, obj.StagePiezoY, obj.StagePiezoZ, ...
                obj.StageStepper); % active registration object
            obj.AlignReg.PixelSize = 0.104; % microns (SCMOS camera)
            obj.unloadSample(); % move stage up so user can mount sample
        end
        
        function delete(obj)
            % Class destructor.
            delete(obj.CameraIR);
            obj.Laser647.off(); % ensure the 647 laser is turned off
        end
        
        function [Attributes, Data, Children] = exportState(obj)
            % exportState Exports current state of all hardware objects
            % and SEQ_SRcollect settings
            
            % First, call exportState() method for the Children of obj.
            [Children.CameraSCMOS.Attributes, ...
                Children.CameraSCMOS.Data, ...
                Children.CameraSCMOS.Children] = ...
                    obj.CameraSCMOS.exportState();
            [Children.CameraIR.Attributes, ...
                Children.CameraIR.Data, ...
                Children.CameraIR.Children] = ...
                    obj.CameraIR.exportState();
            [Children.StageStepper.Attributes, ...
                Children.StageStepper.Data, ...
                Children.StageStepper.Children] = ...
                    obj.StageStepper.exportState();
            [Children.Laser405.Attributes, ...
                Children.Laser405.Data, ...
                Children.Laser405.Children] = ...
                    obj.Laser405.exportState();
            [Children.Laser647.Attributes, ...
                Children.Laser647.Data, ...
                Children.Laser647.Children] = ...
                    obj.Laser647.exportState();
            [Children.Lamp850.Attributes, ...
                Children.Lamp850.Data, ...
                Children.Lamp850.Children] = ...
                    obj.Lamp850.exportState();
            [Children.Lamp660.Attributes, ...
                Children.Lamp660.Data, ...
                Children.Lamp660.Children] = ...
                    obj.Lamp660.exportState();
            [Children.AlignReg.Attributes, ...
                Children.AlignReg.Data, ...
                Children.AlignReg.Children] = ...
                    obj.AlignReg.exportState();
            if obj.UseActiveReg
                % We should only export this object if it was used.
                [Children.ActiveReg.Attributes, ...
                    Children.ActiveReg.Data, ...
                    Children.ActiveReg.Children] = ...
                        obj.ActiveReg.exportState();
            end
            
            % Store the desired obj properties to be exported.
            Attributes.ExposureTimeLampFocus = obj.ExposureTimeLampFocus;
            Attributes.ExposureTimeLaserFocus = obj.ExposureTimeLaserFocus;
            Attributes.ExposureTimeSequence = obj.ExposureTimeSequence;
            Attributes.ExposureTimeCapture = obj.ExposureTimeCapture;
            Attributes.NumberOfFrames = obj.NumberOfFrames;
            Attributes.NumberOfSequences = obj.NumberOfSequences;
            Attributes.NumberOfPhotoBleachingIterations = ...
                obj.NumberOfPhotoBleachingIterations;
            Attributes.CameraROI = obj.SCMOS_ROI_Collect;
            Attributes.SCMOS_ROI_Full = obj.SCMOS_ROI_Full;
            Attributes.IRCamera_ROI = obj.IRCamera_ROI;
            Attributes.CameraPixelSize=obj.SCMOS_PixelSize;
            Attributes.SaveDir = obj.SaveDir;
            Attributes.LaserPower405Activate = obj.LaserPower405Activate;
            Attributes.LaserPower405Bleach = obj.LaserPower405Bleach;
            Attributes.LaserPowerSequence = obj.LaserPowerSequence;
            Attributes.LaserPowerFocus = obj.LaserPowerFocus;
            
            % Store the Data to be exported.
            Data=[]; % Export as empty for now...
        end
        
        autoCollect(obj,StartCell, RefDir);
        exposeCellROI(obj); 
        exposeGridPoint(obj);
        findCoverSlipOffset(obj, RefStruct);
        Success=findCoverSlipOffset_Manual(obj, RefStruct);
        saveReferenceImage(obj);
        startSequence(obj, RefStruct, LabelID);
        
        function setupSCMOS(obj)
            % Used to setup the Hamamatsu SCMOS camera.
            obj.CameraSCMOS = MIC_HamamatsuCamera();
            CamSet = obj.CameraSCMOS.CameraSetting;
            CamSet.DefectCorrection.Bit = 1;
            obj.CameraSCMOS.setCamProperties(CamSet);
            obj.CameraSCMOS.ReturnType = 'matlab';
            obj.CameraSCMOS.setCamProperties( ...
                obj.CameraSCMOS.CameraSetting);
            obj.CameraSCMOS.ExpTime_Capture = 0.2;
            obj.CameraSCMOS.ExpTime_Sequence = 0.01;
        end
        
        function setupStagePiezo(obj)
            % Setup the piezos on the NanoMax stage.
            obj.StagePiezoX = MIC_TCubePiezo('81850186', '84850145', 'X');
            obj.StagePiezoY = MIC_TCubePiezo('81850193', '84850146', 'Y');
            obj.StagePiezoZ = MIC_TCubePiezo('81850176', '84850203', 'Z');
            obj.StagePiezoX.center();
            obj.StagePiezoY.center();
            obj.StagePiezoZ.center();
        end
        
        function setupStageStepper(obj)
            % Setup the stepper motors for the NanoMax stage.
            % The StepperMotor Serial Number is 70850323.
            % NOTE: the positions set here are chosen such that the center
            %       GUI button will ~correspond to the center of the well.
            obj.StageStepper = MIC_StepperMotor('70850323');
            obj.StageStepper.moveToPosition(1, 2.0650); % y stepper
            obj.StageStepper.moveToPosition(2, 2.2780); % x stepper
            obj.StageStepper.moveToPosition(3, 2); % z stepper
        end
        
        function setupIRCamera(obj)
            % Setup the IR camera used for active registration.
            obj.CameraIR = MIC_ThorlabsIR();
            obj.CameraIR.ROI = obj.IRCamera_ROI;
            obj.CameraIR.ExpTime_Capture = 0.5;
            
            % Set the save directory based on the current Windows user. 
            % NOTE: This might not ever get used anywhere but I'm keeping
            %       it around because it might be nice if needed someday...
            UserName = java.lang.System.getProperty('user.name');
            timenow = clock; % current time
            obj.SaveDir = sprintf('Y:\\%s%s%02.2g-%02.2g-%02.2g\\', ...
                UserName, filesep, ...
                timenow(1)-2000, timenow(2), timenow(3));
        end
        
        function setupLamps(obj)
            % Setup the LED lamp objects.
            obj.Lamp660 = MIC_ThorlabsLED('Dev2', 'ao0');
            obj.Lamp850 = MIC_ThorlabsLED('Dev2', 'ao1');
        end
        
        function setupLasers(obj)
            % Setup the laser(s) needed.
            obj.Laser647 = MIC_MPBLaser();
            obj.Laser405 = MIC_TCubeLaserDiode('64841724', ...
                'Power', 11.84, 2.49, 10);
            % Usage: 
            % TLD = MIC_TCubeLaserDiode(SerialNo, Mode, ...
            %                           MaxPower, WperA, TIARange)
            % Max power was found to be 11.84 mA when driving the diode at
            % 80% of it's maximum rated current (80.14 mA, ~80 mA).  WperA
            % was found by reading the photodiode current at 1-11 mW laser
            % output in steps of 1 mW and fitting a line to the result,
            % taking the slope to be WperA.  The TIARange was set to the 
            % photodiode setting as set by the dip switches on the laser
            % driver controller.  See DS lab notes 9/10/18.
        end
        
        function setupFlipMountTTL(obj)
            % Setup the flip mount object to control the neutral density
            % filter.
            obj.FlipMount = MIC_FlipMountTTL('Dev1', 'Port0/Line0');
            obj.FlipMount.FilterIn; % place the ND filter in 647 laser path
        end
        
        function setupShutterTTL(obj)
            % Setup the shutter for control of the 647nm laser.
            obj.Shutter = MIC_ShutterTTL('Dev1', 'Port0/Line1');
            obj.Shutter.close; % close the shutter by default
        end
        
        function unloadSample(obj)
            % Raise the sample stage away from the objective.
            obj.StageStepper.moveToPosition(1, 2.0650); % y stepper
            obj.StageStepper.moveToPosition(2, 2.2780); % x stepper
            obj.StageStepper.moveToPosition(3, 4); % z stepper
        end
        
        function loadSample(obj)
            % Lower the sample stage towards the objective
            obj.StageStepper.moveToPosition(1, 2.0650); % y stepper
            obj.StageStepper.moveToPosition(2, 2.2780); % x stepper
            obj.StageStepper.moveToPosition(3, 1.4); % z stepper
        end
        
        function findCoverslipFocus(obj)
            % Displays the entire ROI of the main sCMOS camera while
            % illuminating the sample with the 660nm lamp.  This can be
            % used, e.g., to help find the coverslip when the sample is
            % initially placed on the sample stage.
            
            % Center the piezos before proceeding.
            obj.StagePiezoX.center();
            obj.StagePiezoY.center();
            obj.StagePiezoZ.center();
            
            % Set some camera parameters and begin a focus acquisition.
            obj.CameraSCMOS.ExpTime_Focus = obj.ExposureTimeLampFocus;
            obj.CameraSCMOS.ROI = obj.SCMOS_ROI_Full;
            obj.CameraSCMOS.AcquisitionType = 'focus';
            obj.CameraSCMOS.setup_acquisition();
            obj.Lamp660.setPower(obj.Lamp660Power);
            obj.Lamp660.on;
            obj.CameraSCMOS.start_focus();
            obj.Lamp660.setPower(0);
        end
        
        function Data = captureLamp(obj, ROISelect)
            % Capture an image with 660nm lamp.
            obj.Lamp660.setPower(obj.Lamp660Power);
            pause(obj.LampWait);
            switch ROISelect
                case 'Full'
                    obj.CameraSCMOS.ROI=obj.SCMOS_ROI_Full;
                case 'ROI'
                    obj.CameraSCMOS.ROI=obj.SCMOS_ROI_Collect;
            end
            obj.CameraSCMOS.ExpTime_Capture = obj.ExposureTimeCapture;
            obj.CameraSCMOS.AcquisitionType = 'capture';
            obj.CameraSCMOS.setup_acquisition();
            Data = obj.CameraSCMOS.start_capture();
            obj.Lamp660.setPower(0);
        end
        
        function startROILampFocus(obj)
            % Run the SCMOS in focus mode with the 660nm lamp to allow the 
            % user to focus.
            obj.CameraSCMOS.ExpTime_Focus = obj.ExposureTimeLampFocus;
            obj.CameraSCMOS.ROI = obj.SCMOS_ROI_Collect;
            obj.CameraSCMOS.AcquisitionType = 'focus';
            obj.CameraSCMOS.setup_acquisition();
            obj.Lamp660.setPower(obj.Lamp660Power);
            obj.FlipMount.FilterIn; 
            obj.CameraSCMOS.start_focus();
            obj.startROILaserFocusLow();
            obj.Lamp660.setPower(0);
        end
        
        function startROILaserFocusLow(obj)
            % Run the SCMOS in focus mode with Low Laser Power to allow the
            % user to focus.  
            
            % Run SCMOS in focus mode with Low Laser Power to check
            % fluorescence. 
            % NOTE: Once the laser is turned on once through this function,
            % it will stay on until an acquisition is complete (this is
            % done to avoid the laser power up delay at each cell
            % selection).
            obj.CameraSCMOS.ExpTime_Focus = obj.ExposureTimeLaserFocus;
            obj.CameraSCMOS.ROI = obj.SCMOS_ROI_Collect;
            obj.CameraSCMOS.AcquisitionType = 'focus';
            obj.CameraSCMOS.setup_acquisition();
            obj.Laser647.setPower(obj.LaserPowerFocus);
            obj.FlipMount.FilterIn;
            obj.Shutter.open; % opens shutter for laser
            obj.Laser647.on();
            obj.Lamp660.setPower(0);
            obj.CameraSCMOS.start_focus();
            obj.Shutter.close; % closes shutter to prevent photobleaching
            
            % Ask user if they would like to save the current cell and
            % focus as a reference (question dialog will appear once the
            % figure window for the CameraSCMOS object is closed).
            UseCell = ...
                questdlg('Use this cell and Save Reference Image?', ...
                'Save and Use', 'Yes', 'No', 'Yes'); % default Yes
            if strcmpi(UseCell, 'Yes')
                obj.saveReferenceImage();
            end
        end

        function startROILaserFocusHigh(obj)
            % Run SCMOS in focus mode with High Laser Power.
            obj.CameraSCMOS.ExpTime_Focus = obj.ExposureTimeSequence;
            obj.CameraSCMOS.ROI = obj.SCMOS_ROI_Collect;
            obj.CameraSCMOS.AcquisitionType = 'focus';
            obj.CameraSCMOS.setup_acquisition();
            obj.Laser647.setPower(obj.LaserPowerSequence);
            obj.Laser647.WaitForLaser = 0;
            obj.Shutter.open; % open shutter
            obj.FlipMount.FilterOut; 
            obj.Laser647.on();
            obj.CameraSCMOS.start_focus();
            obj.Laser647.off();
        end
        
        function moveStepperUpLarge(obj)
            % Large stage step up in the z dimension with stepper motor.
            PosStepZ = obj.StageStepper.getPosition(3); % get z position
            PosStepZ = PosStepZ + obj.StepperLargeStep; % proposed z pos.
            obj.StageStepper.moveToPosition(3, PosStepZ); % set new z pos.
        end
        
        function moveStepperDownLarge(obj)
            % Large stage step down in the z dimension with stepper motor.
            PosStepZ = obj.StageStepper.getPosition(3); % get z position
            PosStepZ = PosStepZ - obj.StepperLargeStep; % proposed z pos.
            obj.StageStepper.moveToPosition(3, PosStepZ); % set new z pos.
        end
        
        function moveStepperUpSmall(obj)
            % Small stage step up in the z dimension with stepper motor.
            PosStepZ = obj.StageStepper.getPosition(3); % get z position
            PosStepZ = PosStepZ + obj.StepperSmallStep; % proposed z pos.
            obj.StageStepper.moveToPosition(3, PosStepZ); % set new z pos.
        end
        
        function moveStepperDownSmall(obj)
            % Small stage step down in the z dimension with stepper motor.
            PosStepZ = obj.StageStepper.getPosition(3); % get z position
            PosStepZ = PosStepZ - obj.StepperSmallStep; % proposed z pos.
            obj.StageStepper.moveToPosition(3, PosStepZ); % set new z pos.
        end
        
        function movePiezoUpSmall(obj)
            % Small stage step up in the z dimension with piezo.
            PosPiezoZ=obj.StagePiezoZ.getPosition; % get z position
            PosPiezoZ=PosPiezoZ+obj.PiezoStep; % proposed z pos.
            obj.StagePiezoZ.setPosition(PosPiezoZ); % set new z pos.
        end
        
        function movePiezoDownSmall(obj)
            % Small stage step down in the z dimension with piezo.
            PosPiezoZ = obj.StagePiezoZ.getPosition; % get z position
            PosPiezoZ = PosPiezoZ - obj.PiezoStep; % proposed z pos.
            obj.StagePiezoZ.setPosition(PosPiezoZ); % set new z pos.
        end
    end
    
    methods (Static)
        function State = unitTest()
            % unitTest for the sequential microscope.. not yet written!
        end

    end
end