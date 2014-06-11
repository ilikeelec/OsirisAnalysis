
%
% Script to generate an animation of the evolution of the ElectronBeam
%

iStart = 12;
iEnd   = 116;

xMin   = 185;
xMax   = 189.2;

clear M;

for k=iStart:iEnd
    
    figMain = figure(1);
    clf;
    i = k-iStart+1;

    % Beam density lineout
    subplot(2,3,[1:2]);
    fPlotDensityEField(od, k, 5, 'PB', 'EB');
    axis([xMin, xMax, -1.05, 1.05]);
    
    % Electron Beam x1p1
    subplot(2,3,3);
    colormap(gray);
    fPlotPhase2D(od, k, 'EB', 'x1', 'p1');
    title('Electron Beam x1p1', 'FontSize', 14);
    axis([xMin, xMax, -20, 500]);
    caxis([0, 1e-5]);
    freezeColors;
    
    % ElectronBeam Density
    subplot(2,3,4);
    fPlotDensity(od, k, 'EB');
    title('Electron Beam Density', 'FontSize', 14);
    axis([xMin, xMax, -0.2, 0.2]);

    % ProtonBeam Density
    subplot(2,3,5);
    fPlotDensity(od, k, 'PB');
    title('Proton Beam Density', 'FontSize', 14);
    axis([xMin, xMax, -0.2, 0.2]);

    % E-Field
    subplot(2,3,6);
    fPlotField(od, k, 'e1');
    title('Ez-Field', 'FontSize', 14);
    axis([xMin, xMax, -0.7, 0.7]);
    
    M(i) = getframe(gcf);

end % for