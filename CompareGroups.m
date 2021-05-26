function CompareGroups( flogs, options )
%COMPAREGROUPS Compare hover metrics between different groups of logs.
%   COMPAREGROUPS( FLOGS ) compares performance metrics for log groups in FLOGS.
%   COMPAREGROUPS( FLOGS, OPTIONS ) specifies plotting options, described below.
%
%   Inputs:
%       - flogs:     1-D cell array of flight logs. Note: flights are
%                    assumed to be cropped as desired before being passed
%                    to this function. In addition, they need to be
%                    resampled with matching timestamps.
%       - options:   Name-value arguments. Available options:
%           > xVals:       Array of values for the x-axis of the metric
%                          plots. For example, if flogs contains flight
%                          results at different wind speeds, xVals can
%                          contain the mean wind speed for each log. By
%                          default, the x-axes of the metrics plots show
%                          the log identifier.
%           > xAxisLabel:  Description of the x-axis values. For example,
%                          in the above example, 'Wind speed (m/s)' would
%                          be appropriate.
%           > groupLegend: Cell array of legends for each group.
%
%   See also COMPAREFLIGHTS, CALCULATEHOVERMETRICS.
%
%   Written: 2021/03/17, J.X.J. Bannwarth

    arguments
        flogs                     cell
        options.xVals       (:,1) double  = nan
        options.xAxisLabel  (1,:) char    = ''
        options.groupLegend       cell    = {}
    end

    %% Input processing
    if isnan( options.xVals )
        useIdentifier = true;
    else
        useIdentifier = false;
    end

    %% Compute and process metrics
    % Compute metrics
    metrics = CalculateHoverMetrics( flogs );
    
    xLabels = string( unique( metrics.xLabel ) );
    if useIdentifier
        options.xVals = (1:length(xLabels))';
    end

    % Add x-values to table
    metrics.xVal = options.xVals( metrics.xLabel );
    
    % Legend and axes labels
    groups = string( unique( metrics.group ) );
    if isempty( options.groupLegend )
        options.groupLegend = replace( groups, '_', '\_' );
    end
    
    if length( options.groupLegend ) ~= length( groups )
        error( 'Not enough entries in groupLegend' )
    end
    
    %% Plot metrics
    % Position metrics
    PlotMetrics3( metrics, 'rmsPosErr', options.xAxisLabel, options.groupLegend, useIdentifier )
    PlotMetrics3( metrics, 'maxPosErr', options.xAxisLabel, options.groupLegend, useIdentifier )
    
    % Attitude metrics
    PlotMetrics3( metrics, 'rmsAttErr', options.xAxisLabel, options.groupLegend, useIdentifier )
    PlotMetrics3( metrics, 'maxAttErr', options.xAxisLabel, options.groupLegend, useIdentifier )
    PlotMetrics3( metrics, 'avgAtt'   , options.xAxisLabel, options.groupLegend, useIdentifier )
    
    % PWM metrics
    PlotPWM( metrics, options.xAxisLabel, options.groupLegend, useIdentifier )
    
    % Hover thrust
    figure( 'name', 'Hover thrust' )
    tiledlayout( 1, 1, 'TileSpacing', 'compact', 'Padding', 'compact' );
    nexttile(1); hold on; grid on; box on
    markers = 'op^dvh';
    for ii = 1:length( groups )
        scatter( metrics(metrics.group==groups{ii},:).xVal, ...
            metrics(metrics.group==groups{ii},:).avgThrust.*100, ...
            markers(ii) )
    end
    xlabel( options.xAxisLabel )
    ylabel( 'Mean hover throttle (\%)' )
    ylim( [0 100] )
    legend( options.groupLegend, 'location', 'best' )
    if useIdentifier
        xticks( 1:length(xLabels) )
        xticklabels( xLabels )
    end
end

