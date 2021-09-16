% Executive script for object-oriented-based monitor calibration.
%
% 3/27/2014  npc   Wrote it.
% 8/05/2014  npc   Added option to conduct PsychImaging - based calibration
% 3/02/2015  npc   Re-organized script so that settings and options are set in 
%                  a single function.
% 8/30/2016  JAR   Added calibration configuration for the InVivo Sensa Vue
%                  Flat panel monitor located at the Stellar Chance 3T Magnet.
% 10/18/2017 npc   Reset Radiometer before crashing
% 12/12/2017 ana   Added eye tracker LCD case

function SACC_calibrateMonitor
    
    % Select a calibration configuration name
    AvailableCalibrationConfigs = {  ...
        'SACC'
        'SACCPrimary1'
    };
    
    % Default config is SACCPrimary1
    defaultCalibrationConfig = AvailableCalibrationConfigs{find(contains(AvailableCalibrationConfigs, 'SACCPrimary1'))};
    
    while (true)
        fprintf('Available calibration configurations \n');
        for k = 1:numel(AvailableCalibrationConfigs)
            fprintf('\t %s\n', AvailableCalibrationConfigs{k});
        end
        calibrationConfig = input(sprintf('Select a calibration config [%s]: ', defaultCalibrationConfig),'s');
        if isempty(calibrationConfig)
            calibrationConfig = defaultCalibrationConfig;
        end
        if (ismember(calibrationConfig, AvailableCalibrationConfigs))
            break;
        else
           fprintf(2,'** %s ** is not an available calibration configuration. Try again. \n\n', calibrationConfig);
        end
    end
    
    % Generate calibration options and settings
    runtimeParams = [];
    switch calibrationConfig
            
        case 'SACC'
            configFunctionHandle = @generateConfigurationForSACC; 

        case 'SACCPrimary1'
            configFunctionHandle = @generateConfigurationForSACCPrimary1;       
            
        otherwise
            configFunctionHandle = @generateConfigurationForViewSonicProbe;
    end
    

    if (isempty(runtimeParams))
        [displaySettings, calibratorOptions] = configFunctionHandle();
    else
        [displaySettings, calibratorOptions] = configFunctionHandle(runtimeParams);
    end

    
    % Generate the Radiometer object, here a PR650obj.
    radiometerOBJ = generateRadiometerObject(calibrationConfig);
    
    % Generate the calibrator object
    calibratorOBJ = generateCalibratorObject(displaySettings, radiometerOBJ, mfilename);
    
    % Set the calibrator options
    calibratorOBJ.options = calibratorOptions;
        
    % display calStruct if so desired
    beVerbose = false;
    if (beVerbose)
        % Optionally, display the cal struct before measurement
        calibratorOBJ.displayCalStruct();
    end
        
    try 
        % Calibrate !
        calibratorOBJ.calibrate();
            
        if (beVerbose)
            % Optionally, display the updated cal struct after the measurement
            calibratorOBJ.displayCalStruct();
        end
        
        % Optionally, export cal struct in old format, for backwards compatibility with old programs.
        % calibratorOBJ.exportOldFormatCal();
        
        disp('All done with the calibration ...');

        % Shutdown DBLab_Calibrator
        calibratorOBJ.shutDown();
        
        % Shutdown DBLab_Radiometer object
        radiometerOBJ.shutDown();
    
    catch err
        % Shutdown DBLab_Calibrator object  
        if (~isempty(calibratorOBJ))
            % Shutdown calibratorOBJ
            calibratorOBJ.shutDown();
        end
        
        % Shutdown DBLab_Radiometer object
        radiometerOBJ.shutDown();

        rethrow(err)
    end % end try/catch
end

