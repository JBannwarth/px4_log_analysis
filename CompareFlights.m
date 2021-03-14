%COMPAREFLIGHTS Compare several flights.
%
%   See also FLIGHTOVERVIEW, COMPAREPOSITIONSENSORS.
%
%   Written: 2021/03/11, J.X.J. Bannwarth

%% Set-up
close all;
clearvars -except filePattern files flog ulog legendStr fileIdentifier

if ~exist( 'filePattern', 'var' )
    fileTag = '_offboard_tether';
end

if ~exist( 'U', 'var' )
    U =  [ 0 5.5777 7.3993 9.8020 12.7741 ]';
    legendStr = strcat( 'U =', {' '}, ...
        strip( cellstr( num2str( U, '%0.1f' ) ) ), {' '}, 'm/s' );
end

dirIn = 'logs';
flightLen = 150; % seconds

%% Load files if needed
if ~exist( 'flog', 'var') || ~exist( 'ulog', 'var' )
    % Find matching files
    files = dir( fullfile( dirIn, '**', [ '*' fileTag '*.ulg' ] ) );

    flog = cell( length(files), 1 );
    ulog = cell( length(files), 1 );
    for ii = 1:length( files )
        curFolder = extractAfter( files(ii).folder, [ dirIn filesep ] );
        [ flog{ii}, ulog{ii} ] = LoadLog( fullfile( curFolder, ...
            files(ii).name ), dirIn );
    end
    fileIdentifier = replace( extractAfter( {files.name}, fileTag ), ...
    { '_', '.ulg' }, '' );
end

% Sort arrays by legend
[fileIdentifier, idxSorted] = sort( fileIdentifier );
flog = flog( idxSorted );
ulog = ulog( idxSorted );

%% Get information of interest
pos   = cell( length(flog), 1 );
posSp = cell( length(flog), 1 );
att   = cell( length(flog), 1 );
attSp = cell( length(flog), 1 );
mode  = cell( length(flog), 1 );
meanPos = zeros( length(flog), 3 );
meanAtt = zeros( length(flog), 3 );
rmsPosErr  = zeros( length(flog), 3 );
rmsAttErr  = zeros( length(flog), 3 );
maxPosErr  = zeros( length(flog), 3 );
maxAttErr  = zeros( length(flog), 3 );
maxPosNorm = zeros( length(flog), 1 );
maxqDist   = zeros( length(flog), 1 );
rmsPosNorm = zeros( length(flog), 1 );
rmsqDist   = zeros( length(flog), 1 );
for ii = 1:length( flog )
    % Get important data
    mode{ii}  = flog{ii}.vehicle_control_mode;
    pos{ii}   = flog{ii}.vehicle_local_position;
    posSp{ii} = flog{ii}.vehicle_local_position_setpoint;
    att{ii}   = flog{ii}.vehicle_attitude;
    attSp{ii} = flog{ii}.vehicle_attitude_setpoint;
    
    % Select columns of interest
    pos{ii} = pos{ii}(:, matches( pos{ii}.Properties.VariableNames, { 'x', 'y', 'z', 'vx', 'vy', 'vz' } ) );
    posSp{ii} = posSp{ii}(:, matches( posSp{ii}.Properties.VariableNames, { 'x', 'y', 'z', 'vx', 'vy', 'vz' } ) );
    att{ii} = att{ii}(:, matches( att{ii}.Properties.VariableNames, { 'rollspeed', 'pitchspeed', 'yawspeed', 'q' } ) );
    attSp{ii} = attSp{ii}(:, matches( attSp{ii}.Properties.VariableNames, { 'roll_body', 'pitch_body', 'yaw_body', 'q_d' } ) );
    
    % Add euler attitude
    [ att{ii}.roll_body, att{ii}.pitch_body, att{ii}.yaw_body ] = QuatToEuler( att{ii}.q );
    
    % Convert to degrees
    attSp{ii}.roll_body  = rad2deg( attSp{ii}.roll_body );
    attSp{ii}.pitch_body = rad2deg( attSp{ii}.pitch_body );
    attSp{ii}.yaw_body   = rad2deg( attSp{ii}.yaw_body );
    att{ii}.roll_body  = rad2deg( att{ii}.roll_body );
    att{ii}.pitch_body = rad2deg( att{ii}.pitch_body );
    att{ii}.yaw_body   = rad2deg( att{ii}.yaw_body );
    
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
    posErr = [posSp{ii}.x posSp{ii}.y posSp{ii}.z] - [pos{ii}.x pos{ii}.y pos{ii}.z];
    posNorm = sqrt( sum( posErr.^2, 2 ) );
    meanPos(ii,:) = mean( [pos{ii}.x pos{ii}.y pos{ii}.z], 1 );
    rmsPosErr(ii,:)  = rms( posErr, 1 );
    maxPosErr(ii,:)  = max( abs(posErr), [], 1 );
    rmsPosNorm(ii) = rms( posNorm );
    maxPosNorm(ii) = max( posNorm );
    
    % Calculate attitude metrics
    q = quaternion( att{ii}.q );
    qDes = quaternion( attSp{ii}.q_d );
    qErr = conj(q) .* qDes;
    attErr = eulerd( qErr, 'ZYX', 'frame' );
    meanAtt(ii,:) = eulerd( meanrot( q ), 'ZYX', 'frame' );
    rmsAttErr(ii,:)  = rms( attErr, 1 );
    maxAttErr(ii,:)  = max( abs(attErr), [], 1 );
    maxqDist(ii) = rad2deg( max( dist( q, qDes ) ) );
    rmsqDist(ii) = rad2deg( rms( dist( q, qDes ) ) );
