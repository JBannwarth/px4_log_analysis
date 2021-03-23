function metrics = CalculateHoverMetrics( flogs )
%CALCULATEHOVERMETRICS Calculate hover performance metrics.
%   METRICS = CALCULATEHOVERMETRICS( FLOGS ) calculates metrics for logs in FLOGS.
%
%   Inputs:
%       - flogs:     Individual flight log, cell array of flight log (i.e.
%                    a group), or a cell array of groups. Note: the logs
%                    are assumed to have been cropped and resampled prior
%                    to being passed to this function.
%   Outputs:
%       - metrics:   Table of performance metrics for each log, with group
%                    identifier and group categoricals.
%
%   See also COMPAREFLIGHTS.
%
%   Written: 2021/03/16, J.X.J. Bannwarth

    arguments
        flogs
    end
    
    %% Input processing
    % Convert individual log and or standalone group into the same format
    % as cell arrays of groups to simplify subsequent code
    if ~iscell(flogs)
        % Individual log
        flogs = {{flogs}};
        isIndividual = true;
    elseif ~iscell(flogs{1})
        % Standalone group
        flogs = {flogs};
        isIndividual = false;
    else
        % Array of groups
        isIndividual = false;
    end
    
    nLogs = sum( cellfun( @(x)( length(x) ), flogs ) );
    
    %% Initialize output table
    % Table column properties
    varDefs = { ...
        'identifier'   , 'string'     , ''   ;
        'group'        , 'categorical', ''   ;
        'xLabel'       , 'categorical', ''   ;
        'avgPosErr'    , 'double'     , 'm'  ;
        'avgPosErrNorm', 'double'     , 'm'  ;
        'rmsPosErr'    , 'double'     , 'm'  ;
        'rmsPosErrNorm', 'double'     , 'm'  ;
        'maxPosErr'    , 'double'     , 'm'  ;
        'maxPosErrNorm', 'double'     , 'm'  ;
        'avgAtt'       , 'double'     , 'deg';
        'rmsAttErr'    , 'double'     , 'deg';
        'rmsqDist'     , 'double'     , 'deg';
        'maxqDist'     , 'double'     , 'deg';
        'maxAttErr'    , 'double'     , 'deg';
        'avgPwm'       , 'double'     , 'us' ;
        'rmsPwm'       , 'double'     , 'us' ;
        'maxPwm'       , 'double'     , 'us' ;
        'minPwm'       , 'double'     , 'us' ;
        'fileName'     , 'string'     , ''   ;
        };
    
    % Create table
    metrics = table( 'Size', [nLogs size(varDefs, 1)], ...
        'VariableNames', varDefs(:,1), 'VariableTypes', varDefs(:,2) );
    metrics.Properties.VariableUnits = varDefs(:,3);
    
    % Cannot set dimensions right away, so go through and change column
    % dimensions
    isTriplet = ~contains( varDefs(:,1), {'Norm', 'qDist', 'Pwm'} ) & ...
        strcmp( varDefs(:,2), 'double' ) ;
    isOctuplet = contains( varDefs(:,1), 'Pwm' );
    for ii = 1:length( varDefs(:,1) )
        if isTriplet(ii)
            metrics.(varDefs{ii,1}) = zeros( nLogs, 3 );
        elseif isOctuplet(ii)
            metrics.(varDefs{ii,1}) = zeros( nLogs, 8 );
        end
    end
    
    %% Compute metrics
    idx = 1;
    for ii = 1:length( flogs )
        for jj = 1:length( flogs{ii} )
            % Get important data
            pos   = flogs{ii}{jj}.vehicle_local_position;
            posSp = flogs{ii}{jj}.vehicle_local_position_setpoint;
            att   = flogs{ii}{jj}.vehicle_attitude;
            attSp = flogs{ii}{jj}.vehicle_attitude_setpoint;
            act   = flogs{ii}{jj}.actuator_outputs;
            ctrls = flogs{ii}{jj}.actuator_controls_0;

            % Calculate position error
            posErr = [posSp.x posSp.y posSp.z] - [pos.x pos.y pos.z];
            posErrNorm = sqrt( sum( posErr.^2, 2 ) );
            
            % Calculate attitude error
            q     = quaternion( att.q );
            qDes  = quaternion( attSp.q_d );
            qErr  = conj(q) .* qDes;
            qDist = dist( q, qDes );
            attErr = eulerd( qErr, 'ZYX', 'frame' );
            attErr = attErr(:,[3 2 1]); % Switch to [roll pitch yaw]
            avgAtt = eulerd( meanrot(q), 'ZYX', 'frame' );
            avgAtt = avgAtt(:,[3 2 1]); % Switch to [roll pitch yaw]
            
            % Calculate actuator usage
            pwm = act.output(:,1:act.noutputs(1));
            
            % Get hover throttle
            thrust = ctrls.control(:,4);
            
            % Fill table
            % Sorting columns
            if isIndividual
                metrics.group(idx)     = 'NA';
                metrics.xLabel(idx)    = 'NA';
                metrics.identifier(idx)= 'NA';
            else
                metrics.group(idx)     = flogs{ii}{jj}.group;
                metrics.xLabel(idx)    = flogs{ii}{jj}.identifier(1:end-3);
                metrics.identifier(idx)= flogs{ii}{jj}.identifier;
            end
            
            % Position columns
            metrics.avgPosErr(idx,:)   = mean( posErr, 1 );
            metrics.avgPosErrNorm(idx) = mean( posErrNorm );
            metrics.rmsPosErr(idx,:)   = rms( posErr, 1 );
            metrics.rmsPosErrNorm(idx) = rms( posErrNorm );
            metrics.maxPosErr(idx,:)   = max( abs(posErr), [], 1 );
            metrics.maxPosErrNorm(idx) = max( posErrNorm );
            
            % Attitude columns
            metrics.avgAtt(idx,:)      = avgAtt;
            metrics.rmsAttErr(idx,:)   = rms( attErr, 1 );
            metrics.maxqDist(idx)      = rad2deg( max( qDist ) );
            metrics.maxAttErr(idx,:)   = max( abs(attErr), [], 1 );
            metrics.rmsqDist(idx)      = rad2deg( rms( qDist ) );
            
            % Actuator usage columns
            metrics.avgPwm(idx,:)      = mean( pwm, 1 );
            metrics.rmsPwm(idx,:)      = rms( pwm - mean( pwm, 1 ), 1 );
            metrics.minPwm(idx,:)      = min( pwm, [], 1 );
            metrics.maxPwm(idx,:)      = max( pwm, [], 1 );
            
            % Thrust column
            metrics.avgThrust(idx,:)   = mean( thrust );
            
            % Extra columns
            metrics.fileName(idx)      = [flogs{ii}{jj}.filename '.ulg'];
            
            idx = idx+1;
        end
    end 
end