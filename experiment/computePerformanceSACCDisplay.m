function [correct] = computePerformanceSACCDisplay(nullRGBImage,testRGBImage,...
    theSceneTemporalSupportSeconds,testContrast,window,windowRect,options)
% Run one trial of a psychophysical experiment.
%
% Syntax:
%    [correct] = computePerformanceSACCDisplay(nullRGBImage,testRGBIimage,...
%    theSceneTemporalSupportSeconds,displayControlStruct)
%
% Description:
%     Run one trial of a psychophysical experiment and return correct or
%     incorrect.  The trial is TAFC.  The two stimuli are nullRGBImage and
%     testRGBImage.  Subject is correct if he/she chooses testRGBImage.
%
%     It can be executed both with and without using PTB. In the
%     experiment, we will use the PTB version, but we can also run this by
%     displaying the images on the figure if the option 'simulation' set to
%     true.
%
% Inputs:
%     nullRGBImage                   - Null RGB image as a reference for
%                                      evaluation, which means no contrast
%                                      image in SACC project.
%     testRGBImage                   - Test RGB image to be compared with
%                                      the null image.
%     theSceneTemporalSupportSeconds - Temporal support vector (in
%                                      seconds) for scene sequences.
%     testContrast                   - Contrast value of the input image.
%                                      This is only used when getting an
%                                      automatic response based on the
%                                      probability estimated from the
%                                      psychometric function with certain
%                                      parameters.
%
% Outputs:
%     correct                        - 1 if correct and 0 if incorrect.
%
% Optional key/value pairs:
%     runningMode                    - If you are not acutally running
%                                      the experiment, set this to true and
%                                      null and test images will be showed
%                                      on the figure instead of displaying
%                                      it on PTB.
%    expKeyType                      - Default to 'keyboard'. Set either
%                                      'keyboard' or 'gamepad' to get a
%                                      response when running the
%                                      experiment.
%    imageMagnificationFactor        - When simulation was set to true,
%                                      this decides the size of the null
%                                      and test images. If it is set to 1,
%                                      it displays the original image size.
%    beepSound                       - If it is set to true, make a beep
%                                      sound every when an image is
%                                      displaying as an audible cue for
%                                      patients.
%    autoResponse                    - If it is set to true, make an
%                                      automatic response based on the
%                                      probability
%    verbose                         - Boolean. Default true. Controls
%                                      printout.
%
% See also
%   t_thresholdEngine, t_spatialCsf, computeThresholdTAFC,
%   SACC_runExperiment

% History:
%   10/23/20  dhb                   - Comments.
%   02/02/22  smo                   - Modified it to use in SACC project.
%   02/04/22  smo                   - Removed the input variable
%                                     displayControlStruct which is not
%                                     needed in this version. We can bring
%                                     it back if we want to.
%   02/07/22  smo                   - Added an option getting automatic
%                                     response. Also, made it shorter and
%                                     clearer in overall.

%% Set parameters.
arguments
    nullRGBImage
    testRGBImage
    theSceneTemporalSupportSeconds
    testContrast
    window (1,1)
    windowRect (1,4)
    options.runningMode = 'simulation'
    options.expKeyType = 'keyboard'
    options.imageMagnificationFactor (1,1) = 1.3
    options.beepSound (1,1) = false
    options.autoResponse (1,1) = true
    options.verbose (1,1) = true
end