% Configuration function for the SACC display (LED/DLP optical system)
function [displaySettings, calibratorOptions] = generateConfigurationForSACC()
    % Specify where to send the 'Calibration Done' notification email
    emailAddressForNotification = 'seminoh@sas.upenn.edu';
    
    % Specify the @Calibrator's initialization params. 
    % Users should tailor these according to their hardware specs. 
    % These can be set once only, at the time the @Calibrator object is instantiated.
    displayPrimariesNum = 3;
    displaySettings = { ...
        'screenToCalibrate',        2, ...                          % which display to calibrate. main screen = 1, second display = 2
        'desiredScreenSizePixel',   [1920 1080], ...                % pixels along the width and height of the display to be calibrated
        'desiredRefreshRate',       120, ...                        % refresh rate in Hz
        'displayPrimariesNum',      displayPrimariesNum, ...        % for regular displays this is always 3 (RGB) 
        'displayDeviceType',        'monitor', ...                  % this should always be set to 'monitor' for now
        'displayDeviceName',        'SACC', ...                     % a name for the display been calibrated
        'calibrationFile',          'SACC', ...                     % name of calibration file to be generated
        'comment',                  'The SACC LED/DLP optical system' ...          % some comment, could be anything
        };
    
    % Specify the @Calibrator's optional params using a CalibratorOptions object
    % To see what options are available type: doc CalibratorOptions
    % Users should tailor these according to their experimental needs.
    calibratorOptions = CalibratorOptions( ...
        'verbosity',                        2, ...
        'whoIsDoingTheCalibration',         input('Enter your name: ','s'), ...
        'emailAddressForDoneNotification',  GetWithDefault('Enter email address for done notification',  emailAddressForNotification), ...
        'blankOtherScreen',                 0, ...                          % whether to blank other displays attached to the host computer (1=yes, 0 = no), ...
        'whichBlankScreen',                 1, ...                          % screen number of the display to be blanked  (main screen = 1, second display = 2)
        'blankSettings',                    [0.0 0.0 0.0], ...              % color of the whichBlankScreen 
        'bgColor',                          [0.3962 0.3787 0.4039], ...     % color of the background  
        'fgColor',                          [0.3962 0.3787 0.4039], ...     % color of the foreground
        'meterDistance',                    1.0, ...                        % distance between radiometer and screen in meters
        'leaveRoomTime',                    3, ...                          % seconds allowed to leave room
        'nAverage',                         2, ...                          % number of repeated measurements for averaging
        'nMeas',                            4, ...                          % samples along gamma curve
        'nDevices',                         displayPrimariesNum, ...        % number of primaries
        'boxSize',                          600, ...                        % size of calibration stimulus in pixels 
        'boxOffsetX',                       0, ...                          % x-offset from center of screen (neg: leftwards, pos:rightwards)         
        'boxOffsetY',                       0 ...                           % y-offset from center of screen (neg: upwards, pos: downwards)                      
    );
end


