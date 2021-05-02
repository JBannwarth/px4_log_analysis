function flogsOut = CropLogGroup( flogsIn, flightLen, dt, signal )
%CROPLOGGROUP Crop a group of logs.
%   FLOGSOUT = CROPLOGGROUP( FLOGSIN ) crops logs to the last 150s of OFFBOARD mode.
%   FLOGSOUT = CROPLOGGROUP( FLOGSIN, FLIGHTLEN ) specifies the flight length to crop.
%   FLOGSOUT = CROPLOGGROUP( FLOGSIN, FLIGHTLEN, DT ) also resamples the data with sampling time DT.
%   FLOGSOUT = CROPLOGGROUP( FLOGSIN, FLIGHTLEN, DT, SIGNAL ) specifies the signal which change demarkates the end of the log
%
%   Inputs:
%       - flogsIn:   Individual flight log, cell array of flight log (i.e.
%                    a group), or a cell array of groups.
%       - flightLen: Length of time-period to crop in seconds. 150s by
%                    default, can be turned off by setting to -1.
%       - dt:        Sample time for log resampling. Off by default (-1).
%       - signal:    2x1 cell array defining the topic and signal name that
%                    contains the state change demarkating the end of the
%                    test period.
%   Output:
%       - signal:  Cropped flight log(s).
%
%   See also LOADLOGGROUP.
%
%   Written: 2021/03/17, J.X.J. Bannwarth

    arguments
        flogsIn
        flightLen (1,1) double = 150 % seconds
        dt        (1,1) double = -1  % seconds
        signal    (2,1) cell   =  {'vehicle_control_mode', 'flag_control_offboard_enabled'}
    end

    %% Input processing
    % Convert individual log and or standalone group into the same format
    % as cell arrays of groups to simplify subsequent code
    if ~iscell(flogsIn)
        % Individual log
        flogsIn = {{flogsIn}};
        type = 'individual';
    elseif ~iscell(flogsIn{1})
        % Standalone group
        flogsIn = {flogsIn};
        type = 'group';
    else
        % Array of groups
        type = 'groups';
    end
    
    %% Crop logs
    flogsOut = flogsIn;
    for ii = 1:length( flogsIn )
        for jj = 1:length( flogsIn{ii} )
            mode = flogsIn{ii}{jj}.(signal{1});
            if flightLen > 0
                % Find last mode change (when the signal last experiences a
                % large change
                threshold = min(mode.(signal{2})) + ...
                    0.5*( max(mode.(signal{2})) - min(mode.(signal{2})) );
                idxEnd = find( diff( mode.(signal{2}) > threshold ), ...
                    1, 'last' );
                tEnd = mode.timestamp( idxEnd );
                tStart = tEnd - seconds(flightLen);
            else
                % Use the earliest and latest times that are present in
                % all topics
                tStart = -inf;
                tEnd = inf;
                fieldNames = fields( flogsIn{ii}{jj} );
                for kk = 1:length( fieldNames )
                    if istimetable( flogsIn{ii}{jj}.(fieldNames{kk}) )
                        tStart = max( [ tStart, ...
                            flogsIn{ii}{jj}.(fieldNames{kk}).timestamp(1) ] );
                        tEnd = min( [ tEnd, ...
                            flogsIn{ii}{jj}.(fieldNames{kk}).timestamp(end) ] );
                    end
                end
            end
            
            if dt > 0
                % Use round timestamps
                tResample = (ceil(tStart/dt)*dt:seconds(dt):floor(tEnd/dt)*dt)';
            end
            
            % Crop log and resample if necessary
            flightFields = fields( flogsOut{ii}{jj} );
            for kk = 1:length( flightFields )
                if istimetable( flogsOut{ii}{jj}.(flightFields{kk}) )
                    T = flogsIn{ii}{jj}.(flightFields{kk});
                    t = flogsIn{ii}{jj}.(flightFields{kk}).timestamp;
                    if dt <= 0
                        % Simply crop
                        T = T((T.timestamp <= tEnd) & (T.timestamp >= tStart), :);
                        
                        % Zero the time
                        T.timestamp = T.timestamp - tStart;
                    else
                        % Resample and crop
                        % Resampling done in three steps
                        % (1) Resample flags - stored as int8
                        TFlags = T(:, vartype('int8'));
                        TFlags = retime( TFlags, tResample, 'nearest' );
                        
                        % (2) Resample quaternions using slerp
                        isQuat = matches( T.Properties.VariableNames, ...
                            {'q', 'q_d', 'delta_q_reset'} );
                        TQ = T(:, isQuat );
                        TQOut = retime( TQ, tResample, 'fillwithmissing' );
                        for mm = 1:width(TQ)
                            % Find index of original timestamp before each
                            % resampled timestamp
                            idx = zeros( size( tResample ) );
                            for nn = 1:length( tResample )
                                idx(nn) = find( t <= tResample(nn), 1, 'last' );
                            end

                            % Find how far along the resampled timestamp is
                            % between the closes two original timestamps
                            ratio = (tResample - t(idx)) ./ (t(idx+1) - t(idx));

                            % Interpolate quaternion using slerp between
                            % the original quaternion at timestamps right
                            % before and after the resampled timestamp
                            q = quaternion( TQ{:,mm} );
                            q = slerp( q(idx), q(idx+1), ratio );
                            TQOut{:,mm} = compact( q );
                        end
                        
                        % (3) Resample everything else
                        % First convert durations to seconds to avoid
                        % conversion errors
                        vars = T.Properties.VariableNames;
                        for mm = 1:length( vars )
                            if isduration( T.(vars{mm}) )
                                T.(vars{mm}) = seconds( T.(vars{mm}) );
                            end
                        end
                        T = convertvars( T, T.Properties.VariableNames, 'double' );
                        T = retime( T, tResample, 'linear' );
                        
                        % Assign data back
                        if ~isempty( TFlags )
                            for mm = 1:width( TFlags )
                                T.(TFlags.Properties.VariableNames{mm}) = TFlags{:,mm};
                            end
                        end
                        if ~isempty( TQ )
                            T(:,isQuat) = TQOut;
                        end
                        
                        % Zero the time
                        T.timestamp = T.timestamp - T.timestamp(1);
                    end
                    
                    % Add seconds column for easier plotting
                    T.t = seconds( T.timestamp );
                    
                    % Write to output
                    flogsOut{ii}{jj}.(flightFields{kk}) = T;
                end
            end
        end
    end

    %% Post-process data
    switch type
        case 'individual'
            flogsOut = flogsOut{1}{1};
        case 'group'
            flogsOut = flogsOut{1};
        otherwise
            % Nothing
    end
end