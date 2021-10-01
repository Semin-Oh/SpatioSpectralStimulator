% SpectralTestCal
%
% Start exploring spectral fits with swubprimarys, this
% version using the calibration structures.
%
% 4/22/2020  Started on it

%% Clear
clear; close all;

%% Define calibration filenames/params
%
% This is a standard calibration file for the DLP projector,
% with the subprimaries set to something.  As we'll see below,
% we're going to rewrite those.
projectorCalName = 'SACC';
projectorNInputLevels = 256;

% These are the calibration files for each of the primaries, which
% then entails measuring the spectra of all the subprimaries for that
% primary.
subprimaryCalNames = {'SACCPrimary1' 'SACCPrimary1' 'SACCPrimary1'};
subprimaryNInputLevels = 252;

%% Load projector calibration
projectorCal = LoadCalFile(projectorCalName);
projectorCalObj = ObjectToHandleCalOrCalStruct(projectorCal);
CalibrateFitGamma(projectorCalObj, projectorNInputLevels);

%% Load subprimary calibrations
subprimaryCals = cell(3,1);
subprimaryCalObjs = cell(3,1);
for cc = 1:length(subprimaryCalNames)
    subprimaryCals{cc} = LoadCalFile(subprimaryCalNames{cc});

    subprimaryCalObjs{cc} = ObjectToHandleCalOrCalStruct(subprimaryCals{cc});
    CalibrateFitGamma(subprimaryCalObjs{cc}, subprimaryNInputLevels);
end

%% Get out some data to work with.
%
% This is from the subprimary calibration file.
S = subprimaryCalObjs{1}.get('S');
wls = SToWls(S);
ambientSpd = subprimaryCalObjs{1}.get('P_ambient');
if (isempty(ambientSpd))
    subprimaryCalObjs{1}.P_ambient = zeros(size(wls));
end
P_device = subprimaryCalObjs{1}.get('P_device');
gammaInput = subprimaryCalObjs{1}.get('gammaInput');
gammaTable = subprimaryCalObjs{1}.get('gammaTable');
gammaMeasurements = subprimaryCals{1}.rawData.gammaCurveMeanMeasurements;
[nSubprimaries,nMeas,~] = size(gammaMeasurements);

%% Cone fundamentals and XYZ CMFs
psiParamsStruct.coneParams = DefaultConeParams('cie_asano');
T_cones = ComputeObserverFundamentals(psiParamsStruct.coneParams,S);
load T_xyzJuddVos % Judd-Vos XYZ Color matching function
T_xyz = SplineCmf(S_xyzJuddVos,683*T_xyzJuddVos,S);

%% Let's look at little at the subprimary calibration.
%
% Eventually this will be handled by the analyze program,
% when it is generalized for more than three primaries.  But
% we are impatient people so we will hack something up here.
PLOT_SUBPRIMARYINVARIANCE = false;
if (PLOT_SUBPRIMARYINVARIANCE)
    for pp = 1:nSubprimaries
        maxSpd = squeeze(gammaMeasurements(pp,end,:));
        figure;
        subplot(1,2,1); hold on;
        plot(wls,maxSpd,'r','LineWidth',3);
        for mm = 1:nMeas-1
            temp = squeeze(gammaMeasurements(pp,mm,:));
            plot(wls,temp,'k','LineWidth',1);
        end
        subplot(1,2,2); hold on
        plot(wls,maxSpd,'r','LineWidth',3);
        for mm = 1:nMeas-1
            temp = squeeze(gammaMeasurements(pp,mm,:));
            scaleFactor = temp\maxSpd;
            plot(wls,scaleFactor*temp,'k','LineWidth',1);
        end
    end
end

%% Plot subprimary gamma functions
PLOT_SUBPRIMARYGAMMA = false;
if (PLOT_SUBPRIMARYGAMMA)
    for pp = 1:nSubprimaries
        figure; hold on;
        plot(subprimaryCals{1}.rawData.gammaInput,subprimaryCals{1}.rawData.gammaTable(:,pp),'ko','MarkerSize',12,'MarkerFaceColor','k');
        plot(gammaInput,gammaTable(:,pp),'k','LineWidth',2);
    end 
