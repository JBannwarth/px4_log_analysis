function flogs = LoadLogGroup( groupTag, saveFile, dirIn, flightLen, dt, signal, tEndIn )
%LOADLOGGROUP Load a group of log containing a given tag
%   FLOGS = LOADLOGGROUP( GROUPTAG ) loads files matching GROUPTAG.
%   FLOGS = LOADLOGGROUP( GROUPTAG, SAVEFILE ) saves output to disk.
%   FLOGS = LOADLOGGROUP( GROUPTAG, SAVEFILE, DIRIN ) specifies the input dir.
%   FLOGS = LOADLOGGROUP( GROUPTAG, SAVEFILE, DIRIN, FLIGHTLEN ) specifies the length to crop
%   FLOGS = LOADLOGGROUP( GROUPTAG, SAVEFILE, DIRIN, FLIGHTLEN, DT ) specifies the resampling rate
%   FLOGS = LOADLOGGROUP( GROUPTAG, SAVEFILE, DIRIN, FLIGHTLEN, DT, ) specifies the resampling rate
%   FLOGS = LOADLOGGROUP( GROUPTAG, SAVEFILE, DIRIN, FLIGHTLEN, DT, SIGNAL ) specifies the signal to use for cropping
%   FLOGS = LOADLOGGROUP( GROUPTAG, SAVEFILE, DIRIN, FLIGHTLEN, DT, SIGNAL, TENDIN ) overrides the crop time
%
%   Inputs:
%       - GROUPTAG:  Only files containing GROUPTAG will be loaded. Can be
%                    a string of chars, or a cell array of strings of chars.
%       - dirIn:     Top-level directory containing logs, defaults to 'logs'.
%       - saveFile:  Save the outputs to a .mat file for faster loading.
%       - flightLen: Length of time-period to crop in seconds. It is
%                    assumed that the cropped period ends when the
%                    OFFBOARD flight mode is switched off for the last time
%                    in the current flight log. Off by default (-1).
%       - dt:        Sample time for log resampling. Off by default (-1).
%       - signal:    2x1 cell array defining the topic and signal name that
%                    contains the state change demarkating the end of the
%                    test period.
%       - tEndIn:    cell array of vectors with the same dimensions as
%                    the input files, overriding the crop time detection.
%                    Elements <=0 are not overriden.
%   Outputs:
%       - flogs:     Sorted cell array of flight log structures.
%
%   It is assumed that the filenames are in the format
%       <DATE>_<LEADSTRING>_<GROUPTAG>_<CASETAG>_<TRIAL>[_<EXTRATAG>].ulg
%
%   For example: DATE       is the date
%                LEADSTRING corresponds to the flight mode used
%                GROUPTAG   corresponds to a type of controller
%                CASETAG    corresponds to a wind tunnel wind speed
%                TRIAL      corresponds to the number of the trial for that
%                           combination of controller and wind speed
%                EXTRATAG   is set to 'issue' if the flight is to be
%                           ignored
%
%   LEADSTRING is ignored and filenames ending with the extra tags 'issue'
%   and 'demo' are ignored.
%
%   The output of the function are alphabetically sorted based on the
%   files' CASETAG.
%
%   See also LOADLOG.
%
%   Written: 2021/03/16, J.X.J. Bannwarth

    arguments
        groupTag   (1,:)
        saveFile  (1,1) logical = false
        dirIn     (1,:) char    = 'logs'
        flightLen (1,1) double  = -1     % seconds
        dt        (1,1) double  = -1     % seconds
        signal    (2,1) cell    = {'vehicle_control_mode', 'flag_control_offboard_enabled'}
        tEndIn                  = {}
    end
    
    if ~iscell( groupTag )
        groupTag = { groupTag };
    end
    
    % Get files
    files = cell( length(groupTag), 1 );
    flogs = cell( length(groupTag), 1 );
    for ii = 1:length(groupTag)    
        %% Get file info
        % Inform user
        fprintf( 'Loading files matching tag %s (%d/%d)\n', ...
            groupTag{ii}, ii, length(groupTag) );
        
        % Find matching files
        files{ii} = dir( fullfile( dirIn, '**', [ '*' groupTag{ii} '*.ulg' ] ) );
        
        % Ignore files with extra tags
        filesToIgnore = endsWith( replace( {files{ii}.name}', '.ulg', '' ), ...
            {'issue', 'demo'} );
        files{ii}(filesToIgnore) = [];
 
        % Get case tags and trial numbers
        tags = extractBetween( {files{ii}.name}', groupTag{ii}, '.ulg' );
        
        % Use trial numbers, or add unique identifiers if all tags are the
        % same
        if all( strcmp(tags{1}, tags) )
            % No trial numbers, add them
            caseTags = replace( tags, '_', '' );
            [ uniqueIdentifiers, ~, idx ] = unique( caseTags );

            for jj = 1:length(uniqueIdentifiers)
                repeatNames = {files{ii}(idx==jj).name};
                % Sort alphabetically, which also sorts by date given the dates are
                % in the YYYY-MM-DD_HH-MM-SS format
                [~, sortedIdx] = sort( repeatNames );

                % Add _01, _02, etc. to caseTags
                trialNumber = arrayfun( @(x)( num2str(x, '%02d') ), sortedIdx', ...
                    'UniformOutput', false);
                caseTags(idx==jj) = strcat( caseTags(idx==jj), ...
                    '_', trialNumber );
            end
        else
            caseTags = cell( size(tags) );
            for jj = 1:length( tags )
                tagsSplit = split( tags{jj}, '_' );
                tagsSplit( cellfun('isempty', tagsSplit) ) = [];
                caseTags{jj} = [ tagsSplit{1} '_' tagsSplit{2} ];
            end
        end

        %% Get files
        % Load matching files
        flogs{ii} = cell( length(files), 1 );
        for jj = 1:length(files{ii})
            % Inform user
            fprintf( '\t> Loading file [%d/%d]\n', jj, length(files{ii}) );
            
            curFolder = extractAfter( files{ii}(jj).folder, [ dirIn filesep ] );
            [ flogs{ii}{jj}, ~ ] = LoadLog( fullfile( curFolder, ...
                files{ii}(jj).name ), dirIn );
        end

        % Add identifiers to flogs structure
        for jj = 1:length( caseTags )
            flogs{ii}{jj}.identifier = caseTags{jj};
            flogs{ii}{jj}.group      = groupTag{ii};
        end

        % Sort identifiers alphabetically and reorder flogs and ulogs to match
        [ ~, idxSorted ] = sort( caseTags );
        flogs{ii} = flogs{ii}( idxSorted );
    end
    
    %% Process output
    % Crop/resample if needed
    if (flightLen > 0) && (dt > 0)
        fprintf( 'Cropping logs to %.0f s, and resampling at %.1f Hz\n', ...
            flightLen, 1/dt );
        flogs = CropLogGroup( flogs, flightLen, dt, signal, tEndIn );
    elseif flightLen > 0
        fprintf( 'Cropping logs to %.0f s\n', flightLen );
        flogs = CropLogGroup( flogs, flightLen, -1, signal, tEndIn );
    elseif dt > 0
        fprintf( 'Resampling at %.1f Hz\n', 1/dt );
        flogs = CropLogGroup( flogs, -1, dt, signal, tEndIn );
    end
    
    % If we only have one tag, we do not need a cell array inside another
    % cell array
    if length( groupTag ) == 1
        flogs = flogs{1};
    end
    
    % Save to disk if required
    if saveFile
        filename = input( 'Enter output file name: ', 's' );
        save( filename, 'flogs', '-v7.3' )
    end
end