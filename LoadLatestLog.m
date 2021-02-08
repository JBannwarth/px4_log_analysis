function [flog, ulog] = LoadLatestLog( dirIn )
%LOADLATESTLOG Load the most recent ulog file
%   Written: 2021/02/08, J.X.J. Bannwarth
    %% Arguments
    arguments
        dirIn (1,:) char = 'logs'
    end
    
    %% Get latest file name
    folders = dir( dirIn );
    files = dir( fullfile( dirIn, folders(end).name ) );
    
    %% Load latest file
    [flog, ulog] = LoadLog( fullfile( folders(end).name, files(end).name ), ...
        dirIn );

end