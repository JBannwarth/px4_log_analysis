function [flog, ulog] = LoadLog( fileIn, dirIn )
%LOADLOG Load ulog file to structure of timetables
%   [FLOG, ULOG] = LOADLOG( FILEIN ) loads FILEIN in the root folder 'logs'
%   [FLOG, ULOG] = LOADLOG( FILEIN, DIRIN ) specifies the root folder DIRIN
%
%   Inputs:
%       - fileIn: Name of the file to load. If the file name does not
%                 contain the subfolder location, LoadLog will search all
%                 subfolders in dirIn for the file
%       - dirIn:  Name of the root folder containing all the logs
%   Outputs:
%       - flog:   Structure of timetables containing logged messages
%       - ulog:   ulogreader object of the input flight log
%
%   See also LOADLATESTLOG, ULOGREADER.
%
%   Written: 2021/02/07, J.X.J. Bannwarth
    arguments
        fileIn (1,:) char
        dirIn  (1,:) char = 'logs'
    end
    
    %% Load data
    % If the file cannot be found, check if there is a matching file in one
    % of the subfolders
    if ~isfile( fullfile( dirIn, fileIn ) )
        logs = dir( fullfile( dirIn, '**', '*.ulg' ) );
        logIdx = find( strcmp( extractBefore( {logs.name}, '.ulg' ), ...
            fileIn ), 1 );
        
        if isempty( logIdx )
            error( 'Input file ''%s'' not found', fileIn )
        else
            fprintf( 'Input file ''%s'' found in ''%s''\n', ...
                fileIn, logs(logIdx).folder )
            fileIn = logs(logIdx).name;
            dirIn  = logs(logIdx).folder;
        end
    end
    
    % Load file
    ulog = ulogreader( fullfile( dirIn, fileIn ) );

    %% Extract relevant data to structure
    dataTmp = readTopicMsgs( ulog );

    for ii = 1:size( dataTmp, 1 )
        if dataTmp(ii,:).InstanceID == 0
            flog.(dataTmp(ii,:).TopicNames{1}) = dataTmp(ii,:).TopicMessages{1};
        end
    end
    
    % Add filename to structure
    flog.filename = extractBefore( fileIn, '.ulg' );
end