end

%% Plot x,y if desired
PLOT_SUBPRIMARYCHROMATICITY = false;
if (PLOT_SUBPRIMARYCHROMATICITY)
    figure; hold on;
    for pp = 1:nSubprimaries
        for mm = 1:nMeas
            % XYZ calculation for each measurement
            spd_temp = squeeze(gammaMeasurements(pp,mm,:));      
            XYZ_temp = T_xyz*spd_temp; 
            xyY_temp = XYZToxyY(XYZ_temp);
            
            plot(xyY_temp(1,:),xyY_temp(2,:),'r.','Markersize',10); % Coordinates of the subprimary
            xlabel('CIE x');
            ylabel('CIE y');
        end
    end
    
    % Add spectrum locus to plot, connected end to end
    colorgamut=XYZToxyY(T_xyz); 
    colorgamut(:,end+1)=colorgamut(:,1);
    plot(colorgamut(1,:),colorgamut(2,:),'k-'); 
end

%% Background xy
%
% Specify the chromaticity, but we'll chose the luminance based
% on the range available in the device.
targetBgxy = [0.3127 0.3290]';

%% Target color direction and max contrasts.
%
% This is the basic desired modulation direction positive excursion. We go
% equally in positive and negative directions.
targetLMSContrast = [1 -1 0]';

%% Specify desired primary properties
%
% These are the target contrasts for the three primaries. We want these to
% span a triangle around the line specified above. Here we define that
% triangle by hand.  May need a little fussing for other directions, and
% might be able to autocompute good choices.
target1MaxLMSContrast = [-1 1 0]';
target2MaxLMSContrast = [1 -1 0.5]';
target3MaxLMSContrast = [1 -1 -0.5]';

% We may not need the whole direction excursion above. The first number is
% the amount we want to use, the second has a little headroom so we don't
% run into numerical error at the edges. The second number is used when
% defining the three primaries, the first when computing desired weights on
% the primaries.
targetContrastReMax = 0.05;
targetPrimaryHeadroom = 1.1;
targetContrastReMaxWithHeadroom = targetPrimaryHeadroom*targetContrastReMax;
plotAxisLimit = 2;

%% Comment this better later on
%
% When we compute a specific image, we may not want full contrast available
% with the primaries. This tells us fraction of max available relative to
% ledContrastReMax.
imageModulationContrast = 0.05/targetContrastReMax;

%% Image spatial parameters
sineFreqCyclesPerImage = 6;
gaborSdImageFraction = 0.1;

% Image size in pixels
imageN = 512;

%% Computational bit depth 
%
% This is a computational bit depth that we use to define the lookup table
% between contrast and primary values.
fineBits = 14;
nFineLevels = 2^fineBits;

%% Get half on spectrum
%
% This is useful for scaling things reasonably - we start with half of the
% available range of the primaries.
halfOnSubprimaries = 0.5*ones(nSubprimaries,1);
halfOnSpd = PrimaryToSpd(subprimaryCalObjs{1},halfOnSubprimaries);

%% Make sure gamma correction behaves well with unquantized conversion
SetGammaMethod(subprimaryCalObjs{1},0);
halfOnSettings = PrimaryToSettings(subprimaryCalObjs{1},halfOnSubprimaries);
halfOnPrimariesChk = SettingsToPrimary(subprimaryCalObjs{1},halfOnSettings);
if (max(abs(halfOnSubprimaries-halfOnPrimariesChk)) > 1e-8)
    error('Gamma self-inversion not sufficiently precise');
end

%% Use quantized conversion from here on
%
% Comment in the line that refits the gamma to see
% effects of extreme quantization below
%
% CalibrateFitGamma(subprimaryCalObjs{1},10);
SetGammaMethod(subprimaryCalObjs{1},2);
SetGammaMethod(subprimaryCalObjs{2},2);
SetGammaMethod(subprimaryCalObjs{3},2);

