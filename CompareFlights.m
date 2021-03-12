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
    pos{ii}   = flog{ii}.vehicle_local_position;
    posSp{ii} = flog{ii}.vehicle_local_position_setpoint;
    att{ii}   = flog{ii}.vehicle_attitude;
    attSp{ii} = flog{ii}.vehicle_attitude_setpoint;
    mode{ii}  = flog{ii}.vehicle_control_mode;
    
end

%% Plot data