%% Helper
function PlotPWM( metrics, xAxisLabel, groupLegend, useIdentifier )
%PLOTPWM Plot PWM metrics
    % Get group names and identifiers
    groups = unique( metrics.group );
    xLabels = string( unique( metrics.xLabel ) );
    
    figure( 'name', 'PWM metrics' )
    markers = 'op^dvh';
    tiledlayout( 4, 1, 'TileSpacing', 'compact', 'Padding', 'compact' );
    
    fieldNames = { 'avgPwm', 'rmsPwm', 'minPwm', 'maxPwm' };
    labelNames = { 'Average', 'RMS' , 'Min', 'Max' };
    
    for ii = 1:length( fieldNames )
        nexttile(ii); hold on; grid on;  box on
        for jj = 1:length( groups )
            vals = metrics(metrics.group==groups(jj),:).(fieldNames{ii});
            switch fieldNames{ii}
                case 'minPwm'
                    vals = min( vals, [], 2 );
                case 'maxPwm'
                    vals = max( vals, [], 2 );
                otherwise
                    vals = mean( vals, 2 );
            end
            scatter( metrics(metrics.group==groups(jj),:).xVal, ...
                vals, ...
                markers(jj) )
        end

        % Start at zero to give a better scale of the results
        if ~contains( fieldNames{ii}, 'rms' )
            ylim( [1000 2000] )
        end
        
        % Axis ticks and labels
        % Get unit
        idx = strcmp( metrics.Properties.VariableNames, fieldNames{ii} ) ;
        ylabel( sprintf( '%s PWM (%s)', labelNames{ii}, ... 
            metrics.Properties.VariableUnits{idx} ) )
        if useIdentifier
            xticks( 1:length(xLabels) )
            xticklabels( xLabels )
        end
    end
    
    % Formatting
    xlabel( xAxisLabel )
    legend( groupLegend, 'location', 'best' )
    linkaxes( [nexttile(1) nexttile(2) nexttile(3)], 'x' )
end

function PlotMetrics3( metrics, fieldName, xAxisLabel, groupLegend, useIdentifier )
%PLOTMETRICS3 Plot a 3-axis group of metrics.
    % Get group names and identifiers
    groups = unique( metrics.group );
    xLabels = string( unique( metrics.xLabel ) );
    
    % Select axes labels and create figure title
    varType = fieldName(1:3);
    varType(1) = upper(varType(1));
    if contains( fieldName, 'Att' )
        axs = {'roll', 'pitch', 'yaw'};
        varCat = 'angle';
    else
        axs = {'x', 'y', 'z'};
        varCat = 'position';
    end
    
    if contains( fieldName, 'Err' )
        suffix = ' error';
    else
        suffix = '';
    end
    
    % Initialise table
    figure( 'name', [ varType ' ' suffix ] )
    markers = 'op^dvh';
    tiledlayout( 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact' );
    
    % Plot each axis
    for ii = 1:length(axs)
        nexttile( ii ); hold on; grid on; box on
        
        % Plot each group
        for jj = 1:length( groups )
            scatter( metrics(metrics.group==groups(jj),:).xVal, ...
                metrics(metrics.group==groups(jj),:).(fieldName)(:,ii), ...
                markers(jj) )
        end
        
        % Start at zero to give a better scale of the results
        if min( metrics.(fieldName)(:,ii) ) > 0
            ylim( [0, max(metrics.(fieldName)(:,ii))*1.2 ] )
        end
        
        % Axis ticks and labels
        % Get unit
        idx = strcmp( metrics.Properties.VariableNames, fieldName ) ;
        ylabel( sprintf( '%s %s %s (%s)', varType, axs{ii}, ...
            suffix, metrics.Properties.VariableUnits{idx} ) )
        if useIdentifier
            xticks( 1:length(xLabels) )
            xticklabels( xLabels )
        end
    end
    
    % Formatting
    xlabel( xAxisLabel )
    legend( groupLegend, 'location', 'best' )
    linkaxes( [nexttile(1) nexttile(2) nexttile(3)], 'x' )
end