%% Use extant machinery to get primaries from spectrum
%
% This isn't used in our calculations.  Any difference in the
% two lines here reflects a bug in the SpdToPrimary/PrimaryToSpd pair.  
halfOnPrimariesChk = SpdToPrimary(subprimaryCalObjs{1},halfOnSpd);
halfOnSpdChk = PrimaryToSpd(subprimaryCalObjs{1},halfOnPrimariesChk);
figure; hold on;
plot(wls,halfOnSpd,'r','LineWidth',3);
plot(wls,halfOnSpdChk,'k','LineWidth',1);

%% Show effect of quantization
%
% It's very small at the nominal 252 levels of the subprimaries, but will
% increase if you refit the gamma functios to a small number of levels.
halfOnPrimariesChk = SpdToPrimary(subprimaryCalObjs{1},halfOnSpd);
halfOnSettingsChk = PrimaryToSettings(subprimaryCalObjs{1},halfOnPrimariesChk);
halfOnPrimariesChk1 = SettingsToPrimary(subprimaryCalObjs{1},halfOnSettingsChk);
halfOnSpdChk1 = PrimaryToSpd(subprimaryCalObjs{1},halfOnPrimariesChk1);
plot(wls,halfOnSpdChk1,'g','LineWidth',1);

%% Set up basis to try to keep spectra close to
%
% This is how we enforce a smoothness or other constraint
% on the spectra.
basisType = 'fourier';
nFourierBases = 7;
switch (basisType)
    case 'cieday'
        load B_cieday
        B_natural = SplineSpd(S_cieday,B_cieday,S);
    case 'fourier'
        B_natural = MakeFourierBasis(S,nFourierBases);
    otherwise
        error('Unknown basis set specified');
end

% Define wavelength range that will be used to enforce the smoothnes
% thorugh the projection onto an underlying basis set.  We don't the whole
% visible spectrum as putting weights on the extrema where people are not
% sensitive costs us smoothness in the spectral region we care most about.
lowProjectWl = 400;
highProjectWl = 700;
projectIndices = find(wls > lowProjectWl & wls < highProjectWl);

%% Find background primaries to acheive desired xy at intensity scale of display
primaryHeadRoom = 0;
targetLambda = 3;
targetBgXYZ = xyYToXYZ([targetBgxy ; 1]);
[bgPrimaries,obtainedBgSpd,obtainedBgXYZ] = FindDesiredBackgroundPrimaries(targetBgXYZ,T_xyz,subprimaryCalObjs{1}, ...
    B_natural,projectIndices,primaryHeadRoom,targetLambda,'Scale',true,'Verbose',true);
if (any(bgPrimaries < 0) | any(bgPrimaries > 1))
    error('Oops - primaries should always be between 0 and 1');
end

%% SEMIN - Let's make this a function that takes in the desired 
% primary contrasts, calibration objects etc. and produces the three
% desired primaries.  As Geoff notes, can probably write a loop over
% the three primaries as well as part of this.

%% Get primaries based on contrast specification
target1LMSContrast = targetContrastReMaxWithHeadroom*target1MaxLMSContrast;
targetLambda = 3;
[isolatingModulationPrimaries1] = ReceptorIsolateSpectral(T_cones,target1LMSContrast,subprimaryCalObjs{1}.get('P_device'),bgPrimaries,bgPrimaries, ...
    primaryHeadRoom,B_natural,projectIndices,targetLambda,subprimaryCalObjs{2}.get('P_ambient'),'EXCITATIONS',false);
isolatingPrimaries1 = isolatingModulationPrimaries1 + bgPrimaries;

% Quantize
isolatingPrimaries1 = SettingsToPrimary(subprimaryCalObjs{1},PrimaryToSettings(subprimaryCalObjs{1},isolatingPrimaries1));

% Report
isolatingSpd1 = PrimaryToSpd(subprimaryCalObjs{1},isolatingPrimaries1);
isolatingLMS1 = T_cones*isolatingSpd1;
isolatingContrast1 = ExcitationsToContrast(isolatingLMS1,bgLMS);
fprintf('Desired/obtained contrasts 1\n');
for rr = 1:length(target1LMSContrast)
    fprintf('\tReceptor %d (desired/obtained): %0.3f, %0.3f\n',rr,target1LMSContrast(rr),isolatingContrast1(rr));