% Configuration function for the SACC display (LED/DLP optical system)
function [displaySettings, calibratorOptions] = generateConfigurationForSACCPrimary1()
    % Specify where to send the 'Calibration Done' notification email
    emailAddressForNotification = 'seminoh@sas.upenn.edu';
    
    % Specify the @Calibrator's initialization params. 
    % Users should tailor these according to their hardware specs. 
    % These can be set once only, at the time the @Calibrator object is instantiated.
    displayPrimariesNum = 15;
    displaySettings = { ...
        'screenToCalibrate',        2, ...                          % which display to calibrate. main screen = 1, second display = 2
        'desiredScreenSizePixel',   [1920 1080], ...                % pixels along the width and height of the display to be calibrated
        'desiredRefreshRate',       120, ...                        % refresh rate in Hz
        'displayPrimariesNum',      displayPrimariesNum, ...        % for regular displays this is always 3 (RGB) 
        'displayDeviceType',        'monitor', ...                  % this should always be set to 'monitor' for now
        'displayDeviceName',        'SACCPrimary1', ...             % a name for the display been calibrated
        'calibrationFile',          'SACCPrimary1', ...             % name of calibration file to be generated
        'comment',                  'The SACC LED/DLP subprimary optical system' ...          % some comment, could be anything
        };
    
    % SACCPrimary calibrator - specific params struct
    SACCPrimaryCalibratorSpecificParamsStruct = struct(...
        'DLPbackgroundSettings', [0.5 0.5 0.5], ...                 % Set DLP background to initiate the PTB screen (This is needed because the DLP still works with 3 primaries)
        'whichPrimary',  1, ...                                     % Which primary to calibrate subprimaries for
        'nInputLevels', 252, ...                                    % Number of input levels
        'normalMode', true, ...                                     % Normal mode (set to false for steady on mode)
        'arbitraryBlack', 0.05, ...                                 % Level to set other two primary's subprimaries to, when calibrating 
        'nSubprimaries', 15, ...                                    % Number of subprimaries
        'logicalToPhysical', [0:7 9:15] ...                         % Mapping of logical subprimary number to physical LED to write
        );

    % Specify the @Calibrator's optional params using a CalibratorOptions object
    % To see what options are available type: doc CalibratorOptions
    % Users should tailor these according to their experimental needs.
    calibratorOptions = CalibratorOptions( ...
        'verbosity',                        2, ...
        'whoIsDoingTheCalibration',         input('Enter your name: ','s'), ...
        'emailAddressForDoneNotification',  GetWithDefault('Enter email address for done notification',  emailAddressForNotification), ...
        'blankOtherScreen',                 0, ...                          % whether to blank other displays attached to the host computer (1=yes, 0 = no), ...
        'whichBlankScreen',                 1, ...                          % screen number of the display to be blanked  (main screen = 1, second display = 2)
        'blankSettings',                    zeros(1,displayPrimariesNum), ... % color of the whichBlankScreen 
        'bgColor',                          zeros(1,displayPrimariesNum), ... % color of the background  
        'fgColor',                          zeros(1,displayPrimariesNum), ... %color of the foreground
        'meterDistance',                    1.0, ...                        % distance between radiometer and screen in meters
        'leaveRoomTime',                    3, ...                          % seconds allowed to leave room
        'nAverage',                         5, ...                          % number of repeated measurements for averaging
        'nMeas',                            10, ...                          % samples along gamma curve
        'nDevices',                         displayPrimariesNum, ...        % number of primaries
        'boxSize',                          600, ...                        % size of calibration stimulus in pixels (it was 150 / Semin)
        'boxOffsetX',                       0, ...                          % x-offset from center of screen (neg: leftwards, pos:rightwards)         
        'boxOffsetY',                       0, ...                           % y-offset from center of screen (neg: upwards, pos: downwards)                      
        'skipLinearityTest',                true, ...
        'skipAmbientLightMeasurement',      true, ...
        'skipBackgroundDependenceTest',     true, ...
        'calibratorTypeSpecificParamsStruct', SACCPrimaryCalibratorSpecificParamsStruct ...
    );
end

% Function to generate the calibrator object.
% Users should not modify this function unless they know what they are doing.
function calibratorOBJ = generateCalibratorObject(displaySettings, radiometerOBJ, execScriptFileName)

    % set init params
    calibratorInitParams = displaySettings;
    
    % add radiometerOBJ
    calibratorInitParams{numel(calibratorInitParams)+1} = 'radiometerObj';
    calibratorInitParams{numel(calibratorInitParams)+1} = radiometerOBJ;
    
    % add executive script name
    calibratorInitParams{numel(calibratorInitParams)+1} ='executiveScriptName';
    calibratorInitParams{numel(calibratorInitParams)+1} = execScriptFileName;
        
    % Select and instantiate the calibrator object
    calibratorOBJ = selectAndInstantiateCalibrator(calibratorInitParams, radiometerOBJ);
end


