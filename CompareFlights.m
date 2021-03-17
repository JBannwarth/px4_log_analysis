function CompareFlights( flogs, legendStr, xVals, xLabel )
%COMPAREFLIGHTS Compare response and metrics for several flights.
%   COMPAREFLIGHTS( FLOGS ) compares the flight logs contained in FLOGS.
%   COMPAREFLIGHTS( FLOGS, LEGENDSTR ) specifies the flight log legend.
%   COMPAREFLIGHTS( FLOGS, LEGENDSTR, XVALS ) specifies the x-axis value for each log.
%   COMPAREFLIGHTS( FLOGS, LEGENDSTR, XVALS, XLABEL ) specifies the x-axis label.
%
%   Inputs:
%       - flogs:     1-D cell array of flight logs. Note: flights are
%                    assumed to be cropped as desired before being passed
%                    to this function. In addition, they need to be
%                    resampled with matching timestamps.
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
    % Calculate metrics
    metrics = CalculateHoverMetrics( flogs );
    
    % Assign arrays for time responses
    pos   = cell( nLog, 1 );
    posSp = cell( nLog, 1 );
    att   = cell( nLog, 1 );
    attSp = cell( nLog, 1 );
    mode  = cell( nLog, 1 );

    % Process timeseries data
    for ii = 1:nLog
        % Get important data
        mode{ii}  = flogs{ii}.vehicle_control_mode;
        pos{ii}   = flogs{ii}.vehicle_local_position;
        posSp{ii} = flogs{ii}.vehicle_local_position_setpoint;
        att{ii}   = flogs{ii}.vehicle_attitude;
        attSp{ii} = flogs{ii}.vehicle_attitude_setpoint;

        % Add euler attitude
        [ att{ii}.roll_body, att{ii}.pitch_body, att{ii}.yaw_body ] = QuatToEuler( att{ii}.q );

        % Convert to degrees
        axs = { 'roll_body', 'pitch_body', 'yaw_body' };
        for jj = 1:length( axs )
            attSp{ii}.(axs{jj}) = rad2deg( attSp{ii}.(axs{jj}) );
            att{ii}.(axs{jj})   = rad2deg( att{ii}.(axs{jj}) );
        end
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
        plot( xVals, metrics.rmsPosErr(:,ii), lineStyles{ii} )
    end
    plot( xVals, metrics.rmsPosErrNorm, lineStyles{4} )
    ylabel( 'Position RMS error (m)' )
    legend( {'x', 'y', 'z', 'L2 norm' }, 'location', 'best' )
    if useIdentifier
        AddXTickLabels( legendStr )
    end

    % Attitude
    nexttile; hold on; grid on; box on
    for ii = 1:3
        plot( xVals, metrics.rmsAttErr(:,ii), lineStyles{ii} )
    end
    plot( xVals, metrics.rmsqDist, lineStyles{4} )
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
        plot( xVals, metrics.maxPosErr(:,ii), lineStyles{ii} )
    end
    plot( xVals, metrics.maxPosErrNorm, lineStyles{4} )
    ylabel( 'Maximum position error (m)' )
    legend( {'x', 'y', 'z', 'L2 norm' }, 'location', 'best' )
    if useIdentifier
        AddXTickLabels( legendStr )
    end

    % Attitude
    nexttile; hold on; grid on; box on
    for ii = 1:3
        plot( xVals, metrics.maxAttErr(:,ii), lineStyles{ii} )
    end
    plot( xVals, metrics.maxqDist, lineStyles{4} )
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
        plot( xVals, metrics.avgPosErr(:,ii), lineStyles{ii} )
    end
    plot( xVals, metrics.avgPosErrNorm, lineStyles{4} )
    ylabel( 'Mean position error (m)' )
    legend( {'x', 'y', 'z', 'L2 norm'}, 'location', 'best' )
    if useIdentifier
        AddXTickLabels( legendStr )
    end

    % Attitude
    nexttile; hold on; grid on; box on
    for ii = 1:3
        plot( xVals, metrics.avgAtt(:,ii), lineStyles{ii} )
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