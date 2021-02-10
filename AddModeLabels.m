function AddModeLabels( modes, inverted )
%ADDMODELABELS Add mode transition labels to plot
%   Input:
%       - modes:    timetable of mode changes
%       - inverted: whether the y-axis is inverted or not
%   Shows modes in the following order of precedence:
%       - OFFB > POS > VEL > ALT > ATT > RATES
%   Draws a colored line along with a label for each mode change. Lines are
%   much easier to handle than shaded areas.
%   Written: 2021/02/09, J.X.J. Bannwarth
    arguments
        modes timetable
        inverted (1,1) logical = false
    end
    
    %% Set-up
    % Recognised mode labels, corresponding fields, and color codes
    labels = { 'OFFB'; 'POS'; 'VEL'; 'ALT'; 'ATT'; 'RATES' };
    fields = { 'flag_control_offboard_enabled';
               'flag_control_position_enabled';
               'flag_control_velocity_enabled';
               'flag_control_altitude_enabled';
               'flag_control_attitude_enabled';
               'flag_control_rates_enabled'  };
    colors = parula( length(fields) );
    colors = mat2cell( colors, ones(length(fields),1), 3 );
    
    %% Add labels
    % Array of line locations to avoid drawing two lines on top of one another
    lineLocs = zeros( size( modes.(fields{1}) ) );

    % Start from the mode of highest precedence and work way down
    for ii = 1:length(fields)
        % Find when the current mode is activated and deactivated
        modeOnIdx = find( diff(modes.(fields{ii})) == 1 ) + 1;
        modeOffIdx = find( diff(modes.(fields{ii})) == -1 ) + 1;

        % Handle the mode being on on the first sample
        if modes.(fields{ii})(1) == 1
            modeOnIdx = [1 modeOnIdx];
        end

        % Draw lines when mode is activated
        for jj = 1:length( modeOnIdx )
            if lineLocs( modeOnIdx(jj) ) ~= 1
                DrawTransitionLine( modes.timestamp(modeOnIdx(jj)), ...
                    colors{ii}, labels{ii}, inverted );
                lineLocs( modeOnIdx(jj) ) = 1;
            end
        end

        % Draw lines when mode is deactivated
        % Note: Lower level modes are not necessarily deactivated when
        % activating a higher level mode. For example, POSCTL is still active
        % while in OFFBOARD. Therefore, we cannot rely on rising edges of lower
        % level modes to accurately determine the current mode
        for jj = 1:length( modeOffIdx )
            % Cycle through lower level mode to find which one is still active
            for kk = (ii+1):length(fields)
                if (lineLocs( modeOffIdx(jj) ) ~= 1) && ...
                        ( modes.(fields{kk})( modeOffIdx(jj) ) == 1 )
                    DrawTransitionLine( modes.timestamp(modeOffIdx(jj)), ...
                        colors{kk}, labels{kk}, inverted );
                    lineLocs( modeOffIdx(jj) ) = 1;
                    break
                end
            end
        end
    end
end

%% Helper function
function DrawTransitionLine( xLoc, color, label, inverted )
%DRAWTRANSITIONLINE Draw mode transition line with label
%   Inputs:
%       - xLoc:  location on x-axis to put the mode transition line
%       - color: color code or 3x1 array of normalized RGB values
%       - label: label to put to the right of the mode transition line
%       - inverted: whether the y-axis is inverted or not
%   Written: 2021/02/10, J.X.J. Bannwarth
    arguments
        xLoc
        color
        label (1,:) char
        inverted (1,1) logical = false
    end

    % Axes limits
    xLims = xlim();
    yLims = ylim();
    
    % Line
    plot( [xLoc xLoc], [yLims(1), yLims(2)], '-.', 'color', color )
    
    % Label
    if inverted
        text( xLoc+0.02*diff(xLims), yLims(2) - 0.05*diff(yLims), ...
            label, 'FontSize', 8, 'Color', color, 'Rotation', 90 );
    else
        text( xLoc+0.02*diff(xLims), yLims(1) + 0.05*diff(yLims), ...
            label, 'FontSize', 8, 'Color', color, 'Rotation', 90 );
    end
end