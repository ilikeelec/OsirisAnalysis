
%
%  Class Object :: Analyse Fields
% ********************************
%  SubClass of OsirisType
%
%  Description:
%    A class to analyse and handle Osiris data related to electric fields.
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
%    Density  : Returns a dataset with a 2D matrix of the density of the field.
%    Lineout  : Returns a dataset with a 1D lineout of the density of the field.
%    Integral : Returns a dataset with the integrated field over an interval
%               of time dumps.
%

classdef Field < OsirisType

    %
    % Properties
    %

    properties(GetAccess='public', SetAccess='private')
        
        FieldVar  = {};  % Holds field information
        FieldFac  = 1.0; % Field scale factor
        FieldUnit = 'N'; % Field base unit
        
    end % properties

    %
    % Constructor
    %

    methods
        
        function obj = Field(oData, sField, varargin)
            
            % Call OsirisType constructor
            obj@OsirisType(oData, '', varargin{:});

            % Set Field
            stField = obj.Translate.Lookup(sField);
            if stField.isValidEMFDiag
                obj.FieldVar = stField;
            else
                fprintf(2, 'Error: ''%s'' is not a recognised field. Using ''e1'' instead.\n', sField);
                obj.FieldVar = obj.Translate.Lookup('e1');
            end % if
            
            if strcmpi(obj.Units,'SI')
                if obj.FieldVar.isEField
                    obj.FieldFac  = obj.Data.Config.Convert.SI.E0;
                    obj.FieldUnit = 'eV';
                end % if
                if obj.FieldVar.isBField
                    obj.FieldFac  = obj.Data.Config.Convert.SI.B0;
                    obj.FieldUnit = 'T';
                end % if
            end % if
            
        end % function
        
    end % methods

    %
    % Public Methods
    %
    
    methods(Access = 'public')
        
        function stReturn = Density2D(obj)

            % Input/Output
            stReturn = {};

            % Get data and axes
            aData   = obj.Data.Data(obj.Time, 'FLD', obj.FieldVar.Name, '');
            aX1Axis = obj.fGetBoxAxis('x1');
            aX2Axis = obj.fGetBoxAxis('x2');

            % Check if cylindrical
            if obj.Cylindrical
                if obj.FieldVar.Dim == 3
                    aData = transpose([-fliplr(aData),aData]);
                else
                    aData = transpose([fliplr(aData),aData]);
                end % if
                aX2Axis = [-fliplr(aX2Axis), aX2Axis];
            else
                aData = transpose(aData);
            end % if
            
            iX1Min = fGetIndex(aX1Axis, obj.X1Lim(1)*obj.AxisFac(1));
            iX1Max = fGetIndex(aX1Axis, obj.X1Lim(2)*obj.AxisFac(1));
            iX2Min = fGetIndex(aX2Axis, obj.X2Lim(1)*obj.AxisFac(2));
            iX2Max = fGetIndex(aX2Axis, obj.X2Lim(2)*obj.AxisFac(2));
            
            % Crop and scale dataset
            aData   = aData(iX2Min:iX2Max,iX1Min:iX1Max)*obj.FieldFac;
            aX1Axis = aX1Axis(iX1Min:iX1Max);
            aX2Axis = aX2Axis(iX2Min:iX2Max);
            
            % Return data
            stReturn.Data   = aData;
            stReturn.X1Axis = aX1Axis;
            stReturn.X2Axis = aX2Axis;
            stReturn.ZPos   = obj.fGetZPos();        
        
        end % function

        function stReturn = Lineout(obj, iStart, iAverage)

            % Input/Output
            stReturn = {};
            
            if nargin < 3
                iAverage = 1;
            end % if
            
            if nargin < 2
                iStart = 3;
            end % if
            
            % Get data and axes
            aData   = obj.Data.Data(obj.Time, 'FLD', obj.FieldVar.Name, '');
            aX1Axis = obj.fGetBoxAxis('x1');
            aX2Axis = obj.fGetBoxAxis('x2');
            
            iX1Min = fGetIndex(aX1Axis, obj.X1Lim(1)*obj.AxisFac(1));
            iX1Max = fGetIndex(aX1Axis, obj.X1Lim(2)*obj.AxisFac(1));
            
            % Crop and scale dataset
            iEnd    = iStart+iAverage-1;
            aData   = transpose(mean(aData(iX1Min:iX1Max,iStart:iEnd),2))*obj.FieldFac;
            aX1Axis = aX1Axis(iX1Min:iX1Max);
            
            % Return data
            stReturn.Data    = aData;
            stReturn.X1Axis  = aX1Axis;
            stReturn.X1Range = obj.AxisRange(1:2);
            stReturn.X2Range = [aX2Axis(iStart) aX2Axis(iEnd+1)];
            stReturn.ZPos    = obj.fGetZPos();        
        
        end % function
        
        function stReturn = Integral(obj, sStart, sStop, aRange)

            % Input/Output
            stReturn = {};

            if nargin < 2
                sStart = 'PStart';
            end % if

            if nargin < 3
                sStop = 'End';
            end % if

            if nargin < 4
                aRange = [];
            end % if

            iStart = obj.Data.StringToDump(sStart);
            iStop  = obj.Data.StringToDump(sStop);

            % Get simulation variables
            dTFac = obj.Data.Config.Convert.SI.TimeFac;
            dLFac = obj.Data.Config.Convert.SI.LengthFac;
            
            % Set axes
            aVAxis = [];
            aRAxis = [];
            aVLim  = [];
            sVUnit = 'N';
            sTUnit = 'm';

            switch(obj.FieldVar.Dim)

                case 1
                    dVFac  = obj.AxisFac(1);
                    sVUnit = obj.AxisUnits{1};
                    aVAxis = obj.fGetBoxAxis('x1');
                    aRAxis = obj.fGetBoxAxis('x2');
                    aVLim  = [fGetIndex(aVAxis, obj.X1Lim(1)*obj.AxisFac(1)) ...
                              fGetIndex(aVAxis, obj.X1Lim(2)*obj.AxisFac(1))];
                    
                    if isempty(aRange) || ~length(aRange) == 2
                        aRange = [3 3];
                    else
                        if aRange(1) < 1
                            aRange(1) = 1;
                        end % if
                        if aRange(2) > length(aRAxis)
                            aRange(2) = length(aRAxis);
                        end % if
                    end % if

                case 2
                    dVFac  = obj.AxisFac(2);
                    sVUnit = obj.AxisUnits{2};
                    aVAxis = obj.fGetBoxAxis('x2');
                    aRAxis = obj.fGetBoxAxis('x1');
                    aVLim  = [fGetIndex(aVAxis, obj.X2Lim(1)*obj.AxisFac(2)) ...
                              fGetIndex(aVAxis, obj.X2Lim(2)*obj.AxisFac(2))];

                    if isempty(aRange) || ~length(aRange) == 2
                        aRange = [1 10];
                    else
                        if aRange(1) < 1
                            aRange(1) = 1;
                        end % if
                        if aRange(2) > length(aRAxis)
                            aRange(2) = length(aRAxis);
                        end % if
                    end % if
                    
                case 3
                    return;

            end % switch
            
            aTAxis  = obj.fGetTimeAxis;
            aTAxis  = aTAxis(iStart+1:iStop+1);
            dTDiff  = aTAxis(end)-aTAxis(1);
            aVRange = [aVAxis(1) aVAxis(end)];
            aVAxis  = aVAxis(aVLim(1):aVLim(2));
            
            % Extract data
            aEnergy = zeros(length(aVAxis),length(aTAxis));
            for t=iStart:iStop
                
                aData = obj.Data.Data(t,'FLD',obj.FieldVar.Name,'');
                switch(obj.FieldVar.Name)
                    case 'e1'
                        aEnergy(:,t-iStart+1) = mean(aData(aVLim(1):aVLim(2),aRange(1):aRange(2)),2);
                    case 'e2'
                        aEnergy(:,t-iStart+1) = mean(aData(aRange(1):aRange(2),aVLim(1):aVLim(2)),1);
                end % switch
                
            end % for

            % Return data
            stReturn.Energy    = aEnergy*obj.FieldFac;
            stReturn.Integral  = cumtrapz(aEnergy,2)*obj.FieldFac*dTFac*dLFac;
            stReturn.GainFac   = 1/dTDiff;
            stReturn.VAxis     = aVAxis;
            stReturn.TAxis     = aTAxis;
            stReturn.VUnit     = sVUnit;
            stReturn.TUnit     = sTUnit;
            stReturn.AxisFac   = [1.0 dVFac];
            stReturn.AxisRange = [iStart iStop aVRange];
        
        end % function
        
    end % methods

end % classdef