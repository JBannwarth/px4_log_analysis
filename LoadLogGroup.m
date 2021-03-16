function flogs = LoadLogGroup( fileTag, saveFile, dirIn )
%LOADLOGGROUP Load a group of log containing a given tag
%   FLOGS = LOADLOGGROUP( FILETAG ) loads files matching FILETAG.
%   FLOGS = LOADLOGGROUP( FILETAG, SAVEFILE ) saves output to disk.
%   FLOGS = LOADLOGGROUP( FILETAG, SAVEFILE, DIRIN ) specifies the input dir.
%
%   Inputs:
%       - fileTag:  Only files containing fileTag will be loaded. Can be a
%                   string of chars, or a cell array of strings of chars.
%       - dirIn:    Top-level directory containing logs, defaults to 'logs'.
%       - saveFile: Save the outputs to a .mat file for faster loading.
%   Outputs:
%       - flogs:    Sorted cell array of flight log structures.
%
%   It is assumed that the filenames are in the format
%       <DATE>_<LEADSTRING>_<FILETAG>_<FILEIDENTIFIER>.ulg
%   LEADSTRING is ignored, while FILEIDENTIFIER is added to each flog
%   structure in FLOGS. To differentiate files with the same identifier,
%   a number in the form _XX (e.g. _01) is added to the identifier based on
%   the choronological order of the files' DATE field.
%
%   The output of the function are alphabetically sorted based on the
%   files' identifiers.
%
%   See also LOADLOG.
%
%   Written: 2021/03/16, J.X.J. Bannwarth

    arguments
        fileTag  (1,:)
        saveFile (1,1) logical = false
        dirIn    (1,:) char    = 'logs'
    end
    
    if ~iscell( fileTag )
        fileTag = { fileTag };
    end
    
    % Get files
    files = cell( length(fileTag), 1 );
    flogs = cell( length(fileTag), 1 );
    for ii = 1:length(fileTag)    
        %% Get files
        % Inform user
        fprintf( 'Loading files matching tag %s (%d/%d)\n', ...
            fileTag{ii}, ii, length(fileTag) );
        
        % Find matching files
        files{ii} = dir( fullfile( dirIn, '**', [ '*' fileTag{ii} '*.ulg' ] ) );

        % Load matching files
        flogs{ii} = cell( length(files), 1 );
        for jj = 1:length(files{ii})
            % Inform user
            fprintf( '\t> Loading file [%d/%d]\n', jj, length(files{ii}) );
            
            curFolder = extractAfter( files{ii}(jj).folder, [ dirIn filesep ] );
            [ flogs{ii}{jj}, ~ ] = LoadLog( fullfile( curFolder, ...
                files{ii}(jj).name ), dirIn );
        end

        %% Find identifiers
        % Get file identifiers
        fileIdentifiers = replace( extractAfter( {files{ii}.name}', fileTag{ii} ), ...
            { '_', '.ulg' }, '' );

        % Make identifiers unique
        [ uniqueIdentifiers, ~, idx ] = unique( fileIdentifiers );

        for jj = 1:length(uniqueIdentifiers)       
            repeatNames = {files{ii}(idx==jj).name};
            % Sort alphabetically, which also sorts by date given the dates are
            % in the YYYY-MM-DD_HH-MM-SS format
            [~, sortedIdx] = sort( repeatNames );

            % Add _01, _02, etc. to identifiers
            suffixes = arrayfun( @(x)( num2str(x, '%02d') ), sortedIdx', ...
                'UniformOutput', false);
            fileIdentifiers(idx==jj) = strcat( fileIdentifiers(idx==jj), ...
                '_', suffixes );
        end

        % Add to flogs structure
        for jj = 1:length( fileIdentifiers )
            flogs{ii}{jj}.identifier = fileIdentifiers{jj};
            flogs{ii}{jj}.group      = fileTag{ii};
        end

        % Sort identifiers alphabetically and reorder flogs and ulogs to match
        [ ~, idxSorted ] = sort( fileIdentifiers );
        flogs{ii} = flogs{ii}( idxSorted );
    end
    
    %% Process output
    % If we only have one tag, we do not need a cell array inside another
    % cell array
    if length( fileTag ) == 1
        flogs = flogs{1};
    end
    
    % Save to disk if required
    if saveFile
        filename = input( 'Enter output file name: ', 's' );
        save( filename, 'flogs' )
    end
end