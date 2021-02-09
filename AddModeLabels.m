%ADDMODELABELS Add mode transition labels to plot
%   Written: 2021/02/09, J.X.J. Bannwarth

% Add modes
xLims = xlim();
yLims = ylim();

labels = { 'OFFB'; 'POS'; 'ALT'; 'MANUAL' };
fields = { 'flag_control_offboard_enabled';
           'flag_control_position_enabled';
           'flag_control_altitude_enabled';
           'flag_control_manual_enabled' };
colors = { 'r', 'g', 'b', 'k' };
labelLocs = zeros( size( mode.(fields{1}) ) );

for ii = 1:length(fields)
    modeOnIdx = find( diff(mode.(fields{ii})) == 1 );
    modeOffIdx = find( diff(mode.(fields{ii})) == -1 );
    
    for jj = 1:length( modeOnIdx )
        if labelLocs( modeOnIdx(jj) ) ~= 1
            startLoc =  mode.timestamp(modeOnIdx(jj));
            plot( [startLoc startLoc], ...
                [yLims(1), yLims(2)], '--', 'color', colors{ii} )
            labelLocs( modeOnIdx(jj) ) = 1;
            h = text( startLoc+0.02*diff(xLims), ...
                yLims(1) + 0.05*diff(yLims), labels{ii}, 'FontSize', 8, ...
                'Color', colors{ii}, 'Rotation', 90 );
        end
    end
    
    for jj = 1:length( modeOffIdx )
        for kk = ii+1:length(fields)
            if (labelLocs( modeOffIdx(jj) ) ~= 1) && ...
                    ( mode.(fields{kk})( modeOffIdx(jj) ) == 1 )
                startLoc =  mode.timestamp(modeOffIdx(jj));
                plot( [startLoc startLoc], ...
                    [yLims(1), yLims(2)], '--', 'color', colors{kk} )
                labelLocs( modeOffIdx(jj) ) = 1;
                h = text( startLoc+0.02*diff(xLims), ...
                    yLims(1) + 0.05*diff(yLims), labels{kk}, 'FontSize', 8, ...
                    'Color', colors{kk}, 'Rotation', 90 );
                break
            end
        end
    end
end

nLines = sum( labelLocs );
lh = gco;
s = get( lh, 'string' );
set( lh, 'string', s(1:end-nLines) )