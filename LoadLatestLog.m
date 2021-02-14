function [flog, ulog] = LoadLatestLog( dirIn )
%LOADLATESTLOG Load the most recent ulog file
%   LOADLATESTLOG( ) loads the latest log in the 'logs' directory
%   LOADLATESTLOG( DIRIN ) loads the latest log in the DIRIN directory
%
%   Note that 'latest' refers to the flight conducted the most recently,
%   rather than the flight imported the most recently. In addition, note
%   that flights performed without GPS or MAVLink connection may show
%   erroneous dates.
%
%   See also LOADLOG, ULOGREADER.
%
%   Written: 2021/02/08, J.X.J. Bannwarth
    %% Arguments
    arguments
        dirIn (1,:) char = 'logs'
    end
    
    %% Get latest file name
    folders = dir( dirIn );
    folders = folders( [folders.isdir], : );
    files = dir( fullfile( dirIn, folders(end).name ) );
    
    %% Load latest file
    [flog, ulog] = LoadLog( fullfile( folders(end).name, files(end).name ), ...
        dirIn );

end