end

%% Plot data
% Attitude
figure( 'name', 'Attitude' )
axAtt(1) = subplot( 3, 1, 1 ); hold on; grid on; box on;
axAtt(2) = subplot( 3, 1, 2 ); hold on; grid on; box on;
axAtt(3) = subplot( 3, 1, 3 ); hold on; grid on; box on;
axs = {'Roll', 'Pitch', 'Yaw'};
for ii = 1:length( flog )
    for jj = 1:length( axs )
        plot( axAtt(jj), att{ii}.t, att{ii}.([lower(axs{jj}) '_body']) )
        ylabel( axAtt(jj), [ axs{jj} ' (deg)' ] )
    end
end

xlabel( axAtt(end), 'Time (s)' )
legend( legendStr )

% Position
figure( 'name', 'Position' )
axPos(1) = subplot( 3, 1, 1 ); hold on; grid on; box on;
axPos(2) = subplot( 3, 1, 2 ); hold on; grid on; box on;
axPos(3) = subplot( 3, 1, 3 ); hold on; grid on; box on;
axs = {'x', 'y', 'z'};
for ii = 1:length( flog )
    for jj = 1:length( axs )
        plot( axPos(jj), pos{ii}.t, pos{ii}.(axs{jj}) )
        ylabel( axPos(jj), [ axs{jj} ' position (m)' ] )
    end
end

xlabel( axPos(end), 'Time (s)' )
legend( legendStr )

% RMS metrics
lineStyles = { '-o', '--s', '-.^', ':v' };
figure( 'name', 'RMS error' )
subplot( 2, 1, 1 ); hold on; grid on; box on
for ii = 1:3
    plot( U, rmsPosErr(:,ii), lineStyles{ii} )
end
plot( U, rmsPosNorm, lineStyles{4} )
ylabel( 'Position RMS error (m)' )
legend( {'x', 'y', 'z', 'L2 norm' }, 'location', 'best' )

subplot( 2, 1, 2 ); hold on; grid on; box on
for ii = 1:3
    plot( U, rmsAttErr(:,ii), lineStyles{ii} )
end
plot( U, rmsqDist, lineStyles{4} )
xlabel( 'Wind speed (m/s)' )
ylabel( 'Attitude RMS error (deg)' )
legend( {'Roll', 'Pitch', 'Yaw', 'Dist'}, 'location', 'best' )

% Maximum metrics
figure( 'name', 'Max error' )
subplot( 2, 1, 1 ); hold on; grid on; box on
for ii = 1:3
    plot( U, maxPosErr(:,ii), lineStyles{ii} )
end
plot( U, maxPosNorm, lineStyles{4} )
ylabel( 'Maximum position error (m)' )
legend( {'x', 'y', 'z', 'L2 norm' }, 'location', 'best' )

subplot( 2, 1, 2 ); hold on; grid on; box on
for ii = 1:3
    plot( U, maxAttErr(:,ii), lineStyles{ii} )
end
plot( U, maxqDist, lineStyles{4} )
xlabel( 'Wind speed (m/s)' )
ylabel( 'Maximum attitude error (deg)' )
legend( {'Roll', 'Pitch', 'Yaw', 'Dist'}, 'location', 'best' )

% Mean values
figure( 'name', 'Mean values' )
subplot( 2, 1, 1 ); hold on; grid on; box on
for ii = 1:3
    plot( U, meanPos(:,ii), lineStyles{ii} )
end
ylabel( 'Mean position (m)' )
legend( {'x', 'y', 'z'}, 'location', 'best' )

subplot( 2, 1, 2 ); hold on; grid on; box on
for ii = 1:3
    plot( U, meanAtt(:,ii), lineStyles{ii} )
end
xlabel( 'Wind speed (m/s)' )
ylabel( 'Mean attitude (deg)' )
legend( {'Roll', 'Pitch', 'Yaw'}, 'location', 'best' )


%% Helper
function T = CropTimetable( T, tStart, tEnd, dt )
    T = T( T.timestamp <= tEnd & T.timestamp >= tStart, : );
    tResample = round(tStart/dt)*dt:seconds(dt):round(tEnd/dt)*dt;
    T = retime( T, tResample, 'linear' );
    T.timestamp = T.timestamp - T.timestamp(1);
    T.t = seconds( T.timestamp );
end