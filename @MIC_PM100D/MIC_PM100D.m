classdef MIC_PM100D < MIC_PowerMeter_Abstract
    % MIC_PM100D: Matlab Instrument class to control power meter PM100D.
    %
    % ## Description
    % Controls power meter PM100D, gets the current power. It can also gets
    % the current temperature. The wavelengtj of the light can also be
    % set for power measurement (within the sensor limits). The gui shows 
    % a movie of the plot of the
    % measured power where the shown period can be modified. It also shows
    % the current power and the maximum measured power. To run this code
    % you need the power meter to be connected to the machine.
    %
    % ## Constructor
    % Example: P = MIC_PM100D; P.gui
    %
    % ## Key Functions:
    % constructor(), exportState(), send(), minMaxWavelength(), getWavelength(), measure(), setWavelength(), shutdown()
    %
    % ## REQUIREMENTS:
    %    NI_DAQ  (VISA and ICP Interfaces) should be installed.
    %    MATLAB 2014 or higher.
    %    MIC_Abstract.m
    %    MIC_PowerMeter_Abstract.m
    %
    % ### CITATION: Mohamadreza Fazel, Lidkelab, 2017.

    properties (SetAccess=protected)
        InstrumentName='PM100D'; %Name of the instrument.
    end


    methods (Static)
        function obj=MIC_PM100D
            %This is the constructor.
            %example PM = MIC_PM100D
            obj@MIC_PowerMeter_Abstract(~nargout);

            % Find a VISA-USB object.
            % TODO -- the following commands to find the device assume
            % only one device is connected
            vendorinfo = instrhwinfo('visa','ni');
            if isempty(vendorinfo.ObjectConstructorName)
                fprintf('No devices found\n')
                return
            end

            % Use the constructor command to connect to the device.
            s=vendorinfo.ObjectConstructorName{1};
            obj.VisaObj = eval(s);
            fopen(obj.VisaObj);
            fprintf('Connected to VISA power meter device\n')

            % Measure the limits of the wavelength.
            obj.Limits=obj.minMaxWavelength;

            % TODO: this process of using the "Ask" property to determine
            % whether to read light power or temperature is very weird 
            % and should be removed. 
            obj.Ask = 'power'; % by default we read power
        end %constructor

        function unitTest()
            %testing the class.
            try
                TestObj=MIC_PM100D();
                fprintf('Constructor is run and an object of the class is made.\n');
                Limit = minMaxWavelength(TestObj);
                fprintf('Min wavelength: %d, Max wavelength: %d\n', Limit(1),Limit(2));
                getWavelength(TestObj);
                fprintf('The current wavelength is %d nm.\n',TestObj.Lambda);
                TestObj.Lambda=600;
                setWavelength(TestObj);
                fprintf('The wavelength is set to 600 nm.\n');
                State=exportState(TestObj);
                fprintf('The exportState function was successfully tested.\n');
                TestObj.delete();
                fprintf('The port is closed and the object is deleted.\n');
                fprintf('The class is successfully tested :)\n')
            catch E
                fprintf('Sorry an error has occurred :(\n');
                E
            end
        end % unitTest

    end %static methods

    methods

        function  State=exportState(obj)
            %Exporting the class properties to the State.
            State.InstrunetName=obj.InstrumentName;
            State.Lambda=obj.Lambda;
            State.Limits=obj.Limits;
        end

        function Reply=send(obj,Message)
            %Sending a message to the power-meter and getting a feedback.

            fprintf(obj.VisaObj,Message);
            Reply=fscanf(obj.VisaObj,'%s');
        end

        function devInfo = reportDeviceInfo(obj)
            % Return string describing the model number, etc, of the power meter
            devInfo = obj.send('*IDN?');
        end

        function devInfo = reportSensorInfo(obj)
            % Return string describing the sensor head
            devInfo = obj.send(':SYST:SENS:IDN?');
        end

        function autoRange = isAutoRangeEnabled(obj)
            % Return 1 if autorange is enabled. 0 otherwise
            autoRange = obj.send(':SENS:POWER:RANG:AUTO?');
            autoRange = str2num(autoRange);
        end

        function disableAutoRange(obj)
            % Disable auto-range
            fprintf(obj.VisaObj,'SENSE:POWER:RANGE:AUTO OFF');
        end
      
        function enableAutoRange(obj)
            % Enable auto-range
            fprintf(obj.VisaObj,'SENSE:POWER:RANGE:AUTO ON');
        end

        function setAutoRange(obj,autoRange)
            % Set auto-range. 
            % autoRange is a string (TODO: for now)
            %
            % e.g.
            % setAutoRange('0.1')
            fprintf(obj.VisaObj,sprintf('SENSE:POWER:RANGE %s',autoRange));
        end
      
        function Limits=minMaxWavelength(obj)
            %Reading the limits of the wavelength.
            %
            R1=obj.send('SENS:CORR:WAV? MIN');
            R2=obj.send('SENS:CORR:WAV? MAX');
            Limits = [str2double(R1) str2double(R2)];
        end

        function getWavelength(obj)
            %Reading the current wavelength of the instrument.
            obj.Lambda=str2double(send(obj,'SENS:CORR:WAV?'));
            fprintf('Wavelength: %d nm \n',obj.Lambda);
        end

        function Out=measure(obj)
            %This either measures the power or temperature.
            switch obj.Ask
                case 'power'
                    Out=str2double(obj.send('MEASURE:POWER?'))*1000;
                case 'temp'
                    Out=str2double(obj.send('MEASURE:TEMPERATURE?'));
            end
        end

        function out=measurePower(obj)
            % Measure power
            out=str2double(obj.send('MEASURE:POWER?'))*1000;
        end

        function out=measureTemperature(obj)
            % Measure temperature
            out=str2double(obj.send('MEASURE:TEMPERATURE?'));
        end

        function setWavelength(obj,lambda)
            % Setting the compensation wavelength
            %
            % serWavelength(lambda)
            %
            % Inputs
            % lambda [optional] - scalar in nm between 400 and 1100
            %      If lambda is not supplied, the value in the class Lambda
            %      property is used instead. If it is supplied, the Lambda
            %      property is assigned as lambda.
            %
            %
           
            if nargin>1
                if (lambda < obj.Limits(1) || lambda > obj.Limits(2))
                   fprintf('The wavelength is out of the range [%dnm, %dnm]\n', ...
                       obj.Limits);
                   return
                else
                    obj.Lambda = lambda;
                end
            end
            s = sprintf('SENS:CORR:WAV %g ',obj.Lambda);
            fprintf(obj.VisaObj, s);
        end % setWavelength

        function shutdown(obj)
               %This function is called in the destructor to delete the communication port.
               if isempty(obj.VisaObj)
                   return
               end
               fclose(obj.VisaObj);
        end % shutdown

        function delete(obj)
            %This function closes the communication port and close the gui.
           delete(obj.GuiFigure);
           obj.shutdown();
        end % delete

   end % methods

end % classdef
