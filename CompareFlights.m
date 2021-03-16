function CompareFlights( flogs, flightLen, legendStr, xVals, xLabel )
%COMPAREFLIGHTS Compare response and metrics for several flights.
%   COMPAREFLIGHTS( FLOGS ) compares the flight logs contained in FLOGS.
%   COMPAREFLIGHTS( FLOGS, FLIGHTLEN ) specifies the length of the flight in seconds.
%   COMPAREFLIGHTS( FLOGS, FLIGHTLEN, LEGENDSTR ) specifies the flight log legend.
%   COMPAREFLIGHTS( FLOGS, FLIGHTLEN, LEGENDSTR, XVALS ) specifies the x-axis value for each log.
%   COMPAREFLIGHTS( FLOGS, FLIGHTLEN, LEGENDSTR, XVALS, XLABEL ) specifies the x-axis label.
%
%   Inputs:
%       - flogs:     1-D cell array of flight logs.
%       - flightLen: Length of time-period to analyse in seconds. It is
%                    assumed that the analysis period ends when the
%                    OFFBOARD flight mode is switched off for the last time
%                    in the current flight log.
%       - legendStr: Cell array of strings describing each flight log.
%       - xVals:     Array of values for the x-axis of the metric plots.
%                    For example, if flogs contains flight results at
%                    different wind speeds, xVals can contain the mean wind
%                    speed for each log. By default, the x-axes of the
%                    metrics plots show the log identifier.
%       - xLabel:    Description of the x-axis values. For example, in the
%                    above example, 'Wind speed (m/s)' would be appropriate.
%
%   See also FLIGHTOVERVIEW, COMPAREPOSITIONSENSORS, LOADLOGGROUP.
%
%   Written: 2021/03/11, J.X.J. Bannwarth

    arguments
        flogs           cell
        flightLen (1,1) double  = 150 % seconds
        legendStr       cell    = {}
        xVals     (:,1) double  = nan
        xLabel    (1,:) char    = ''
    end

    %% Input processing
    % Give warning if the input contains more than one group, and only
    % process the first one
    if iscell(flogs{1})
        warning( [ 'This function can only process one group of ', ...
                   'logs at a time. Processing first group only.' ] )
        flogs = flogs{1};
    end
    
    nLog = length( flogs );
    
    % Simply use the log identifiers
    if isempty( legendStr )
        legendStr = cell( nLog, 1 );
        for ii = 1:nLog
            legendStr{ii} = replace( flogs{ii}.identifier, '_', '\_' );
        end
    end
    
    % If the x-axis values are not provided, simply use the identifiers for
    % the x-axis labels
    if isnan( xVals )
        xVals = 1:nLog;
        useIdentifier = true;
    else
        useIdentifier = false;
    end

    %% Get information of interest
    % Assign arrays
    pos   = cell( nLog, 1 );
    posSp = cell( nLog, 1 );
    att   = cell( nLog, 1 );
    attSp = cell( nLog, 1 );
    mode  = cell( nLog, 1 );
    meanPosErr = zeros( nLog, 3 );
    meanAtt    = zeros( nLog, 3 );
    rmsPosErr  = zeros( nLog, 3 );
    rmsAttErr  = zeros( nLog, 3 );
    maxPosErr  = zeros( nLog, 3 );
    maxAttErr  = zeros( nLog, 3 );
    maxPosNorm = zeros( nLog, 1 );
    maxqDist   = zeros( nLog, 1 );
    rmsPosNorm = zeros( nLog, 1 );
    rmsqDist   = zeros( nLog, 1 );

    % Process data
    for ii = 1:nLog
        % Get important data
        mode{ii}  = flogs{ii}.vehicle_control_mode;
        pos{ii}   = flogs{ii}.vehicle_local_position;
        posSp{ii} = flogs{ii}.vehicle_local_position_setpoint;
        att{ii}   = flogs{ii}.vehicle_attitude;
        attSp{ii} = flogs{ii}.vehicle_attitude_setpoint;

        % Select columns of interest
        pos{ii} = pos{ii}(:, matches( pos{ii}.Properties.VariableNames, ...
            { 'x', 'y', 'z', 'vx', 'vy', 'vz' } ) );
        posSp{ii} = posSp{ii}(:, matches( posSp{ii}.Properties.VariableNames, ...
            { 'x', 'y', 'z', 'vx', 'vy', 'vz' } ) );
        att{ii} = att{ii}(:, matches( att{ii}.Properties.VariableNames, ...
            { 'rollspeed', 'pitchspeed', 'yawspeed', 'q' } ) );
        attSp{ii} = attSp{ii}(:, matches( attSp{ii}.Properties.VariableNames, ...
            { 'roll_body', 'pitch_body', 'yaw_body', 'q_d' } ) );

        % Add euler attitude
        [ att{ii}.roll_body, att{ii}.pitch_body, att{ii}.yaw_body ] = QuatToEuler( att{ii}.q );

        % Convert to degrees
        axs = { 'roll_body', 'pitch_body', 'yaw_body' };
        for jj = 1:length( axs )
            attSp{ii}.(axs{jj}) = rad2deg( attSp{ii}.(axs{jj}) );
            att{ii}.(axs{jj})   = rad2deg( att{ii}.(axs{jj}) );
        end

        % Find exit from offboard mode
        idxEnd = find( mode{ii}.flag_control_offboard_enabled, 1, 'last' );
        tEnd = mode{ii}.timestamp( idxEnd );
        tStart = tEnd - seconds(flightLen);

        % Extract the range of data we care about and resample
        dt = 1 / 10;
        pos{ii}   = CropTimetable( pos{ii}  , tStart, tEnd, dt );
        posSp{ii} = CropTimetable( posSp{ii}, tStart, tEnd, dt );
        att{ii}   = CropTimetable( att{ii}  , tStart, tEnd, dt );
        attSp{ii} = CropTimetable( attSp{ii}, tStart, tEnd, dt );

        % Calculate position metrics
        posErr = [posSp{ii}.x posSp{ii}.y posSp{ii}.z] - ...
            [pos{ii}.x pos{ii}.y pos{ii}.z];
        posErrNorm = sqrt( sum( posErr.^2, 2 ) );
        meanPosErr(ii,:) = mean( posErr, 1 );

        rmsPosErr(ii,:) = rms( posErr, 1 );
        rmsPosNorm(ii)  = rms( posErrNorm );

        maxPosErr(ii,:) = max( abs(posErr), [], 1 );
        maxPosNorm(ii)  = max( posErrNorm );

        % Calculate attitude metrics
        q    = quaternion( att{ii}.q );
        qDes = quaternion( attSp{ii}.q_d );
        qErr = conj(q) .* qDes;

        attErr = eulerd( qErr, 'ZYX', 'frame' );

        meanAtt(ii,:) = eulerd( meanrot( q ), 'ZYX', 'frame' );

        rmsAttErr(ii,:) = rms( attErr, 1 );
        rmsqDist(ii)    = rad2deg( rms( dist( q, qDes ) ) );

        maxAttErr(ii,:) = max( abs(attErr), [], 1 );
        maxqDist(ii)    = rad2deg( max( dist( q, qDes ) ) );
    end

    %% Plot responses
    % Attitude
    figure( 'name', 'Attitude responses' )
    tiledlayout( 3, 1, 'TileSpacing', 'compact', 'Padding', 'tight' );
    axs = {'Roll', 'Pitch', 'Yaw'};
    for ii = 1:length( flogs )
        for jj = 1:length( axs )
            nexttile( jj ); hold on; grid on; box on
            plot( att{ii}.t, att{ii}.([lower(axs{jj}) '_body']) )
            ylabel( [ axs{jj} ' (deg)' ] )
        end
    end

    xlabel( 'Time (s)' )
    legend( legendStr )
    linkaxes( [nexttile(1) nexttile(2) nexttile(3)], 'x' )

    % Position
    figure( 'name', 'Position responses' )
    tiledlayout( 3, 1, 'TileSpacing', 'compact', 'Padding', 'tight' );
    axs = {'x', 'y', 'z'};
    for ii = 1:nLog
        for jj = 1:length( axs )
            nexttile( jj ); hold on; grid on; box on
            plot( pos{ii}.t, pos{ii}.(axs{jj}) )
            ylabel( [ axs{jj} ' position (m)' ] )
        end
    end

    xlabel( 'Time (s)' );
    legend( legendStr )
    linkaxes( [nexttile(1) nexttile(2) nexttile(3)], 'x' )

    %% Plot metrics
    % Format settings
    lineStyles = { '-o', '--s', '-.^', ':v' };

    % RMS metrics
    figure( 'name', 'RMS error' )
    tiledlayout( 2, 1, 'TileSpacing', 'compact', 'Padding', 'tight' );

    % Position
    nexttile; hold on; grid on; box on
    for ii = 1:3
        plot( xVals, rmsPosErr(:,ii), lineStyles{ii} )
    end
    plot( xVals, rmsPosNorm, lineStyles{4} )
    ylabel( 'Position RMS error (m)' )
    legend( {'x', 'y', 'z', 'L2 norm' }, 'location', 'best' )
    if useIdentifier
        AddXTickLabels( legendStr )
    end

    % Attitude
    nexttile; hold on; grid on; box on
    for ii = 1:3
        plot( xVals, rmsAttErr(:,ii), lineStyles{ii} )
    end
    plot( xVals, rmsqDist, lineStyles{4} )
    xlabel( xLabel )
    ylabel( 'Attitude RMS error (deg)' )
    legend( {'Roll', 'Pitch', 'Yaw', 'Dist'}, 'location', 'best' )
    linkaxes( [nexttile(1) nexttile(2)], 'x' )
    if useIdentifier
        AddXTickLabels( legendStr )
    end

    % Maximum metrics
    figure( 'name', 'Max error' )
    tiledlayout( 2, 1, 'TileSpacing', 'compact', 'Padding', 'tight' );

    % Position
    nexttile; hold on; grid on; box on
    for ii = 1:3
        plot( xVals, maxPosErr(:,ii), lineStyles{ii} )
    end
    plot( xVals, maxPosNorm, lineStyles{4} )
    ylabel( 'Maximum position error (m)' )
    legend( {'x', 'y', 'z', 'L2 norm' }, 'location', 'best' )
    if useIdentifier
        AddXTickLabels( legendStr )
    end

    % Attitude
    nexttile; hold on; grid on; box on
    for ii = 1:3
        plot( xVals, maxAttErr(:,ii), lineStyles{ii} )
    end
    plot( xVals, maxqDist, lineStyles{4} )
    xlabel( xLabel )
    ylabel( 'Maximum attitude error (deg)' )
    legend( {'Roll', 'Pitch', 'Yaw', 'Dist'}, 'location', 'best' )
    linkaxes( [nexttile(1) nexttile(2)], 'x' )
    if useIdentifier
        AddXTickLabels( legendStr )
    end

    % Mean values
    figure( 'name', 'Mean values' )
    tiledlayout( 2, 1, 'TileSpacing', 'compact', 'Padding', 'tight' );

    % Position
    nexttile; hold on; grid on; box on
    for ii = 1:3
        plot( xVals, meanPosErr(:,ii), lineStyles{ii} )
    end
    ylabel( 'Mean position (m)' )
    legend( {'x', 'y', 'z'}, 'location', 'best' )
    if useIdentifier
        AddXTickLabels( legendStr )
    end

    % Attitude
    nexttile; hold on; grid on; box on
    for ii = 1:3
        plot( xVals, meanAtt(:,ii), lineStyles{ii} )
    end
    xlabel( xLabel )
    ylabel( 'Mean attitude (deg)' )
    legend( {'Roll', 'Pitch', 'Yaw'}, 'location', 'best' )
    linkaxes( [nexttile(1) nexttile(2)], 'x' )
    if useIdentifier
        AddXTickLabels( legendStr )
    end
end

%% Helper
function AddXTickLabels( labels )
    xticks( 1:length(labels) )
    xticklabels( labels )
end

function T = CropTimetable( T, tStart, tEnd, dt )
    T = T( T.timestamp <= tEnd & T.timestamp >= tStart, : );
    tResample = round(tStart/dt)*dt:seconds(dt):round(tEnd/dt)*dt;
    T = retime( T, tResample, 'linear' );
    T.timestamp = T.timestamp - T.timestamp(1);
    T.t = seconds( T.timestamp );
end