function CompareGroups( flogs, xVals, xLabel, groupLegend )
%COMPAREGROUPS Compare hover metrics between different groups of logs.
%   COMPAREGROUPS( FLOGS )
%   COMPAREGROUPS( FLOGS, XVALS )
%   COMPAREGROUPS( FLOGS, XVALS, XLABEL )
%   COMPAREGROUPS( FLOGS, XVALS, XLABEL, groupLegend )
%
%   Inputs:
%       - flogs:     1-D cell array of flight logs. Note: flights are
%                    assumed to be cropped as desired before being passed
%                    to this function. In addition, they need to be
%                    resampled with matching timestamps.
%       - xVals:     Array of values for the x-axis of the metric plots.
%                    For example, if flogs contains flight results at
%                    different wind speeds, xVals can contain the mean wind
%                    speed for each log. By default, the x-axes of the
%                    metrics plots show the log identifier.
%       - xLabel:    Description of the x-axis values. For example, in the
%                    above example, 'Wind speed (m/s)' would be appropriate.
%
%   Written: 2021/03/17, J.X.J. Bannwarth

    arguments
        flogs             cell
        xVals       (:,1) double  = nan
        xLabel      (1,:) char    = ''
        groupLegend       cell    = {}
    end

    %% Input processing
    if isnan( xVals )
        useIdentifier = true;
    else
        useIdentifier = false;
    end

    %% Compute and process metrics
    % Compute metrics
    metrics = CalculateHoverMetrics( flogs );
    
    identifiers = string( unique( metrics.identifier ) );
    if useIdentifier
        xVals = (1:length(identifiers))';
    end

    % Add x-values to table
    metrics.xVal = xVals( metrics.identifier );
    
    % Legend and axes labels
    if isempty( groupLegend )
        groups      = string( unique( metrics.group ) );
        groupLegend = replace( groups, '_', '\_' );
    end
    
    if length( groupLegend ) ~= length( groups )
        error( 'Not enough entries in groupLegend' )
    end
    
    %% Plot metrics    
    PlotMetric3( metrics, 'rmsPosErr', 'RMS pos error (m)', xLabel, groupLegend, useIdentifier )
    PlotMetric3( metrics, 'maxPosErr', 'max pos error (m)', xLabel, groupLegend, useIdentifier )
    PlotMetric3( metrics, 'rmsAttErr', 'RMS att error (deg)', xLabel, groupLegend, useIdentifier )
    PlotMetric3( metrics, 'maxAttErr', 'RMS att error (deg)', xLabel, groupLegend, useIdentifier )
    PlotMetric3( metrics, 'avgAtt', '(deg)', xLabel, groupLegend, useIdentifier )
end
    
%% Helper
function PlotMetric3( metrics, metricName, metricLabel, xLabel, groupLegend, useIdentifier )
    groups = unique( metrics.group );
    identifiers = string( unique( metrics.identifier ) );
    figure( 'name', metricLabel )
    if contains( metricName, 'Att' )
        axs = {'Roll', 'Pitch', 'Yaw'};
    else
        axs = {'x', 'y', 'z'};
    end
    markers = 'op^dvh';
    tiledlayout( 3, 1, 'TileSpacing', 'compact', 'Padding', 'tight' );
    for ii = 1:3
        nexttile( ii ); hold on; grid on; box on
        for jj = 1:length( groups )
            scatter( metrics(metrics.group==groups(jj),:).xVal, ...
                metrics(metrics.group==groups(jj),:).(metricName)(:,ii), ...
                markers(jj) )
        end
        if min( metrics.(metricName)(:,ii) ) > 0
            ylim( [0, max(metrics.(metricName)(:,ii))*1.2 ] )
        end
        ylabel( [ axs{ii} ' ' metricLabel ] )
        if useIdentifier
            AddXTickLabels( identifiers )
        end
    end
    
    xlabel( xLabel )
    legend( groupLegend, 'location', 'best' )
    linkaxes( [nexttile(1) nexttile(2) nexttile(3)], 'x' )
end

function AddXTickLabels( labels )
    xticks( 1:length(labels) )
    xticklabels( labels )
end