end
fprintf('Min/max primaries 1: %0.4f, %0.4f\n', ...
    min(isolatingPrimaries1), max(isolatingPrimaries1));

% Primary 2
target2LMSContrast = targetContrastReMaxWithHeadroom*target2MaxLMSContrast;
targetLambda = 3;
[isolatingModulationPrimaries2] = ReceptorIsolateSpectral(T_cones,target2LMSContrast,subprimaryCalObjs{2}.get('P_device'),bgPrimaries,bgPrimaries, ...
    primaryHeadRoom,B_natural,projectIndices,targetLambda,subprimaryCalObjs{2}.get('P_ambient'),'EXCITATIONS',false);
isolatingPrimaries2 = isolatingModulationPrimaries2 + bgPrimaries;

% Quantize
isolatingPrimaries2 = SettingsToPrimary(subprimaryCalObjs{2},PrimaryToSettings(subprimaryCalObjs{2},isolatingPrimaries2));

% Report
isolatingSpd2 = PrimaryToSpd(subprimaryCalObjs{2},isolatingPrimaries2);
isolatingLMS2 = T_cones*isolatingSpd2;
isolatingContrast2 = ExcitationsToContrast(isolatingLMS2,bgLMS);
fprintf('Desired/obtained contrasts 2\n');
for rr = 1:length(target2LMSContrast)
    fprintf('\tReceptor %d (desired/obtained): %0.3f, %0.3f\n',rr,target2LMSContrast(rr),isolatingContrast2(rr));
end
fprintf('Min/max primaries 2: %0.4f, %0.4f\n', ...
    min(isolatingPrimaries2), max(isolatingPrimaries2));

% Primary 3
target3LMSContrast = targetContrastReMaxWithHeadroom*target3MaxLMSContrast;
targetLambda = 3;
[isolatingModulationPrimaries3] = ReceptorIsolateSpectral(T_cones,target3LMSContrast,subprimaryCalObjs{3}.get('P_device'),bgPrimaries,bgPrimaries, ...
    primaryHeadRoom,B_natural,projectIndices,targetLambda,subprimaryCalObjs{3}.get('P_ambient'),'EXCITATIONS',false);
isolatingPrimaries3 = isolatingModulationPrimaries3 + bgPrimaries;

% Quantize
isolatingPrimaries3 = SettingsToPrimary(subprimaryCalObjs{3},PrimaryToSettings(subprimaryCalObjs{3},isolatingPrimaries3));

% Report
isolatingSpd3 = PrimaryToSpd(subprimaryCalObjs{3},isolatingPrimaries3);
isolatingLMS3 = T_cones*isolatingSpd3;
isolatingContrast3 = ExcitationsToContrast(isolatingLMS3,bgLMS);
fprintf('Desired/obtained contrasts 3\n');
for rr = 1:length(target3LMSContrast)
    fprintf('\tReceptor %d (desired/obtained): %0.3f, %0.3f\n',rr,target3LMSContrast(rr),isolatingContrast3(rr));
end
fprintf('Min/max primaries 3: %0.4f, %0.4f\n', ...
    min(isolatingPrimaries3), max(isolatingPrimaries3));
%% *************************

%% How close are spectra to subspace defined by basis?
theBgNaturalApproxSpd = B_natural*(B_natural(projectIndices,:)\bgSpd(projectIndices));
isolatingNaturalApproxSpd1 = B_natural*(B_natural(projectIndices,:)\isolatingSpd1(projectIndices));
isolatingNaturalApproxSpd2 = B_natural*(B_natural(projectIndices,:)\isolatingSpd2(projectIndices));
isolatingNaturalApproxSpd3 = B_natural*(B_natural(projectIndices,:)\isolatingSpd3(projectIndices));