function radiometerOBJ = generateRadiometerObject(calibrationConfig)

    if (strcmp(calibrationConfig, 'debugMode'))
        % Dummy radiometer - measurements will be all zeros
        radiometerOBJ = PR670dev('emulateHardware',  true);
        fprintf('Will employ a dummy PR670dev radiometer (all measurements will be zeros).\n');
        return;
    end
    
    
    % List of available @Radiometer objects
    radiometerTypes = {'PR650dev', 'PR670dev', 'SpectroCALdev'};
    radiometersNum  = numel(radiometerTypes);
    
    % Ask the user to select a calibrator type
    fprintf('\n\n Available radiometer types:\n');
    for k = 1:radiometersNum
        fprintf('\t[%3d]. %s\n', k, radiometerTypes{k});
    end
    defaultRadiometerIndex = 1;
    radiometerIndex = input(sprintf('\tSelect a radiometer type (1-%d) [%d]: ', radiometersNum, defaultRadiometerIndex));
    if isempty(radiometerIndex) || (radiometerIndex < 1) || (radiometerIndex > radiometersNum)
        radiometerIndex = defaultRadiometerIndex;
    end
    fprintf('\n\t-------------------------\n');
    selectedRadiometerType = radiometerTypes{radiometerIndex};
    fprintf('Will employ an %s radiometer object [%d].\n', selectedRadiometerType, radiometerIndex);
    
    if (strcmp(selectedRadiometerType, 'PR650dev'))
        radiometerOBJ = PR650dev(...
            'verbosity',        1, ...                  % 1 -> minimum verbosity
            'devicePortString', '/dev/cu.KeySerial1');  % PR650 port string

    elseif (strcmp(selectedRadiometerType, 'PR670dev'))
        radiometerOBJ = PR670dev(...
            'verbosity',        1, ...       % 1 -> minimum verbosity
            'devicePortString', [] ...       % empty -> automatic port detection
            );
        
        % Specify extra properties
        desiredSyncMode = 'OFF';
        desiredCyclesToAverage = 1;
        desiredSensitivityMode = 'STANDARD';
        desiredApertureSize = '1 DEG';
        desiredExposureTime =  'ADAPTIVE';  % 'ADAPTIVE' or range [1-6000 msec] or [1-30000 msec]
        
        radiometerOBJ.setOptions(...
        	'syncMode',         desiredSyncMode, ...
            'cyclesToAverage',  desiredCyclesToAverage, ...
            'sensitivityMode',  desiredSensitivityMode, ...
            'apertureSize',     desiredApertureSize, ...
            'exposureTime',     desiredExposureTime ...
        );
    elseif (strcmp(selectedRadiometerType, 'SpectroCALdev'))
        radiometerOBJ = SpectroCALdev();
    end
    
end

% Function to select and instantiate a particular calibrator type
% Currently either MGL-based or PTB-3 based.
% Users should not modify this function unless they know what they are doing.
function calibratorOBJ = selectAndInstantiateCalibrator(calibratorInitParams, radiometerOBJ)
    % List of available @Calibrator objects
    calibratorTypes = {'MGL-based', 'PsychImaging-based (8-bit)' 'SACCPrimary'};
    calibratorsNum  = numel(calibratorTypes);
    
    % Ask the user to select a calibrator type
    fprintf('\n\n Available calibrator types:\n');
    for k = 1:calibratorsNum
        fprintf('\t[%3d]. %s\n', k, calibratorTypes{k});
    end
    defaultCalibratorIndex = 1;
    calibratorIndex = input(sprintf('\tSelect a calibrator type (1-%d) [%d]: ', calibratorsNum, defaultCalibratorIndex));
    if isempty(calibratorIndex) || (calibratorIndex < 1) || (calibratorIndex > calibratorsNum)
        calibratorIndex = defaultCalibratorIndex;
    end
    fprintf('\n\t-------------------------\n');
    selectedCalibratorType = calibratorTypes{calibratorIndex};
    fprintf('Will employ an %s calibrator object [%d].\n', selectedCalibratorType, calibratorIndex);
    
    calibratorOBJ = [];

    try
        % Instantiate an Calibrator object with the required configration variables.
        if strcmp(selectedCalibratorType, 'MGL-based')
            calibratorOBJ = MGLcalibrator(calibratorInitParams);
            
        elseif strcmp(selectedCalibratorType, 'PsychImaging-based (8-bit)')
            calibratorOBJ = PsychImagingCalibrator(calibratorInitParams);

        elseif strcmp(selectedCalibratorType, 'SACCPrimary')
            calibratorOBJ = SACCPrimaryCalibrator(calibratorInitParams);
        end
        
    catch err
        % Shutdown the radiometer
        radiometerOBJ.shutDown();
        % Shutdown DBLab_Radiometer object  
        if (~isempty(calibratorOBJ))
            % Shutdown calibratorOBJ
            calibratorOBJ.shutDown();
        end
        
        rethrow(err)
   end % end try/catch
end