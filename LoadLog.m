function [flog, ulog] = LoadLog( fileIn, dirIn )
%LOADLOG
%   Written: 2021/02/07, J.X.J. Bannwarth
    %% Arguments
    arguments
        fileIn (1,:) char
        dirIn  (1,:) char = 'logs'
    end
    
    %% Load data
    ulog = ulogreader( fullfile( dirIn, fileIn ) );

    %% Extract relevant data to structure
    dataTmp = readTopicMsgs( ulog );

    for ii = 1:size( dataTmp, 1 )
        if dataTmp(ii,:).InstanceID == 0
            flog.(dataTmp(ii,:).TopicNames{1}) = dataTmp(ii,:).TopicMessages{1};
        end
    end
end