% Plot
figure; clf;
subplot(2,2,1); hold on
plot(wls,bgSpd,'b','LineWidth',2);
plot(wls,theBgNaturalApproxSpd,'r:','LineWidth',1);
plot(wls(projectIndices),bgSpd(projectIndices),'b','LineWidth',4);
plot(wls(projectIndices),theBgNaturalApproxSpd(projectIndices),'r:','LineWidth',3);
xlabel('Wavelength (nm)'); ylabel('Power (arb units)');
title('Background');
%ylim([0 2]);
subplot(2,2,2); hold on
plot(wls,bgSpd,'b:','LineWidth',1);
plot(wls,isolatingSpd1,'b','LineWidth',2);
plot(wls,isolatingNaturalApproxSpd1,'r:','LineWidth',1);
plot(wls(projectIndices),isolatingSpd1(projectIndices),'b','LineWidth',4);
plot(wls(projectIndices),isolatingNaturalApproxSpd1(projectIndices),'r:','LineWidth',3);
xlabel('Wavelength (nm)'); ylabel('Power (arb units)');
title('Primary 1');
%ylim([0 2]);
subplot(2,2,3); hold on
plot(wls,bgSpd,'b:','LineWidth',1);
plot(wls,isolatingSpd2,'b','LineWidth',2);
plot(wls,isolatingNaturalApproxSpd2,'r:','LineWidth',1);
plot(wls(projectIndices),isolatingSpd2(projectIndices),'b','LineWidth',4);
plot(wls(projectIndices),isolatingNaturalApproxSpd2(projectIndices),'r:','LineWidth',3);
xlabel('Wavelength (nm)'); ylabel('Power (arb units)');
title('Primary 2');
%ylim([0 2]);
subplot(2,2,4); hold on
plot(wls,bgSpd,'b:','LineWidth',1);
plot(wls,isolatingSpd3,'b','LineWidth',2);
plot(wls,isolatingNaturalApproxSpd3,'r:','LineWidth',1);
plot(wls(projectIndices),isolatingSpd3(projectIndices),'b','LineWidth',4);
plot(wls(projectIndices),isolatingNaturalApproxSpd3(projectIndices),'r:','LineWidth',3);
xlabel('Wavelength (nm)'); ylabel('Power (arb units)');
title('Primary 3');
%ylim([0 2]);

%% This is where we would measure the primaries we actually get and then use
%% the measured rather than the nominal primaries to compute the image.

%% Create lookup table that maps [-1,1] to desired LMS contrast at a very fine scale
%
% Also find and save best mixture of quantized primaries to acheive each fine
% % contrast level.
%
% DAVID - Convert this to use SensorToSettings() etc, rather than having
% written it out de novo the way it is here.
fprintf('Making fine contrast to LMS lookup table\n');
fineContrastLevels = linspace(-1,1,nFineLevels);
spdMatrix = [isolatingSpd1, isolatingSpd2, isolatingSpd3];
LMSMatrix = T_cones*spdMatrix;
for ll = 1:nFineLevels
    % Find the LMS values corresponding to desired contrast
    fineDesiredContrast(:,ll) = fineContrastLevels(ll)*targetContrastReMax*targetLMSContrast;
    fineDesiredLMS(:,ll) = ContrastToExcitation(fineDesiredContrast(:,ll),bgLMS);
    
    % Find primary mixture to best prodcue those values
    thisMixture = LMSMatrix\fineDesiredLMS(:,ll);
    thisMixture(thisMixture > 1) = 1;
    thisMixture(thisMixture < 0) = 0;
    
    % Store
    finePrimaries(:,ll) = thisMixture;
    finePredictedLMS(:,ll) = T_cones*spdMatrix*thisMixture;
end

% Do this at quantized levels
fprintf('Making display quantized primary lookup table\n');
quantizedIntegerLevels = 1:projectorNInputLevels;
quantizedContrastLevels = (2*(quantizedIntegerLevels-1)/(projectorNInputLevels-1))-1;
quantizedLMSContrast = zeros(3,projectorNInputLevels);
quantizedLMS = zeros(3,projectorNInputLevels);
minIndices = zeros(1,projectorNInputLevels);
predictedQuantizedLMS = zeros(3,projectorNInputLevels);
quantizedDisplayPrimaries = zeros(3,projectorNInputLevels);

