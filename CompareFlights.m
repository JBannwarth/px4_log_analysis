%COMPAREFLIGHTS Compare several flights.
%
%   See also FLIGHTOVERVIEW, COMPAREPOSITIONSENSORS.
%
%   Written: 2021/03/11, J.X.J. Bannwarth

%% Set-up
close all;
clearvars -except filePattern flog ulog;

if ~exist( 'filePattern', 'var' )
    filePattern = '*_offboard_tether*.ulg';
end

dirIn = 'logs';
flightLen = 150; % seconds

%% Load files if needed
if ~exist( 'flog', 'var') || ~exist( 'ulog', 'var' )
    % Find matching files
    files = dir( fullfile( dirIn, '**', filePattern ) );

    flog = cell( length(files), 1 );
    ulog = cell( length(files), 1 );
    for ii = 1:length( files )
        curFolder = extractAfter( files(ii).folder, [ dirIn filesep ] );
        [ flog{ii}, ulog{ii} ] = LoadLog( fullfile( curFolder, ...
            files(ii).name ), dirIn );
    end
end

%% Get information of interest
pos   = cell( length(flog), 1 );
posSp = cell( length(flog), 1 );
att   = cell( length(flog), 1 );
attSp = cell( length(flog), 1 );
mode  = cell( length(flog), 1 );
for ii = 1:length( flog )
    % Get important data
    mode{ii}  = flog{ii}.vehicle_control_mode;
    pos{ii}   = flog{ii}.vehicle_local_position;
    posSp{ii} = flog{ii}.vehicle_local_position_setpoint;
    att{ii}   = flog{ii}.vehicle_attitude;
    attSp{ii} = flog{ii}.vehicle_attitude_setpoint;
    
    % Find exit from offboard mode
    idxEnd = find( mode{ii}.flag_control_offboard_enabled, 1, 'last' );
    tEnd = mode{ii}.timestamp( idxEnd );
    tStart = tEnd - seconds(flightLen);
    
    % Extract the range of data we care about
    mode{ii}  = mode{ii}(  mode{ii}.timestamp  <= tEnd & mode{ii}.timestamp  >= tStart, : );
    pos{ii}   = pos{ii}(   pos{ii}.timestamp   <= tEnd & pos{ii}.timestamp   >= tStart, : );
    posSp{ii} = posSp{ii}( posSp{ii}.timestamp <= tEnd & posSp{ii}.timestamp >= tStart, : );
    att{ii}   = att{ii}(   att{ii}.timestamp   <= tEnd & att{ii}.timestamp   >= tStart, : );
    attSp{ii} = attSp{ii}( attSp{ii}.timestamp <= tEnd & attSp{ii}.timestamp >= tStart, : );
    
    % Resample at 10 Hz, and round to nearest 1/10th of a second
    dt = 1 / 10;
    tResample = round(tStart/dt)*dt:seconds(dt):round(tEnd/dt)*dt;
    TT = synchronize( pos{1}(:,4:6),  posSp{1}(:,1:3),  ...
        tResample, 'linear' );
end

%% Plot data

%% Helper functions
function dt = GetDt( data )
    meanDt = seconds( mean( diff(data.timestamp) ) ) ;
    frequency = round( 1 / meanDt );
    dt = 1 / frequency;
end