% ContrastOverTrombonePositionData
%
% This is the measurement of contrast over the Tromobone position by
% controlling it by its own software. 

% History:
%    03/25/22  dhb, smo     - Measured the data and plotted the graph.

%% Measurement data.
%
% Position is in mm unit in the Trombone controlling software, and the
% contrast was measured based on the real-time camera image.
positionTrombone = [2.799 2.299 1.772 1.522 1.272 1.022 0.772 0.522 0.272 0.022 -0.530 -1.449 -2.193 -2.665 ];
contrast         = [0.931 0.946 0.954 0.954 0.954 0.954 0.955 0.954 0.954 0.954  0.954  0.954  0.947  0.939 ];

contrastMax = max(contrast);
positionContrastMax = positionTrombone(find(contrast(:) == contrastMax));

%% Plot it.
figure; clf; hold on;
plot(positionTrombone, contrast, 'ko--', 'MarkerFaceColor', [0.5 0.5 0.5], 'MarkerEdgeColor', zeros(1,3), 'MarkerSize', 7);
plot(positionContrastMax, contrastMax, 'o', 'MarkerFaceColor', [1 0 0], 'MarkerEdgeColor', zeros(1,3), 'MarkerSize', 7);
xlabel('Position Trombone (mm)','FontSize',13);
ylabel('Contrast','FontSize',13);
legend('Data','Max Contrast','location','southwest');