% Set up point cloud for fast finding of nearest neighbors
finePtCloud = pointCloud(finePredictedLMS');
for ll = 1:projectorNInputLevels
    quantizedLMSContrast(:,ll) = quantizedContrastLevels(ll)*targetContrastReMax*targetLMSContrast;
    quantizedLMS(:,ll) = ContrastToExcitation(quantizedLMSContrast(:,ll),bgLMS);
    
    minIndices(ll) = findNearestNeighbors(finePtCloud,quantizedLMS(:,ll)',1);
    predictedQuantizedLMS(:,ll) = finePredictedLMS(:,minIndices(ll));
    quantizedDisplayPrimaries(:,ll) = finePrimaries(:,minIndices(ll));
end

%% Make Gabor patch in range 0-1
%
% This is our contrast modulation
fprintf('Making Gabor contrast image\n');
centerN = imageN/2;
gaborSdPixels = gaborSdImageFraction*imageN;
rawMonochromeSineImage = MakeSineImage(0,sineFreqCyclesPerImage,imageN);
gaussianWindow = normpdf(MakeRadiusMat(imageN,imageN,centerN,centerN),0,gaborSdPixels);
gaussianWindow = gaussianWindow/max(gaussianWindow(:));
rawMonochromeGaborImage = imageModulationContrast*rawMonochromeSineImage.*gaussianWindow;

% Quantized for display bit depth
displayIntegerMonochromeGaborImage = PrimariesToIntegerPrimaries((rawMonochromeGaborImage+1)/2,projectorNInputLevels);
displayIntegerMonochromeGaborCal = ImageToCalFormat(displayIntegerMonochromeGaborImage);

% Quantized for fine bit depth
fineIntegerMonochromeGaborImage = PrimariesToIntegerPrimaries((rawMonochromeGaborImage+1)/2,nFineLevels);
fineIntegerMonochromeGaborCal = ImageToCalFormat(fineIntegerMonochromeGaborImage);

%% Create the Gabor image with desired LMS contrasts
fprintf('Making Gabor desired (fine) LMS contrast image\n');
quantizedFineLMSGaborCal = zeros(3,imageN*imageN);
for ii = 1:imageN*imageN
    thisIndex = fineIntegerMonochromeGaborImage(ii);
    fineLMSContrastCal(:,ii) = fineDesiredContrast(:,thisIndex);
    quantizedFineLMSGaborCal(:,ii) = finePredictedLMS(:,thisIndex);
end
fineLMSContrastGaborImage = CalFormatToImage(fineLMSContrastCal,imageN,imageN);
meanLMS = mean(quantizedFineLMSGaborCal,2);
quantizedFineContrastGaborCal = ExcitationsToContrast(quantizedFineLMSGaborCal,meanLMS);
quantizedFineContrastGaborImage = CalFormatToImage(quantizedFineContrastGaborCal,imageN,imageN);

%% Create the Gabor image with quantized primary mixtures
fprintf('Making Gabor primary mixture image\n');
quantizedDisplayPrimariesGaborCal = zeros(3,imageN*imageN);
for ii = 1:imageN*imageN
    thisIndex = displayIntegerMonochromeGaborCal(ii);
    quantizedDisplayPrimariesGaborCal(:,ii) = quantizedDisplayPrimaries(:,thisIndex);
end

%% Convert of useful formats for analysis, rendering
%
% Get spectral power distribution
fprintf('Convert Gabor for rendering, analysis\n');
quantizedSpdCal = spdMatrix*quantizedDisplayPrimariesGaborCal;

% Quantized LMS image and cone contrast image
quantizedLMSCal = T_cones*quantizedSpdCal;
meanLMS = mean(quantizedLMSCal,2);
quantizedContrastCal = ExcitationsToContrast(quantizedLMSCal,meanLMS);
quantizedContrastImage = CalFormatToImage(quantizedContrastCal,imageN,imageN);

% SRGB image via XYZ
quantizedXYZCal = T_xyz*quantizedSpdCal;
quantizedSRGBPrimaryCal = XYZToSRGBPrimary(quantizedXYZCal);
scaleFactor = max(quantizedSRGBPrimaryCal(:));
quantizedSRGBCal = SRGBGammaCorrect(quantizedSRGBPrimaryCal/(2*scaleFactor),0);
quantizedSRGBImage = uint8(CalFormatToImage(quantizedSRGBCal,imageN,imageN));

% Show the SRGB image
figure; imshow(quantizedSRGBImage)

%% Now compute projector image
%
% First step is to make a DLP calibration file that has as primaries
% the three spds we've computed above.
%
% In an actual display program, we would set each of the primary's
% subprimaries to isolatingPrimaries1, isolatingPrimaries2,
% isolatingPrimaries3 as computed above.  That now allows the DLP
% to produce mixtures of these primaries.  Here we tell the calibration
% object for the DLP that it has these desired primaries.
P_device = [isolatingSpd1 isolatingSpd2 isolatingSpd3];
projectorCal.processedData.P_device = P_device;

% Initialze the calibration structure
projectorCal = SetSensorColorSpace(projectorCal,T_cones,S);
projectorCal = SetGammaMethod(projectorCal,2);

% Convert excitations image to projector settings
[projectorSettingsCal,outOfGamutIndex] = SensorToSettings(projectorCal,quantizedFineLMSGaborCal);
if (any(outOfGamutIndex))
    error('Oops: Some pixels out of gamut');
end
projectorSettingsImage = CalFormatToImage(projectorSettingsCal,imageN,imageN);
figure; clf;
imshow(projectorSettingsImage)

% Show this image on the DLP, and it should look more or less like
% the sRGB image we display below.
testFiledir = getpref('SpatioSpectralStimulator','TestDataFolder');
testFilename = fullfile(testFiledir,'testImageData1');
save(testFilename,'projectorSettingsImage','isolatingPrimaries1','isolatingPrimaries2','isolatingPrimaries3');

%% Plot slice through LMS contrast image
figure; hold on
plot(1:imageN,100*quantizedContrastImage(centerN,:,1),'r+','MarkerFaceColor','r','MarkerSize',4);
plot(1:imageN,100*fineLMSContrastGaborImage(centerN,:,1),'r','LineWidth',0.5);
%plot(1:imageN,100*quantizedFineContrastGaborImage(centerN,:,1),'r','LineWidth',0.5);

plot(1:imageN,100*quantizedContrastImage(centerN,:,2),'g+','MarkerFaceColor','g','MarkerSize',4);
plot(1:imageN,100*fineLMSContrastGaborImage(centerN,:,2),'g','LineWidth',0.5);
%plot(1:imageN,100*quantizedFineContrastGaborImage(centerN,:,2),'g','LineWidth',0.5);

plot(1:imageN,100*quantizedContrastImage(centerN,:,3),'b+','MarkerFaceColor','b','MarkerSize',4);
plot(1:imageN,100*fineLMSContrastGaborImage(centerN,:,3),'b','LineWidth',0.5);
%plot(1:imageN,100*quantizedFineContrastGaborImage(centerN,:,3),'b','LineWidth',0.5);
title('Image Slice, LMS Cone Contrast');
xlabel('x position (pixels)')
ylabel('LMS Cone Contrast (%)');
ylim([-plotAxisLimit plotAxisLimit]);

%% DAVID - Add plot of primaries.

%% Light level tests
%
% PupilDiameter
pupilDiameterMM = 4;
theStimulusExtentDeg = 15;
theStimulusAreaDeg2 = theStimulusExtentDeg^2;

% Scale background to target cd/m2
%
% This makes units Watts/sr-m2-wlband
% Wavelength band is 2 here, which we need
% to keep track of.
targetLum = 1000;
theBGDeviceRawLum = T_xyz(2,:)*bgSpd;
theBgDeviceSpdScaled = targetLum*bgSpd/theBGDeviceRawLum;