%% Displaying the images.
switch (options.runningMode)
    case 'PTB'
        % This part will be used for the actual experiment displaying the test
        % image on the projector using PTB.
        %
        % Randomize the displaying order of null and test images.
        displayFirstTest = 1;
        displayFirstNull = 2;
        displayOrders = [displayFirstTest displayFirstNull];
        whichOneToStart = randi(displayOrders);
        
        allImages = {testRGBImage nullRGBImage};
        firstDisplayImage  = allImages{whichOneToStart};
        secondDisplayImage = allImages{setdiff(displayOrders,whichOneToStart)};
        
        % Display the images here.
        %
        % Cross-fixation image before displaying the images. This is useful
        % when audible cue is not working.
         DisplayScreenPattern(window,windowRect,'patternType','crossbar',...
            'patternColor',[1 1 1],'verbose',false);
        % Make a time delay.
        for dd = 1:theSceneTemporalSupportSeconds;
            pause(1);
        end
        
        % First image.
        SetScreenImage(firstDisplayImage, window, windowRect,'verbose',options.verbose);
        % Make a beep sound as an audible cue.
        if (options.beepSound)
            MakeBeepSound;
        end
        % Make a time delay.
        for dd = 1:theSceneTemporalSupportSeconds;
            pause(1);
        end
        
        % Cross-fixation image again.
        DisplayScreenPattern(window,windowRect,'patternType','crossbar',...
            'patternColor',[1 1 1],'verbose',false);
        % Make a time delay.
        for dd = 1:theSceneTemporalSupportSeconds;
            pause(1);
        end
        
        % Second image.
        SetScreenImage(secondDisplayImage, window, windowRect,'verbose',options.verbose);
        % Make a beep sound as an audible cue.
        if (options.beepSound)
            MakeBeepSound;
        end
        % Make a time delay.
        for dd = 1:theSceneTemporalSupportSeconds;
            pause(1);
        end
        
    case 'simulation'
        % This part does not use PTB and just diplay test images side-by-side on
        % the figure and record key stroke responses, which would be helpful to
        % check the sequence of the experiment before running it with the patients.
        % Resize the image as desired here.
        nullRGBImageResize = imresize(nullRGBImage,options.imageMagnificationFactor);
        testRGBImageResize = imresize(testRGBImage,options.imageMagnificationFactor);
        imageSize = size(nullRGBImageResize);
        imageXPixel = imageSize(1);
        imageYPixel = imageSize(2);
        
        % Get the display info here.
        screenSize = get(0,'screensize');
        screenXPixel = screenSize(3);
        screenYPixel = screenSize(4);
        
        % Randomize the location of the images.
        imageSideLeft  = 1;
        imageSideRight = 2;
        imageSides = [imageSideLeft imageSideRight];
        whichSideNullImage = randi([imageSideLeft imageSideRight]);
        whichSideTestImage = setdiff(imageSides,whichSideNullImage);
        
        % Display images here.
        figure; clf;
        
        % Set the position and the size of the images.
        %
        % Note that the (x,y) = (0,0) is the left and bottom end of the screen.
        % We will display the images on the full screen anyways.
        x = 0;
        y = 0;
        width = screenXPixel;
        height = screenYPixel;
        set(figure, 'Position', [x y width height])
        
        % Display null image.
        subplot(1,2,whichSideNullImage); imshow(nullRGBImageResize);
        % Display test image.
        subplot(1,2,whichSideTestImage); imshow(testRGBImageResize);
        
        % Make a beep sound as an audible cue.
        if (options.beepSound)
            MakeBeepSound;
        end
end

%% Getting a key response.
if (options.verbose)
    fprintf('Waiting for a key is pressed... \n');
end

% Key press response is saved in a single number based on the ASCII
% allocated number for the keyboards.
% [28 = leftarrow / 29 = rightarrow].
%
% Maybe we want to change this key to press for the case using the PTB
% because it is not very intuitive. Or we can switch to use the
% joy-stick to evaluate.
leftArrow  = 28;
rightArrow = 29;

% Make a loop till patients press either left of right arrow key.
if (~options.autoResponse)
    switch (options.expKeyType)
        % Get a response using a keyboard.
        case 'keyboard'
            metCondition = false;
            nLoopTrial = 1;
            while (nLoopTrial >= 1)
                gettingResponse = waitforbuttonpress;
                response = double(get(gcf,'CurrentCharacter'));
                if (response == leftArrow || response == rightArrow)
                    metCondition = true;
                    break
                else
                    metCondition = false;
                    nLoopTrial = nLoopTrial + 1;
                end
            end
            
            % Get a response using a gamepad.
        case 'gamepad'
            gamepadRespFirst  = 1;
            gamepadRespSecond = 2;
            responseGamePad = GetGamepadResp2AFC('verbose',options.verbose);
            if (responseGamePad == gamepadRespFirst)
                response = leftArrow;
            elseif (responseGamePad == gamepadRespSecond)
                response = rightArrow;
            end
    end
    if (options.verbose)
        fprintf('     Key input has been received! \n');
    end
    % Convert the key response into a single number either 0 or 1.
    correctResponse   = 1;
    incorrectResponse = 0;
    
    % Match the variable names prior to response conversion.
    if (strcmp(options.runningMode,'PTB'))
        whichSideTestImage = whichOneToStart;
        imageSideLeft = displayFirstTest;
        imageSideRight = displayFirstNull;
    end
    
    % Convert the numbers here.
    switch whichSideTestImage
        % When test image was shown on the left side (simulation) or first order (PTB).
        case (imageSideLeft)
            response(response == rightArrow) = incorrectResponse;
            response(response == leftArrow)  = correctResponse;
            % When test image was shown on the right side (simulation) or second order (PTB).
        case (imageSideRight)
            response(response == rightArrow) = correctResponse;
            response(response == leftArrow)  = incorrectResponse;
        otherwise
            error('Check if your images are placed in right positions!');
    end
    
    % Check if the response value is either 0 or 1.
    if (~any(response == [correctResponse, incorrectResponse]))
        error('Response value should be either 0 or 1!');
    end
    
elseif (options.autoResponse)
    % Getting an auto response based on the test contrast level. This part
    % needs to be modified to reflect the psychometric function params that
    % we will use for fitting the data.
    nTrials = 1;
    a = 0.01;
    b = 1.5;
    pCorrect = wblcdf(testContrast,a,b);
    response = binornd(nTrials,pCorrect);
end

%% Close.
switch (options.runningMode)
    case 'PTB'
    case 'simulation'
        close all;
end
if (options.verbose)
    fprintf('Key input has been received! \n');
end

% Print out the results.
correct = response;

end
