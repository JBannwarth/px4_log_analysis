function ImportLogs( driveIn )
%IMPORTLOGS Move logs from SD-card and rename them
%   Output format:
%       ./logs/yyyy-MM-dd/yyyy-MM-dd_HH-mm-ss_mode.ulg
%   Written: 2021/02/07, J.X.J. Bannwarth
    %% Input processing
    arguments
        driveIn (1,:) char = 'F:'
    end
    
    if ~exist( driveIn, 'dir' )
        error( 'Input drive %s does not exist', driveIn )
    end
    
    % Inform user
    fprintf( 'Importing ulog files from %s\n', driveIn )

    %% Analyse contents of SD-card
    % Get list of folders
    folders = dir( fullfile( driveIn, 'log' ) );
    folders( strcmp({folders.name}, '.') | strcmp({folders.name}, '..') ) = [];

    % Get list of input files, and generate output file paths
    filesIn = {};
    filesOut = {};
    foldersOut = {};
    skipped = 0;
    for ii = 1:length( folders )
        curFolder = fullfile( driveIn, 'log', folders(ii).name );
        logFiles = dir( fullfile( curFolder, '*.ulg' ) );

        % Get date and time for each file
        logDatetimes = datetime( [logFiles.datenum], 'ConvertFrom', 'datenum', ...
            'TimeZone', 'Etc/GMT', 'Format', 'yyyy-MM-dd_HH-mm-ss' )';
        logDatetimes.TimeZone = 'Pacific/Auckland'; % Convert to NZDT
        logDates = logDatetimes;
        logDates.Format = 'yyyy-MM-dd';

        % Check the logs have not been imported already
        toSkip = zeros( size(logDatetimes) );
        for jj = 1:length( logDatetimes )
            pathFormat = fullfile( '.', 'logs', char( logDates(jj) ), ...
                [ char( logDatetimes(jj) ) '*' ] );
            if ~isempty( dir(pathFormat) )
                toSkip(jj) = 1;
                skipped = skipped + 1;
            end
        end
        logFiles = logFiles( ~toSkip, : );
        logDatetimes = logDatetimes( ~toSkip, : );
        logDates = logDates( ~toSkip, : );
        
        % Input files to move
        filesIn = [filesIn; fullfile( curFolder, {logFiles.name} )'];
        
        % Get the highest 'level' flight mode used during the flight
        modes = cell( size(logFiles) );
        for jj = 1:length( logFiles )
            reader = ulogreader( fullfile( curFolder, logFiles(jj).name ) );
            status = readTopicMsgs( reader, 'TopicNames', 'vehicle_control_mode' );
            status = status.TopicMessages{1};
            if sum( status.flag_control_offboard_enabled ) > 0
                modes{jj} = 'offboard';
            elseif sum( status.flag_control_position_enabled ) > 0
                modes{jj} = 'posctl';
            elseif sum( status.flag_control_altitude_enabled ) > 0
                modes{jj} = 'altctl';
            else
                modes{jj} = 'manual';
            end
        end
        filesOut = [filesOut; fullfile( '.', 'logs', char( logDates ), ...
            strcat( char(logDatetimes), '_', modes, '.ulg' ) ) ];
        foldersOut = [foldersOut; fullfile( '.', 'logs', cellstr(logDates) )];
    end

    % Inform user
    if skipped > 0
        fprintf( 'Skipped %d existing files\n', skipped )
    end
    
    if isempty( filesIn )
        error( 'No new files on SD card' )
    end
    
    fprintf( 'Detected %d new files\n', length(filesIn) )

    %% Transfer logs
    % Exit if there is nothing to do


    % Create folder if necessary
    for ii = 1:length( foldersOut )
        if ~isfolder( foldersOut{ii} )
            mkdir( foldersOut{ii} )
        end
    end

    % Copy files that do not already exist - redundant but safe
    for ii = 1:length( filesOut )
        if ~isfile( filesOut{ii} )
            copyfile( filesIn{ii}, filesOut{ii} )
        end
    end

    % Inform user
    fprintf( 'Copied %d new files\n', ...
        length(filesIn) )
end