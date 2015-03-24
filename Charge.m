
%
%  Class Object :: Analyse Species Charge
% ****************************************
%

classdef Charge

    %
    % Public Properties
    %

    properties (GetAccess = 'public', SetAccess = 'public')
        
        Data        = [];                        % OsirisData dataset
        Species     = '';                        % Species to ananlyse
        Time        = 0;                         % Current time (dumb number)
        X1Lim       = [];                        % Axes limits x1
        X2Lim       = [];                        % Axes limits x2
        X3Lim       = [];                        % Axes limits x3
        Units       = 'N';                       % Units of axes
        AxisUnits   = {'N' 'N' 'N'};             % Units of axes
        AxisScale   = {'Auto' 'Auto' 'Auto'};    % Scale of axes
        AxisRange   = [0.0 0.0 0.0 0.0 0.0 0.0]; % Max and min of axes
        AxisFac     = [1.0 1.0 1.0];             % Axes scale factors
        ParticleFac = 1.0;                       % Q-to-particles factor
        ChargeFac   = 1.0;                       % Q-to-charge factor
        Coords      = '';                        % Coordinates

    end % properties

    %
    % Private Properties
    %
    
    properties (GetAccess = 'private', SetAccess = 'private')
        

    end % properties

    %
    % Constructor
    %

    methods
        
        function obj = Charge(oData, sSpecies, varargin)
            
            % Set data and species
            obj.Data    = oData;
            obj.Species = fTranslateSpecies(sSpecies);

            % Read input parameters
            oOpt = inputParser;
            addParameter(oOpt, 'Units',   'N');
            addParameter(oOpt, 'X1Scale', 'Auto');
            addParameter(oOpt, 'X2Scale', 'Auto');
            addParameter(oOpt, 'X3Scale', 'Auto');
            parse(oOpt, varargin{:});
            stOpt = oOpt.Results;

            % Read config
            dBoxX1Min = obj.Data.Config.Variables.Simulation.BoxX1Min;
            dBoxX1Max = obj.Data.Config.Variables.Simulation.BoxX1Max;
            dBoxX2Min = obj.Data.Config.Variables.Simulation.BoxX2Min;
            dBoxX2Max = obj.Data.Config.Variables.Simulation.BoxX2Max;
            dBoxX3Min = obj.Data.Config.Variables.Simulation.BoxX3Min;
            dBoxX3Max = obj.Data.Config.Variables.Simulation.BoxX3Max;
            sCoords   = obj.Data.Config.Variables.Simulation.Coordinates;
            dLFactor  = obj.Data.Config.Variables.Convert.SI.LengthFac;

            % Set Scale and Units
            obj.AxisScale = {stOpt.X1Scale, stOpt.X2Scale, stOpt.X3Scale};
            obj.Coords    = sCoords;

            % Evaluate units
            switch(lower(stOpt.Units))

                case 'si'
                    obj.Units = 'SI';
                    
                    [dX1Fac, sX1Unit]  = fLengthScale(obj.AxisScale{1}, 'm');
                    [dX2Fac, sX2Unit]  = fLengthScale(obj.AxisScale{2}, 'm');
                    [dX3Fac, sX3Unit]  = fLengthScale(obj.AxisScale{3}, 'm');
                    obj.AxisFac        = [dLFactor*dX1Fac, dLFactor*dX2Fac, dLFactor*dX3Fac];
                    obj.AxisUnits      = {sX1Unit, sX2Unit, sX3Unit};
                    obj.AxisRange(1:2) = [dBoxX1Min dBoxX1Max]*obj.AxisFac(1);
                    obj.AxisRange(3:4) = [dBoxX2Min dBoxX2Max]*obj.AxisFac(2);
                    obj.AxisRange(5:6) = [dBoxX3Min dBoxX3Max]*obj.AxisFac(3);
                    
                    obj.ParticleFac = obj.Data.Config.Variables.Convert.SI.ParticleFac;
                    obj.ChargeFac   = obj.Data.Config.Variables.Convert.SI.ChargeFac;

                otherwise
                    obj.Units = 'N';

                    obj.AxisFac = [1.0, 1.0, 1.0];
                    if strcmpi(sCoords, 'cylindrical')
                        obj.AxisUnits = {'c/\omega_p', 'c_/\omega_p', 'rad'};
                    else
                        obj.AxisUnits = {'c/\omega_p', 'c_/\omega_p', 'c/\omega_p'};
                    end % if
                    obj.AxisRange   = [dBoxX1Min dBoxX1Max dBoxX2Min dBoxX2Max dBoxX3Min dBoxX3Max];

                    obj.ParticleFac = obj.Data.Config.Variables.Convert.Norm.ParticleFac;
                    obj.ChargeFac   = obj.Data.Config.Variables.Convert.Norm.ChargeFac;

            end % switch

            % Set defult axis limits
            obj.X1Lim = [dBoxX1Min, dBoxX1Max]*obj.AxisFac(1);
            if strcmpi(sCoords, 'cylindrical')
                obj.X2Lim = [-dBoxX2Max, dBoxX2Max]*obj.AxisFac(2);
            else
                obj.X2Lim = [ dBoxX2Min, dBoxX2Max]*obj.AxisFac(2);
            end % if
            obj.X3Lim = [dBoxX3Min, dBoxX3Max]*obj.AxisFac(3);

        end % function

    end % methods

    %
    % Setters and Getters
    %

    methods
        
        function obj = set.Time(obj, sTime)
            
            sTime = num2str(sTime);
            iEnd  = fStringToDump(obj.Data, 'end');
            
            if strcmpi(sTime, 'next') || strcmpi(sTime, 'n')

                obj.Time = obj.Time + 1;
                if obj.Time > iEnd
                    obj.Time = iEnd;
                end % if

            elseif strcmpi(sTime, 'prev') || strcmpi(sTime, 'previous') || strcmpi(sTime, 'p')
            
                obj.Time = obj.Time - 1;
                if obj.Time < 0
                    obj.Time = 0;
                end % if

            else
                
                obj.Time = fStringToDump(obj.Data, sTime);

            end % if
            
        end % function
        
        function obj = set.X1Lim(obj, aX1Lim)

            dBoxX1Min = obj.Data.Config.Variables.Simulation.BoxX1Min;
            dBoxX1Max = obj.Data.Config.Variables.Simulation.BoxX1Max;

            if length(aX1Lim) ~= 2
                fprintf(2, 'Error: x1 limit needs to be a vector of dimension 2.\n');
                return;
            end % if

            if aX1Lim(2) < aX1Lim(1)
                fprintf(2, 'Error: second value must be larger than first value.\n');
                return;
            end % if

            if aX1Lim(1)/obj.AxisFac(1) < dBoxX1Min || aX1Lim(1)/obj.AxisFac(1) > dBoxX1Max ...
            || aX1Lim(2)/obj.AxisFac(1) < dBoxX1Min || aX1Lim(2)/obj.AxisFac(1) > dBoxX1Max
                fprintf('Warning: X1Lim input is out of range. Range is %.2f–%.2f %s.\n', dBoxX1Min*obj.AxisFac(1), dBoxX1Max*obj.AxisFac(1), obj.AxisUnits{1});
                aX1Lim(1) = dBoxX1Min*obj.AxisFac(1);
            end % if

            obj.X1Lim = aX1Lim/obj.AxisFac(1);

        end % function
         
        function obj = set.X2Lim(obj, aX2Lim)
 
            dBoxX2Min = obj.Data.Config.Variables.Simulation.BoxX2Min;
            dBoxX2Max = obj.Data.Config.Variables.Simulation.BoxX2Max;
            sCoords   = obj.Data.Config.Variables.Simulation.Coordinates;

            if length(aX2Lim) ~= 2
                fprintf(2, 'Error: x2 limit needs to be a vector of dimension 2.\n');
                return;
            end % if

            if aX2Lim(2) < aX2Lim(1)
                fprintf(2, 'Error: second value must be larger than first value.\n');
                return;
            end % if
            
            if strcmpi(sCoords, 'cylindrical')

                if aX2Lim(1)/obj.AxisFac(2) < -dBoxX2Max || aX2Lim(1)/obj.AxisFac(2) > dBoxX2Max ...
                || aX2Lim(2)/obj.AxisFac(2) < -dBoxX2Max || aX2Lim(2)/obj.AxisFac(2) > dBoxX2Max
                    fprintf('Warning: X2Lim input is out of range. Range is %.2f–%.2f %s.\n', ...
                            -dBoxX2Max*obj.AxisFac(2), dBoxX2Max*obj.AxisFac(2), obj.AxisUnits{2});
                    aX2Lim = [-dBoxX2Max*obj.AxisFac(2) dBoxX2Max*obj.AxisFac(2)];
                end % if

            else
                
                if aX2Lim(1)/obj.AxisFac(2) < dBoxX2Min || aX2Lim(1)/obj.AxisFac(2) > dBoxX2Max ...
                || aX2Lim(2)/obj.AxisFac(2) < dBoxX2Min || aX2Lim(2)/obj.AxisFac(2) > dBoxX2Max
                    fprintf('Warning: X2Lim input is out of range. Range is %.2f–%.2f %s.\n', ...
                            dBoxX2Min*obj.AxisFac(2), dBoxX2Max*obj.AxisFac(2), obj.AxisUnits{2});
                    aX2Lim = [dBoxX2Min*obj.AxisFac(2) dBoxX2Max*obj.AxisFac(2)];
                end % if

            end % if

            obj.X2Lim = aX2Lim/obj.AxisFac(2);
             
        end % function
 
        function obj = set.X3Lim(obj, aX3Lim)

            dBoxX3Min = obj.Data.Config.Variables.Simulation.BoxX3Min;
            dBoxX3Max = obj.Data.Config.Variables.Simulation.BoxX3Max;

            if length(aX3Lim) ~= 2
                fprintf(2, 'Error: x3 limit needs to be a vector of dimension 2.\n');
                return;
            end % if

            if aX3Lim(2) < aX3Lim(1)
                fprintf(2, 'Error: second value must be larger than first value.\n');
                return;
            end % if

            if aX3Lim(1)/obj.AxisFac(3) < dBoxX3Min || aX3Lim(1)/obj.AxisFac(3) > dBoxX3Max ...
            || aX3Lim(2)/obj.AxisFac(3) < dBoxX3Min || aX3Lim(2)/obj.AxisFac(3) > dBoxX3Max
                fprintf('Warning: X3Lim input is out of range. Range is %.2f–%.2f %s.\n', ...
                        dBoxX3Min*obj.AxisFac(3), dBoxX3Max*obj.AxisFac(3), obj.AxisUnits{3});
                aX3Lim = [dBoxX3Min*obj.AxisFac(3) dBoxX3Max*obj.AxisFac(3)];
            end % if

            obj.X3Lim = aX3Lim/obj.AxisFac(3);

        end % function

    end % methods
    
    %
    % Public Methods
    %
    
    methods (Access = 'public')
        
        function stReturn = Density(obj)
            
            % Input/Output
            stReturn = {};

            % Get simulation variables
            sCoords = obj.Data.Config.Variables.Simulation.Coordinates;
            dNMax   = obj.Data.Config.Variables.Plasma.MaxPlasmaFac;
            
            % Get data and axes
            aData   = obj.Data.Data(obj.Time, 'DENSITY', 'charge', obj.Species);
            aX1Axis = obj.fGetBoxAxis('x1');
            aX2Axis = obj.fGetBoxAxis('x2');

            % Check if cylindrical
            if strcmpi(sCoords, 'cylindrical')
                aData   = transpose([fliplr(aData),aData]);
                aX2Axis = [-fliplr(aX2Axis), aX2Axis];
            else
                aData   = transpose(aData);
            end % if
            
            iX1Min = fGetIndex(aX1Axis, obj.X1Lim(1)*obj.AxisFac(1));
            iX1Max = fGetIndex(aX1Axis, obj.X1Lim(2)*obj.AxisFac(1));
            iX2Min = fGetIndex(aX2Axis, obj.X2Lim(1)*obj.AxisFac(2));
            iX2Max = fGetIndex(aX2Axis, obj.X2Lim(2)*obj.AxisFac(2));

            % Crop and scale dataset
            aData   = aData(iX2Min:iX2Max,iX1Min:iX1Max)/dNMax;
            aX1Axis = aX1Axis(iX1Min:iX1Max);
            aX2Axis = aX2Axis(iX2Min:iX2Max);
            
            % Return data
            stReturn.Data   = aData;
            stReturn.X1Axis = aX1Axis;
            stReturn.X2Axis = aX2Axis;
            stReturn.ZPos   = obj.fGetZPos();
            
        end % function

        function stReturn = Fourier(obj, aRange)
            
            stReturn = {};
            
            if nargin < 2
                aRange = [];
            end % if
            
            dPlasmaFac = obj.Data.Config.Variables.Plasma.MaxPlasmaFac;
            dXMin      = obj.Data.Config.Variables.Simulation.BoxX1Min;
            dXMax      = obj.Data.Config.Variables.Simulation.BoxX1Max;
            dBoxSize   = dXMax-dXMin;
            
            h5Data = obj.Data.Data(obj.Time, 'DENSITY', 'charge', obj.Species);
            if isempty(aRange)
                aProj = abs(sum(transpose(h5Data),1));
            else
                if length(aRange) == 1
                    aProj = abs(sum(transpose(h5Data(:,aRange(1))),1));
                else
                    aProj = abs(sum(transpose(h5Data(:,aRange(1):aRange(1))),1));
                end % if
            end % if

            iLen   = length(aProj);
            iN     = 2^nextpow2(iLen);
            aFFT   = fft(aProj,iN)/iLen;
            aXAxis = 2*pi*iLen/dBoxSize/2*linspace(0,1,iN/2+1)/sqrt(dPlasmaFac);
            
            stReturn.Proj  = aProj;
            stReturn.Data  = 2*abs(aFFT(1:iN/2+1));
            stReturn.XAxis = aXAxis;
            stReturn.ZPos  = obj.fGetZPos();
            
        end % function

        function stReturn = Wavelet(obj, aRange, varargin)
            
            % Input/Output
            stReturn = {};

            if nargin < 2
                aRange = [];
            end % if

            oOpt = inputParser;
            addParameter(oOpt, 'Octaves', 7);
            parse(oOpt, varargin{:});
            stOpt = oOpt.Results;

            % Simulation parameters
            dPlasmaFac = obj.Data.Config.Variables.Plasma.MaxPlasmaFac;
            iBoxNX     = obj.Data.Config.Variables.Simulation.BoxNX1;
            dXMin      = obj.Data.Config.Variables.Simulation.BoxX1Min;
            dXMax      = obj.Data.Config.Variables.Simulation.BoxX1Max;
            dBoxSize   = dXMax-dXMin;

            % Get dataset
            aData = obj.Data.Data(obj.Time, 'DENSITY', 'charge', obj.Species);

            if isempty(aRange)
                aProj = abs(sum(transpose(aData),1));
            else
                if length(aRange) == 1
                    aProj = abs(sum(transpose(aData(:,aRange(1))),1));
                else
                    aProj = abs(sum(transpose(aData(:,aRange(1):aRange(1))),1));
                end % if
            end % if

            aProj = aProj/max(aProj);

            % Wavelet parameters
            dZ    = dBoxSize/double(iBoxNX)/sqrt(dPlasmaFac);
            iPad  = 1;
            dDJ   = 0.02;
            dS0   = 2*dZ;
            dJ1   = stOpt.Octaves/dDJ;

            % Wavelet
            [aWave, aPeriod, aScale, aCOI] = wavelet(aProj, dZ, iPad, dDJ, dS0, dJ1, 'MORLET', 6);

            % Return
            stReturn.Input     = aProj;
            stReturn.Data      = aWave;
            stReturn.Real      = real(aWave);
            stReturn.Imaginary = imag(aWave);
            stReturn.Amplitude = abs(aWave);
            stReturn.Phase     = atan(imag(aWave)/real(aWave));
            stReturn.Power     = abs(aWave).^2;
            stReturn.Period    = aPeriod;
            stReturn.Scale     = aScale;
            stReturn.COI       = aCOI;
            stReturn.XAxis     = obj.fGetBoxAxis('x1');
            stReturn.ZPos      = obj.fGetZPos();
            
        end % function
        
        function stReturn = BeamCharge(obj, varargin)
            
            % Input/Output
            stReturn = {};

            % Read input parameters
            oOpt = inputParser;
            addParameter(oOpt, 'Ellipse', []);
            parse(oOpt, varargin{:});
            stOpt = oOpt.Results;
            
            % Species must be a beam
            if ~isBeam(obj.Species)
                fprintf(2, 'Error: Species %s is not a beam.\n', obj.Species);
                return;
            end % if
            
            
            dRAWFrac  = obj.Data.Config.Variables.Beam.(obj.Species).RAWFraction;
            dTFactor  = obj.Data.Config.Variables.Convert.SI.TimeFac;
            dRQM      = obj.Data.Config.Variables.Beam.(obj.Species).RQM;
            dSign     = dRQM/abs(dRQM);
            
            aRaw      = obj.Data.Data(obj.Time, 'RAW', '', obj.Species);
            iCount    = length(aRaw(:,1));
            aRaw(:,1) = aRaw(:,1) - dTFactor*obj.Time;
            
            % Eliminate charge outside box. In cylindrical X2Lim(1) < 0 is 0
            aRaw(:,8) = aRaw(:,8).*(aRaw(:,1) >= obj.X1Lim(1) & aRaw(:,1) <= obj.X1Lim(2));
            aRaw(:,8) = aRaw(:,8).*(aRaw(:,2) >= obj.X2Lim(1) & aRaw(:,2) <= obj.X2Lim(2));
            
            if length(stOpt.Ellipse) == 4

                dXPos = stOpt.Ellipse(1)/obj.AxisFac(1);
                dRPos = stOpt.Ellipse(2)/obj.AxisFac(2);
                dZRad = stOpt.Ellipse(3)/obj.AxisFac(1);
                dRRad = stOpt.Ellipse(4)/obj.AxisFac(2);

                % Applying condition:
                aRaw(:,8) = aRaw(:,8).*(((aRaw(:,1)-dZPos).^2/dZRad^2 + (aRaw(:,2)-dRPos).^2/dRRad^2) <= 1);

                stReturn.Box    = 'Ellipse';
                stReturn.Coords = [dZPos, dRPos, dZRad, dRRad];

            end % if
            
            % Total charge
            
            dQ = sum(aRaw(:,8))/dRAWFrac; % Sum of RAW field q
            dP = dQ*obj.ParticleFac;
            dQ = dQ*obj.ChargeFac;
            
            % Meta data
            
            iSCount  = nnz(aRaw(:,8));
            dExact   = dQ/sqrt(iCount/dRAWFrac);
            dSErrorQ = abs(dQ/(dRAWFrac*sqrt(iSCount))-dExact);
            dSErrorP = abs(dP/(dRAWFrac*sqrt(iSCount))-dExact);
            
            % Return data
            
            stReturn.QTotal              = dQ;
            stReturn.Particles           = dP*dSign;
            stReturn.RAWFraction         = dRAWFrac;
            stReturn.RAWCount            = iCount;
            stReturn.SampleCount         = iSCount;
            stReturn.ChargeSampleError   = dSErrorQ;
            stReturn.ParticleSampleError = dSErrorP;
            
        end % function

        function stReturn = Beamlets(obj, varargin)
            
            % Input/Output
            stReturn = {};

            % Values
            dMaxPlasma = obj.Data.Config.Variables.Plasma.MaxPlasmaFac;
            sCoords    = obj.Data.Config.Variables.Simulation.Coordinates;
            dRAWFrac   = obj.Data.Config.Variables.Beam.(obj.Species).RAWFraction;
            dTFactor   = obj.Data.Config.Variables.Convert.SI.TimeFac;
            dRQM       = obj.Data.Config.Variables.Beam.(obj.Species).RQM;

            % Read input parameters
            oOpt = inputParser;
            addParameter(oOpt, 'IgnoreLimits',    'No');
            addParameter(oOpt, 'BeamProminence',  0.5); % In fraction of maximum
            addParameter(oOpt, 'MinPeakDistance', 0.5); % In units of max(lambda_p)
            addParameter(oOpt, 'SmoothSpan',      0.5); % In units of max(lambda_p)
            addParameter(oOpt, 'RadialInclude',   0.9); % How much radial charge to include
            parse(oOpt, varargin{:});
            stOpt = oOpt.Results;

            % Species must be a beam
            if ~isBeam(obj.Species)
                fprintf(2, 'Error: Species %s is not a beam.\n', obj.Species);
                return;
            end % if

            % Load charge density data
            h5Data  = obj.Data.Data(obj.Time, 'DENSITY', 'charge', obj.Species);
            h5Data  = double(abs(h5Data));
            [nX1,~] = size(h5Data);

            % Get axes
            aX1Axis = obj.fGetBoxAxis('x1');
            aX2Axis = obj.fGetBoxAxis('x2');
            if strcmpi(sCoords, 'Cylindrical')
                aX2Axis = [-fliplr(aX2Axis) aX2Axis];
            end % if

            % Calculate Span value for smooth function and MinPeakDistance for findpeaks
            dSpan     = stOpt.SmoothSpan * 2*pi/sqrt(dMaxPlasma) * obj.AxisFac(1) / (aX1Axis(2)-aX1Axis(1)) / nX1;
            dMinPeakD = stOpt.MinPeakDistance * 2*pi/sqrt(dMaxPlasma) * obj.AxisFac(1) / (aX1Axis(2)-aX1Axis(1));
            
            % Project data onto x1-axis and smooth
            aData   = abs(sum(h5Data,2));
            aSmooth = smooth(aData,dSpan,'loess');

            % Find peaks
            [aPeaks,aLocs,~,aProms] = findpeaks(aSmooth,'MinPeakDistance',dMinPeakD,'WidthReference','HalfHeight');
            
            % Eliminate peaks with prominence below threshold
            dMax   = max(abs(aSmooth));
            dMin   = min(abs(aSmooth));
            dThres = stOpt.BeamProminence*(dMax-dMin)+dMin;
            aPeaks = aPeaks.*(aProms >= dThres);
            aProms = aProms.*(aProms >= dThres);
            aPeaks(aPeaks == 0) = [];
            aProms(aProms == 0) = [];
            
            % Find peak boundaries based on soothed data
            iPeaks = length(aPeaks);
            aSpan  = zeros(2,iPeaks);
            if iPeaks > 0
                [~,iLoc] = min(flipud(aSmooth(1:aLocs(1))));
                aSpan(1,1) = aLocs(1)-iLoc;
                for i=2:iPeaks
                    [~,iLoc] = min(flipud(aSmooth(aLocs(i-1):aLocs(i))));
                    aSpan(1,i) = aLocs(i)-iLoc;
                end % for
                for i=1:iPeaks-1
                    [~,iLoc] = min(aSmooth(aLocs(i):aLocs(i+1)));
                    aSpan(2,i) = aLocs(i)+iLoc;
                end % for
                [~,iLoc] = min(aSmooth(aLocs(end):length(aSmooth)));
                aSpan(2,end) = aLocs(end)+iLoc;
            end % if

            % Preview plot for test purposes
            %figure(2);
            %plot(aData, 'r');
            %hold on;
            %plot(aSmooth,'b','LineWidth',2);
            %scatter(aSpan(1,:), ones(1,length(aSpan(1,:)))*-0.2, 'k+');
            %scatter(aSpan(2,:), ones(1,length(aSpan(2,:)))*-0.3, 'r+');
            %hold off;
            
            % Get RAW data
            aRaw      = obj.Data.Data(obj.Time, 'RAW', '', obj.Species);
            aRaw(:,1) = (aRaw(:,1) - dTFactor*obj.Time)*obj.AxisFac(1);
            
            % Create return matrix
            stBeamlets(iPeaks) = struct();
            for i=1:iPeaks
                
                % X! Data
                aProj = aData(aSpan(1,i):aSpan(2,i)).';
                aAxis = aX1Axis(aSpan(1,i):aSpan(2,i));
                
                [dMax,iMax] = max(aProj);
                dHalfMax    = dMax/2.0;
                iUpper      = 0;
                iLower      = 0;
                for k=iMax:length(aProj)
                    if aProj(k) <= dHalfMax
                        iUpper = k;
                        break;
                    end % if
                end % for
                for k=iMax:-1:1
                    if aProj(k) <= dHalfMax
                        iLower = k;
                        break;
                    end % if
                end % for

                stBeamlets(i).X1Start = aAxis(1);
                stBeamlets(i).X1Stop  = aAxis(end);
                stBeamlets(i).X1Proj  = aProj;
                stBeamlets(i).X1Peak  = aAxis(iMax);
                stBeamlets(i).X1FWHM  = [aAxis(iLower) aAxis(iUpper)];
                stBeamlets(i).X1Mean  = wmean(aAxis, aProj);
                stBeamlets(i).X1Std   = wstd(aAxis, aProj);
                
                % X2 Data
                aProj = sum(h5Data(aSpan(1,i):aSpan(2,i),:),1);
                aAxis = aX2Axis;
                dAQ     = 0.0;
                dSum    = sum(aProj);
                iRLim   = length(aProj);
                for r=1:length(aProj)
                    dAQ = dAQ + aProj(r);
                    if dAQ >= stOpt.RadialInclude*dSum
                        iRLim = r;
                        break;
                    end % if
                end % for
                if strcmpi(sCoords, 'Cylindrical')
                    aProj = [fliplr(aProj) aProj];
                end % if

                [dMax,iMax] = max(aProj);
                dHalfMax    = dMax/2.0;
                iUpper      = 0;
                iLower      = 0;
                for k=iMax:length(aProj)
                    if aProj(k) <= dHalfMax
                        iUpper = k;
                        break;
                    end % if
                end % for
                for k=iMax:-1:1
                    if aProj(k) <= dHalfMax
                        iLower = k;
                        break;
                    end % if
                end % for

                stBeamlets(i).X2Start = 0.0;
                stBeamlets(i).X2Stop  = iRLim;
                stBeamlets(i).X2Proj  = aProj;
                stBeamlets(i).X2Peak  = aAxis(iMax);
                stBeamlets(i).X2FWHM  = [aAxis(iLower) aAxis(iUpper)];
                stBeamlets(i).X2Mean  = wmean(aX2Axis, stBeamlets(i).X2Proj);
                stBeamlets(i).X2Std   = wstd(aX2Axis, stBeamlets(i).X2Proj);

                % Beamlet Charge
                stBeamlets(i).Charge = sum(aRaw(:,8).*( ...
                                           aRaw(:,1) >= aX1Axis(aSpan(1,i)) & ...
                                           aRaw(:,1) <= aX1Axis(aSpan(2,i))   ...
                                          ))*obj.ChargeFac/dRAWFrac;
            end % for
            
            % Return data
            stReturn.RAWData     = h5Data;
            stReturn.X1Axis      = aX1Axis;
            stReturn.X2Axis      = aX2Axis;
            stReturn.Projection  = aData';
            stReturn.Smooth      = aSmooth';
            stReturn.Peaks       = iPeaks;
            stReturn.Prominence  = transpose(aProms);
            stReturn.Span        = aSpan;
            stReturn.Beamlets    = stBeamlets;
            stReturn.TotalCharge = sum(aRaw(:,8))*obj.ChargeFac/dRAWFrac;
            
        end % function
        
        function stReturn = ParticleSample(obj, varargin)
        
            % Input/Output
            stReturn = {};

            % Read input parameters
            oOpt = inputParser;
            addParameter(oOpt, 'Sample', 200);
            addParameter(oOpt, 'Filter', 'Random');
            parse(oOpt, varargin{:});
            stOpt = oOpt.Results;

            % Read variables
            sCoords   = obj.Data.Config.Variables.Simulation.Coordinates;
            dTFactor  = obj.Data.Config.Variables.Convert.SI.TimeFac;
            dRQM      = obj.Data.Config.Variables.Beam.(obj.Species).RQM;
            dSign     = dRQM/abs(dRQM);
            
            aRaw      = obj.Data.Data(obj.Time, 'RAW', '', obj.Species);
            iCount    = length(aRaw(:,1));
            aRaw(:,1) = aRaw(:,1) - dTFactor*obj.Time;

            iCount = stOpt.Sample;
            if iCount > length(aRaw(:,1))
                iCount = length(aRaw(:,1));
            end % if

            % Removing elements outside box
            aRaw(:,8) = aRaw(:,8).*(aRaw(:,1) >= obj.X1Lim(1) & aRaw(:,1) <= obj.X1Lim(2));
            aRaw(:,8) = aRaw(:,8).*(aRaw(:,2) >= obj.X2Lim(1) & aRaw(:,2) <= obj.X2Lim(2));
            aRaw      = aRaw(find(aRaw(:,8)),:);
            
            if strcmpi(sCoords, 'cylindrical')
                aRaw(:,8) = aRaw(:,8)./aRaw(:,2);
                aRaw      = [aRaw; aRaw(:,1) -aRaw(:,2) aRaw(:,3:end)]; 
            end % if

            aRaw(:,9) = aRaw(:,8)*dSign;

            switch(lower(stOpt.Filter))
                case 'random'
                    aRand = randperm(length(aRaw(:,1)));
                    aRaw  = aRaw(aRand(1:iCount),:);
                case 'charge'
                    aRaw  = sortrows(aRaw,9);
                    aRaw  = aRaw(end-iCount+1:end,:);
            end % switch
            
            % Return data
            stReturn.X1     = aRaw(:,1)*obj.AxisFac(1);
            stReturn.X2     = aRaw(:,2)*obj.AxisFac(2);
            stReturn.X3     = aRaw(:,3)*obj.AxisFac(3);
            stReturn.P1     = aRaw(:,4);
            stReturn.P2     = aRaw(:,5);
            stReturn.P3     = aRaw(:,6);
            stReturn.Energy = aRaw(:,7);
            stReturn.Charge = aRaw(:,8)*obj.ChargeFac;
            stReturn.Count  = aRaw(:,9)*obj.ParticleFac;
            stReturn.Norm   = aRaw(:,9)./max(aRaw(:,9));
            stReturn.Area   = 7*(0.4 + stReturn.Norm);

        end % function
        
    end % methods
    
    %
    % Private Methods
    %
    
    methods (Access = 'private')
        
        function aReturn = fGetTimeAxis(obj)
            
            iDumps  = obj.Data.Elements.DENSITY.(obj.Species).charge.Info.Files-1;
            
            dPStart = obj.Data.Config.Variables.Plasma.PlasmaStart;
            dTFac   = obj.Data.Config.Variables.Convert.SI.TimeFac;
            dLFac   = obj.Data.Config.Variables.Convert.SI.LengthFac;
            
            aReturn = (linspace(0.0, dTFac*iDumps, iDumps+1)-dPStart)*dLFac;
            
        end % function

        function aReturn = fGetBoxAxis(obj, sAxis)
            
            switch sAxis
                case 'x1'
                    dXMin = obj.Data.Config.Variables.Simulation.BoxX1Min;
                    dXMax = obj.Data.Config.Variables.Simulation.BoxX1Max;
                    iNX   = obj.Data.Config.Variables.Simulation.BoxNX1;
                    dLFac = obj.AxisFac(1);
                case 'x2'
                    dXMin = obj.Data.Config.Variables.Simulation.BoxX2Min;
                    dXMax = obj.Data.Config.Variables.Simulation.BoxX2Max;
                    iNX   = obj.Data.Config.Variables.Simulation.BoxNX2;
                    dLFac = obj.AxisFac(2);
                case 'x3'
                    dXMin = obj.Data.Config.Variables.Simulation.BoxX3Min;
                    dXMax = obj.Data.Config.Variables.Simulation.BoxX3Max;
                    iNX   = obj.Data.Config.Variables.Simulation.BoxNX3;
                    dLFac = obj.AxisFac(3);
            end % switch

            aReturn = linspace(dXMin, dXMax, iNX)*dLFac;
            
        end % function
        
        function dReturn = fGetZPos(obj)
            
            dLFactor = obj.Data.Config.Variables.Convert.SI.LengthFac;
            dTFactor = obj.Data.Config.Variables.Convert.SI.TimeFac;
            dPStart  = obj.Data.Config.Variables.Plasma.PlasmaStart;
            
            dReturn  = (obj.Time*dTFactor - dPStart)*dLFactor;
            
        end % function

    end % methods

end % classdef

