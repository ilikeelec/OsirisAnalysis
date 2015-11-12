
%
%  Class Object :: Momentum
% **************************
%  SubClass of OsirisType
%
%  Description:
%    A class to analyse and handle Osiris data related to the momentum and
%    energy of particles.
%
%  Constructor:
%    oData    : OsirisDara object
%    sSpecies : What species to study
%    Parameter pairs:
%      Units   : 'N', 'SI' or 'CGS'
%      X1Scale : Unit scale on x1 axis. 'Auto', or specify metric unit
%      X2Scale : Unit scale on x2 axis. 'Auto', or specify metric unit
%      X3Scale : Unit scale on x3 axis. 'Auto', or specify metric unit
%
%  Set Methods:
%    Time  : Set time dump for dataset. Default is 0.
%    X1Lim : 2D array of limits for x1 axis. Default is full box.
%    X2Lim : 2D array of limits for x2 axis. Default is full box.
%    X3Lim : 2D array of limits for x3 axis. Default is full box.
%
%  Public Methods:
%    SigmaEToEMean    : Returns a dataset with mean energy and spread.
%    Evolution        : Returns a dataset of momentum along an axis as a
%                       function of time (plasma length).
%    BeamSlip         : Returns a dataset of information on beam slipping.
%    PhaseSpace       : Returns a dataset with information on beam emittance
%                       or emittance-like properties.
%    MomentumToEnergy : Converts a vector of momenta to energy.
%

