function metrics = CalculateHoverMetrics( flogs, flightLen )
%CALCULATEHOVERMETRICS Calculate hover performance metrics.
%   METRICS = CALCULATEHOVERMETRICS( FLOGS ) calculates metrics for logs in FLOGS.
%   METRICS = CALCULATEHOVERMETRICS( FLOGS, FLIGHTLEN ) specifies the length of flight to analyse in seconds.
%
%   Inputs:
%       - flogs:     Individual flight log, cell array of flight log (i.e.
%                    a group), or a cell array of groups.
%       - flightLen: Length of time-period to analyse in seconds. It is
%                    assumed that the analysis period ends when the
%                    OFFBOARD flight mode is switched off for the last time
%                    in the current flight log.
%   Outputs:
%       - metrics:   Table of performance metrics for each log, with group
%                    identifier and group categoricals.
%
%   See also COMPAREFLIGHTS.
%
%   Written: 2021/03/16, J.X.J. Bannwarth

    arguments
        flogs
        flightLen (1,1) double = 150 % seconds
    end
    
    %% Input processing
    % Convert individual log and or standalone group into the same format as cell
    % arrays of groups to simplify subsequent code
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
    varNames = { 'group', 'identifier', 'avgPosErr', 'avgPosErrNorm', ...
        'rmsPosErr', 'rmsPosErrNorm', 'maxPosErr', 'maxPosNorm', 'avgAtt', ...
        'rmsAttErr', 'rmsqDist', 'maxqDist', 'maxAttErr', 'fileName' }';
    varTypes = { 'categorical', 'categorical', 'double', 'double', ...
        'double', 'double', 'double', 'double', 'double', ...
        'double', 'double', 'double', 'double', 'string' }';
    varUnits = { '', '', 'm', 'm', 'm', 'm', 'm', 'm', 'deg', 'deg', ...
        'deg', 'deg', 'deg', '' };
    
    % Create table
    metrics = table( 'Size', [nLogs 14], 'VariableNames', varNames, ...
        'VariableTypes', varTypes );
    metrics.Properties.VariableUnits = varUnits;
    
    % Cannot set dimensions right away, so go through and change column
    % dimensions
    isTriplet = ~contains( varNames, {'Norm', 'qDist'} ) & ...
        strcmp( varTypes, 'double' ) ;
    for ii = 1:length( varNames )
        if isTriplet(ii)
            metrics.(varNames{ii}) = zeros( nLogs, 3 );
        end
    end
    
    %% Compute metrics
    idx = 1;
    for ii = 1:length( flogs )
        for jj = 1:length( flogs{ii} )
             % Get important data
            mode  = flogs{ii}{jj}.vehicle_control_mode;
            pos   = flogs{ii}{jj}.vehicle_local_position;
            posSp = flogs{ii}{jj}.vehicle_local_position_setpoint;
            att   = flogs{ii}{jj}.vehicle_attitude;
            attSp = flogs{ii}{jj}.vehicle_attitude_setpoint;

            % Select columns of interest
            pos = pos(:, matches( pos.Properties.VariableNames, ...
                { 'x', 'y', 'z', 'vx', 'vy', 'vz' } ) );
            posSp = posSp(:, matches( posSp.Properties.VariableNames, ...
                { 'x', 'y', 'z', 'vx', 'vy', 'vz' } ) );
            att = att(:, matches( att.Properties.VariableNames, ...
                { 'rollspeed', 'pitchspeed', 'yawspeed', 'q' } ) );
            attSp = attSp(:, matches( attSp.Properties.VariableNames, ...
                { 'roll_body', 'pitch_body', 'yaw_body', 'q_d' } ) );

            % Add euler attitude
            [ att.roll_body, att.pitch_body, att.yaw_body ] = QuatToEuler( att.q );

            % Convert to degrees
            axs = { 'roll_body', 'pitch_body', 'yaw_body' };
            for kk = 1:length( axs )
                attSp.(axs{kk}) = rad2deg( attSp.(axs{kk}) );
                att.(axs{kk})   = rad2deg( att.(axs{kk}) );
            end

            % Find exit from offboard mode
            idxEnd = find( mode.flag_control_offboard_enabled, 1, 'last' );
            tEnd = mode.timestamp( idxEnd );
            tStart = tEnd - seconds(flightLen);

            % Extract the range of data we care about and resample
            dt = 1 / 10;
            pos   = CropTimetable( pos  , tStart, tEnd, dt );
            posSp = CropTimetable( posSp, tStart, tEnd, dt );
            att   = CropTimetable( att  , tStart, tEnd, dt );
            attSp = CropTimetable( attSp, tStart, tEnd, dt );

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
            
            % Fill table
            metrics.group(idx)         = flogs{ii}{jj}.group;
            metrics.identifier(idx)    = flogs{ii}{jj}.identifier(1:end-3);
            metrics.avgPosErr(idx,:)   = mean( posErr, 1 );
            metrics.avgPosErrNorm(idx) = mean( posErrNorm );
            metrics.rmsPosErr(idx,:)   = rms( posErr, 1 );
            metrics.rmsPosErrNorm(idx) = rms( posErrNorm );
            metrics.maxPosErr(idx,:)   = max( abs(posErr), [], 1 );
            metrics.maxPosNorm(idx)    = max( posErrNorm );
            metrics.avgAtt(idx,:)      = avgAtt;
            metrics.rmsAttErr(idx,:)   = rms( attErr, 1 );
            metrics.maxqDist(idx)      = rad2deg( max( qDist ) );
            metrics.maxAttErr(idx,:)   = max( abs(attErr), [], 1 );
            metrics.rmsqDist(idx)      = rad2deg( rms( qDist ) );
            metrics.fileName(idx)      = flogs{ii}{jj}.filename;
            
            idx = idx+1;
        end
    end
    
end

%% Helper function
function T = CropTimetable( T, tStart, tEnd, dt )
    T = T( T.timestamp <= tEnd & T.timestamp >= tStart, : );
    tResample = round(tStart/dt)*dt:seconds(dt):round(tEnd/dt)*dt;
    T = retime( T, tResample, 'linear' );
    T.timestamp = T.timestamp - T.timestamp(1);
    T.t = seconds( T.timestamp );
end