function GenerateFlightReport( fileIn, dirIn )
%GENERATEFLIGHTREPORT Create a report with key flight information for a log
%   GENERATEFLIGHTREPORT( ) generates report for most recent file in 'logs'
%   GENERATEFLIGHTREPORT( FILEIN ) generates report for FILEIN in 'logs'
%   GENERATEFLIGHTREPORT( FILEIN, DIRIN ) generates report for FILEIN in DIRIN
%
%   Input:
%       - fileIn: name of the flight log file to load
%       - dirIn:  path of the root directory containing the flight logs
%   By default load latest flight log
%
%   See also LOADLOG, FLIGHTOVERVIEW.
%
%   Written: 2021/02/10, J.X.J. Bannwarth
    arguments
        fileIn (1,:) char = ''
        dirIn  (1,:) char = 'logs'
    end
    
    %% Load and plot the flight
    if ~isempty( fileIn )
        [flog, ulog] = LoadLog( fileIn, dirIn );
    end
    FlightOverview
    
    % Get filename without the leading path
    [~, fileName, ~] = fileparts( ulog.FileName );

    %% Set-up the report
    import mlreportgen.report.*
    import mlreportgen.dom.*
    report = Report( fullfile( 'reports', fileName ) ,'pdf');

    %% Title page
    % Details
    titlePage = TitlePage();
    titlePage.Title    = 'Flight report';
    titlePage.Subtitle = [fileName '.ulog'];
    titlePage.Author   = '';

    % Add to report
    append( report, titlePage )
    append( report, TableOfContents() )
    append( report, ListOfFigures() )
    append( report, ListOfTables() )

    %% Important information
    chapterInfo = Chapter();
    chapterInfo.Title = 'PX4 Firmware details';
    detailTable = BaseTable( readSystemInformation(ulog) );
    detailTable.Title = 'System information.';

    append( chapterInfo, Paragraph( [ 'The table below lists the details ' ...
        'of the system used for the flight.' ] ) )
    append( chapterInfo, detailTable )
    append( report, chapterInfo )

    %% Add plots
    chapterPlots = Chapter();
    chapterPlots.Title = 'Responses';

    append( chapterPlots, Paragraph( [ 'The plots in this section show the ' ...
        'response of the UAV during the flight.' ] ) )

    % Include all open figures
    figHandles = get(groot, 'Children');
    for ii = length( figHandles ):-1:1
        curFig = Figure( figHandles(ii) );
        curFig.Snapshot.Caption = [figHandles(ii).Name '.'];
        append( chapterPlots, curFig )
    end

    append( report, chapterPlots )

    %% All parameters
    appendix = Chapter();
    appendix.Title = 'PX4 parameters';
    paramTable = BaseTable( readParameters(ulog) );
    paramTable.Title = 'PX4 firmware parameters.';

    append( appendix, Paragraph( [ 'The table below lists all PX4 firmware ' ...
        'parameters.' ] ) )
    append( appendix, paramTable )
    append( report, appendix )

    %% Publish report
    if ~exist( 'reports', 'dir' )
        mkdir( 'reports' )
    end
    close( report )
    rptview( report )
end