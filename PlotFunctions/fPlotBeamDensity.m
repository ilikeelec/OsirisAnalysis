%
%  Function: fPlotBeamDensity
% ****************************
%  Plots density plot
%
%  Inputs:
% =========
%  oData   :: OsirisData object
%  sTime   :: Time dump
%  sBeam   :: Which beam to look at
%
%  Options:
% ==========
%  Limits      :: Axis limits
%  Charge      :: Calculate charge in ellipse two inputs for peak
%  FigureSize  :: Default [900 500]
%  IsSubplot   :: Default No
%  CAxis       :: Color axis limits
%  ShowOverlay :: Default Yes
%

function stReturn = fPlotBeamDensity(oData, sTime, sBeam, varargin)

    % Input/Output

    if nargin == 0
       fprintf('\n');
       fprintf('  Function: fPlotBeamDensity\n');
       fprintf(' ****************************\n');
       fprintf('  Plots density plot\n');
       fprintf('\n');
       fprintf('  Inputs:\n');
       fprintf(' =========\n');
       fprintf('  oData :: OsirisData object\n');
       fprintf('  sTime :: Time dump\n');
       fprintf('  sBeam :: Which beam to look at\n');
       fprintf('\n');
       fprintf('  Options:\n');
       fprintf(' ==========\n');
       fprintf('  Limits      :: Axis limits\n');
       fprintf('  Charge      :: Calculate charge in ellipse two inputs for peak\n');
       fprintf('  FigureSize  :: Default [900 500]\n');
       fprintf('  IsSubplot   :: Default No\n');
       fprintf('  CAxis       :: Color axis limits\n');
       fprintf('  ShowOverlay :: Default Yes\n');
       fprintf('\n');
       return;
    end % if
    
    stReturn = {};
    sBeam    = fTranslateSpecies(sBeam);
    iTime    = fStringToDump(oData, num2str(sTime));

    oOpt = inputParser;
    addParameter(oOpt, 'Limits',      []);
    addParameter(oOpt, 'Charge',      []);
    addParameter(oOpt, 'FigureSize',  [900 500]);
    addParameter(oOpt, 'IsSubPlot',   'No');
    addParameter(oOpt, 'CAxis',       []);
    addParameter(oOpt, 'ShowOverlay', 'Yes');
    parse(oOpt, varargin{:});
    stOpt = oOpt.Results;

    if ~isempty(stOpt.Limits) && length(stOpt.Limits) ~= 4
        fprintf(2, 'Error: Limits specified, but must be of dimension 4.\n');
        return;
    end % if

    if ~isempty(stOpt.Charge) && (length(stOpt.Charge) ~= 2 || length(stOpt.Charge) ~= 4)
        fprintf(2, 'Error: Charge specified, but must be of dimension 2 (follow peak) or 4.\n');
        return;
    end % if

    
    % Prepare Data

    CH        = Charge(oData, sBeam);
    CH.Time   = iTime;
    CH.Units  = 'SI';
    CH.ZScale = 'mm';
    CH.RScale = 'mm';

    if length(stOpt.Limits) == 4
        CH.ZLim = stOpt.Limits(1:2);
        CH.RLim = stOpt.Limits(3:4);
    end % if

    stData    = CH.Density;

    aData   = stData.Data;
    aZAxis  = stData.ZAxis;
    aRAxis  = stData.RAxis;
    dZPos   = stData.ZPos;
    
    aProjZ  = -abs(sum(aData));
    aProjZ  = 0.15*(aRAxis(end)-aRAxis(1))*aProjZ/max(abs(aProjZ))+aRAxis(end);

    if length(stOpt.Charge) == 2
        [~,iZPeak] = max(sum(abs(aData),1));
        [~,iRPeak] = max(sum(abs(aData),2));
        stQTot = CH.BeamCharge('Ellipse', [aZAxis(iZPeak), 0, stOpt.Charge(1), stOpt.Charge(2)]);
    elseif length(stOpt.Charge) == 4
        stQTot = CH.BeamCharge('Ellipse', [stOpt.Charge(1), stOpt.Charge(2), stOpt.Charge(3), stOpt.Charge(4)]);
    else
        stQTot = CH.BeamCharge;
    end % if
    dQ = stQTot.QTotal;
    
    if abs(dQ) < 1.0
        sBeamCharge = sprintf('Q_{tot} = %.2f pC', dQ*1e3);
    else
        sBeamCharge = sprintf('Q_{tot} = %.2f nC', dQ);
    end % if
    

    % Plot
    
    if strcmpi(stOpt.IsSubPlot, 'No')
        clf;
        fFigureSize(gcf, stOpt.FigureSize);
    else
        cla;
    end % if

    imagesc(aZAxis, aRAxis, aData);
    colormap('hot');
    colorbar();
    if ~isempty(stOpt.CAxis)
        caxis(stOpt.CAxis);
    end % if

    hold on;

    if strcmpi(stOpt.ShowOverlay, 'Yes')
        plot(aZAxis, aProjZ, 'White');
        h = legend(sBeamCharge, 'Location', 'NE');
        legend(h, 'boxoff');
        set(h,'TextColor', [1 1 1]);
        set(findobj(h, 'type', 'line'), 'visible', 'off')
    end % if

    if length(stOpt.Charge) == 2
        dRX = aZAxis(iZPeak)-stOpt.Charge(1);
        dRY = aRAxis(iRPeak)-stOpt.Charge(2);
        rectangle('Position',[dRX,dRY,2*stOpt.Charge(1),2*stOpt.Charge(2)],'Curvature',[1,1],'EdgeColor','White','LineStyle','--');
    elseif length(stOpt.Charge) == 4
        dRX = aCharge(1)-stOpt.Charge(3);
        dRY = aCharge(2)-stOpt.Charge(4);
        rectangle('Position',[dRX,dRY,2*stOpt.Charge(3),2*stOpt.Charge(4)],'Curvature',[1,1],'EdgeColor','White','LineStyle','--');
    end % if

    sTitle = sprintf('%s Density after %0.2f m of Plasma (Dump %d)', fTranslateSpeciesReadable(sBeam), dZPos, iTime);

    title(sTitle,'FontSize',14);
    xlabel('\xi [mm]', 'FontSize',12);
    ylabel('r [mm]', 'FontSize',12);
    
    hold off;
    
    
    % Return

    stReturn.Beam1 = sBeam;
    stReturn.XLim  = xlim;
    stReturn.YLim  = ylim;
    stReturn.CLim  = caxis;
    
end