classdef Momentum < OsirisType

    %
    % Properties
    %

    properties(GetAccess = 'public', SetAccess = 'public')
        
        Species = ''; % Species to analyse

    end % properties

    %
    % Constructor
    %

    methods
        
        function obj = Momentum(oData, sSpecies, varargin)
            
            % Call OsirisType constructor
            obj@OsirisType(oData, varargin{:});
            
            % Set species
            stSpecies = obj.Translate.Lookup(sSpecies);
            if stSpecies.isSpecies
                obj.Species = stSpecies;
            else
                sDefault = obj.Data.Config.Variables.Species.WitnessBeam{1};
                fprintf(2, 'Error: ''%s'' is not a recognised species name. Using ''%s'' instead.\n', sSpecies, sDefault);
                obj.Species = obj.Translate.Lookup(sDefault);
            end % if

        end % function
        
    end % methods

    %
    % Public Methods
    %
    
    methods(Access = 'public')
        
        function stReturn = SigmaEToEMean(obj, sStart, sStop)

            stReturn = {};

            if nargin < 2
                sStart = 'Start';
            end % if

            if nargin < 3
                sStop = 'End';
            end % if
            
            % Calculate range
            iStart = obj.Data.StringToDump(sStart);
            iStop  = obj.Data.StringToDump(sStop);

            % Calculate axes
            aTAxis = obj.fGetTimeAxis;
            aTAxis = aTAxis(iStart+1:iStop+1);
            
            aMean  = zeros(1, length(aTAxis));
            aSigma = zeros(1, length(aTAxis));
            aData  = zeros(1, length(aTAxis));
            
            for i=iStart:iStop
                
                k = i-iStart+1;
                
                h5Data = obj.Data.Data(i, 'RAW', '', obj.Species.Name);
                
                if length(h5Data(:,8)) == 1 && h5Data(1,8) == 0
                    aMean(k)  = 0.0;
                    aSigma(k) = 0.0;
                    aData(k)  = 0.0;
                else
                    aMean(k)  = obj.MomentumToEnergy(wmean(h5Data(:,4), abs(h5Data(:,8))));
                    aSigma(k) = obj.MomentumToEnergy(wstd(h5Data(:,4), abs(h5Data(:,8))));
                    aData(k)  = aSigma(k)/aMean(k);
                end % if
                
            end % for
            
            % Return data
            stReturn.TimeAxis = aTAxis;
            stReturn.Mean     = aMean;
            stReturn.Sigma    = aSigma;
            stReturn.Data     = aData;

        end % function

        function stReturn = Evolution(obj, sAxis, sStart, sStop, varargin)

            stReturn = {};
            
            if nargin < 3
                sStart = 'Start';
            end % if

            if nargin < 4
                sStop = 'End';
            end % if
            
            iStart = obj.Data.StringToDump(sStart);
            iStop  = obj.Data.StringToDump(sStop);

            oOpt = inputParser;
            addParameter(oOpt, 'Percentile', []);
            parse(oOpt, varargin{:});
            stOpt = oOpt.Results;
            
            % Read simulation data
            dEMass = obj.Data.Config.Variables.Constants.ElectronMassMeV*1e6;

            % Calculate axes
            aTAxis = obj.fGetTimeAxis;
            aTAxis = aTAxis(iStart+1:iStop+1);

            stReturn.TimeAxis = aTAxis;

            switch(fMomentumAxis(sAxis))
                case 'p1'
                    iAxis = 4;
                case 'p2'
                    iAxis = 5;
                case 'p3'
                    iAxis = 6;
            end % switch
            
            for i=iStart:iStop
                
                k = i-iStart+1;

                aRAW = obj.Data.Data(i, 'RAW', '', obj.Species.Name)*dEMass;

                stReturn.Average(k) = double(wmean(aRAW(:,iAxis),aRAW(:,8)));
                stReturn.Median(k)  = wprctile(aRAW(:,iAxis),50,abs(aRAW(:,8)));
                
                if ~isempty(stOpt.Percentile)
                    for p=1:length(stOpt.Percentile)
                        c = stOpt.Percentile(p);
                        if c < 1 || c > 100
                            continue;
                        end % if
                        sSet = sprintf('Percentile%d', c);
                        stReturn.(sSet)(k) = wprctile(aRAW(:,iAxis),c,abs(aRAW(:,8)));
                    end % for
                end % if

            end % for
    
        end % function

        function stReturn = BeamSlip(obj, sStart, sStop, dAdd)

            stReturn = {};

            if nargin < 2
                sStart = 'Start';
            end % if

            if nargin < 3
                sStop = 'End';
            end % if

            if nargin < 4
                dAdd = 0.0;
            end % if
            
            iStart = obj.Data.StringToDump(sStart);
            iStop  = obj.Data.StringToDump(sStop);
            
            % Variables
            dLFac     = obj.AxisFac(1);
            dTimeStep = obj.Data.Config.Variables.Simulation.TimeStep;
            iNDump    = obj.Data.Config.Variables.Simulation.NDump;
            dDeltaZ   = dTimeStep*iNDump;
            
            for i=iStart:iStop
                
                k = i-iStart+1;

                aRaw = obj.Data.Data(i, 'RAW', '', obj.Species.Name);

                stReturn.Slip.Average(k)           = (dDeltaZ - dDeltaZ*sqrt(1-1/wmean(aRaw(:,4),aRaw(:,8))^2))*dLFac;
                stReturn.Slip.Median(k)            = (dDeltaZ - dDeltaZ*sqrt(1-1/wprctile(aRaw(:,4),50,abs(aRaw(:,8)))^2))*dLFac;
                stReturn.Slip.Percentile10(k)      = (dDeltaZ - dDeltaZ*sqrt(1-1/wprctile(aRaw(:,4),10,abs(aRaw(:,8)))^2))*dLFac;
                stReturn.Slip.Percentile90(k)      = (dDeltaZ - dDeltaZ*sqrt(1-1/wprctile(aRaw(:,4),90,abs(aRaw(:,8)))^2))*dLFac;
                stReturn.Slip.FirstQuartile(k)     = (dDeltaZ - dDeltaZ*sqrt(1-1/wprctile(aRaw(:,4),25,abs(aRaw(:,8)))^2))*dLFac;
                stReturn.Slip.ThirdQuartile(k)     = (dDeltaZ - dDeltaZ*sqrt(1-1/wprctile(aRaw(:,4),75,abs(aRaw(:,8)))^2))*dLFac;

                stReturn.Position.Average(k)       = (wmean(aRaw(:,1),aRaw(:,8))-(i*dDeltaZ))*dLFac;
                stReturn.Position.Median(k)        = (wprctile(aRaw(:,1),50,abs(aRaw(:,8)))-(i*dDeltaZ))*dLFac;
                stReturn.Position.Percentile10(k)  = (wprctile(aRaw(:,1),10,abs(aRaw(:,8)))-(i*dDeltaZ))*dLFac;
                stReturn.Position.Percentile90(k)  = (wprctile(aRaw(:,1),90,abs(aRaw(:,8)))-(i*dDeltaZ))*dLFac;
                stReturn.Position.FirstQuartile(k) = (wprctile(aRaw(:,1),25,abs(aRaw(:,8)))-(i*dDeltaZ))*dLFac;
                stReturn.Position.ThirdQuartile(k) = (wprctile(aRaw(:,1),75,abs(aRaw(:,8)))-(i*dDeltaZ))*dLFac;
                
                if k > 1
                    stReturn.ExpectedPos.Average(k)       = stReturn.Position.Average(1)       - sum(stReturn.Slip.Average(1:k-1));
                    stReturn.ExpectedPos.Median(k)        = stReturn.Position.Median(1)        - sum(stReturn.Slip.Median(1:k-1));
                    stReturn.ExpectedPos.Percentile10(k)  = stReturn.Position.Percentile10(1)  - sum(stReturn.Slip.Percentile10(1:k-1));
                    stReturn.ExpectedPos.Percentile90(k)  = stReturn.Position.Percentile90(1)  - sum(stReturn.Slip.Percentile90(1:k-1));
                    stReturn.ExpectedPos.FirstQuartile(k) = stReturn.Position.FirstQuartile(1) - sum(stReturn.Slip.FirstQuartile(1:k-1));
                    stReturn.ExpectedPos.ThirdQuartile(k) = stReturn.Position.ThirdQuartile(1) - sum(stReturn.Slip.ThirdQuartile(1:k-1));
                else
                    stReturn.ExpectedPos.Average(1)       = stReturn.Position.Average(1);
                    stReturn.ExpectedPos.Median(1)        = stReturn.Position.Median(1);
                    stReturn.ExpectedPos.Percentile10(1)  = stReturn.Position.Percentile10(1);
                    stReturn.ExpectedPos.Percentile90(1)  = stReturn.Position.Percentile90(1);
                    stReturn.ExpectedPos.FirstQuartile(1) = stReturn.Position.FirstQuartile(1);
                    stReturn.ExpectedPos.ThirdQuartile(1) = stReturn.Position.ThirdQuartile(1);
                end % if
                
                % Slip if added energy
                stReturn.Slip.AverageAdd(k) = (dDeltaZ - dDeltaZ*sqrt(1-1/(dAdd + wmean(aRaw(:,4),aRaw(:,8)))^2))*dLFac;
                stReturn.Slip.MedianAdd(k)  = (dDeltaZ - dDeltaZ*sqrt(1-1/(dAdd + wprctile(aRaw(:,4),50,abs(aRaw(:,8))))^2))*dLFac;
                if k > 1
                    stReturn.ExpectedAdd.Average(k) = stReturn.Position.Average(1) - sum(stReturn.Slip.AverageAdd(1:k-1));
                    stReturn.ExpectedAdd.Median(k)  = stReturn.Position.Median(1)  - sum(stReturn.Slip.MedianAdd(1:k-1));
                else
                    stReturn.ExpectedAdd.Average(1) = stReturn.Position.Average(1);
                    stReturn.ExpectedAdd.Median(1)  = stReturn.Position.Median(1);
                end % if
                
            end % for
            
            aTAxis = obj.fGetTimeAxis;
            
            stReturn.DeltaZ = dDeltaZ;
            stReturn.TAxis  = aTAxis(iStart+1:iStop+1);
    
        end % function

        function stReturn = PhaseSpace(obj, varargin)
            
            stReturn = {};

            oOpt = inputParser;
            addParameter(oOpt, 'Samples',      1);
            addParameter(oOpt, 'MinParticles', 100000);
            addParameter(oOpt, 'Histogram',    'No');
            addParameter(oOpt, 'Grid',         [1000 1000]);
            parse(oOpt, varargin{:});
            stOpt = oOpt.Results;

            aRaw   = obj.Data.Data(obj.Time, 'RAW', '', obj.Species.Name);
            aP     = sqrt(aRaw(:,4).^2 + aRaw(:,5).^2 + aRaw(:,6).^2);
            iLen   = length(aP);
            aERMS  = zeros(stOpt.Samples, 1);
            aENorm = zeros(stOpt.Samples, 1);
            
            aRX   = [];
            aRXP  = [];
            aRQ   = [];
            aGam  = [];
            
            iMin  = ceil(stOpt.MinParticles/iLen);
            if stOpt.Samples < iMin
                iS = iMin;
            else
                iS = stOpt.Samples;
            end % if

            for s=1:iS

                if obj.Dim == 2
                    aXth = rand(size(aRaw,1),1)*2*pi;
                else
                    aXth = aRaw(:,3);
                end % if

                if strcmpi(obj.Coords, 'cylindrical')
                    aPz  = aRaw(:,4);
                    aPr  = aRaw(:,5);
                    aPth = aRaw(:,6);
                    aPx  = aPr.*cos(aXth) - aPth.*sin(aXth);
                    aX   = aRaw(:,2).*cos(aXth)*obj.AxisFac(2);
                else
                    aPz  = aRaw(:,4);
                    aPx  = aRaw(:,5);
                    aX   = aRaw(:,2)*obj.AxisFac(2);
                end % if
 
                aGamma    = obj.MomentumToEnergy(aPz);
                aXPrime   = sin(aPx./aP)*1e3;
                aCharge   = aRaw(:,8)*obj.Data.Config.Variables.Convert.SI.ChargeFac;
                aCov      = wcov([aX, aXPrime], abs(aCharge));
                dGamma    = wmean(aGamma, abs(aCharge));
                dBeta     = sqrt(1 - 1/dGamma^2);
                aERMS(s)  = sqrt(det(aCov));
                aENorm(s) = sqrt(det(aCov))*dGamma*dBeta;
            
                if strcmpi(obj.Coords, 'cylindrical')
                    aX      = [-aX;aX];
                    aXPrime = [-aXPrime;aXPrime];
                    aCharge = [aCharge;aCharge];
                end % if
                
                if length(aRX) < stOpt.MinParticles
                    aRX  = [aRX;aX];
                    aRXP = [aRXP;aXPrime];
                    aRQ  = [aRQ;aCharge];
                end % if

            end % for
            
            iNE = length(aERMS) - 1;
            iNE = iNE + (iNE == 0);
            
            stReturn.Raw        = aRaw;
            stReturn.X          = aRX;
            stReturn.XUnit      = obj.AxisUnits{1};
            stReturn.XPrime     = aRXP;
            stReturn.XPrimeUnit = 'mrad';
            stReturn.Charge     = aRQ;
            stReturn.Weight     = abs(aRQ)/max(abs(aRQ));
            stReturn.Covariance = aCov;
            stReturn.ERMS       = mean(aERMS);
            stReturn.ERMSError  = 1.96*std(aERMS)/sqrt(iNE);
            stReturn.ENorm      = mean(aENorm);
            stReturn.ENormError = 1.96*std(aENorm)/sqrt(iNE);
            
            if strcmpi(stOpt.Histogram, 'No')
                return;
            end % if
            
            aHist   = zeros(stOpt.Grid(1),stOpt.Grid(2));
            
            dXMax   = max(abs(aRX));
            dXPMax  = max(abs(aRXP));
            dXMin   = -dXMax;
            dXPMin  = -dXPMax;

            dDX     = dXMax/((stOpt.Grid(1)-2)/2);
            dDXP    = dXPMax/((stOpt.Grid(2)-2)/2);
            aM      = floor(aRX/dDX)+(stOpt.Grid(1)/2)+1;
            aN      = floor(aRXP/dDXP)+(stOpt.Grid(2)/2)+1;
            
            for i=1:length(aM)
                aHist(aM(i),aN(i)) = aHist(aM(i),aN(i)) + aRQ(i);
            end % for
            
            stReturn.Hist   = abs(transpose(aHist))*1e9;
            stReturn.X1Axis = linspace(dXMin,dXMax,stOpt.Grid(1));
            stReturn.X2Axis = linspace(dXPMin,dXPMax,stOpt.Grid(2));
            stReturn.Count  = iLen*iMin;
            
        end % function
    
        function aReturn = MomentumToEnergy(obj, aMomentum)
            
            if obj.Species.isBeam
                dRQM = obj.Data.Config.Variables.Beam.(obj.Species.Name).RQM;
            elseif obj.Species.isPlasma
                dRQM = obj.Data.Config.Variables.Plasma.(obj.Species.Name).RQM;
            else
                fprintf(2,'Error: Unknown species type.\n');
                return;
            end % if

            dEMass  = obj.Data.Config.Variables.Constants.ElectronMassMeV*1e6;
            dPFac   = abs(dRQM)*dEMass;
            aReturn = sqrt(aMomentum.^2 + 1)*dPFac;
            
        end % function

    end % methods

end % classdef