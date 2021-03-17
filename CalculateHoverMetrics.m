function metrics = CalculateHoverMetrics( flogs )
%CALCULATEHOVERMETRICS Calculate hover performance metrics.
%   METRICS = CALCULATEHOVERMETRICS( FLOGS ) calculates metrics for logs in FLOGS.
%
%   Inputs:
%       - flogs:     Individual flight log, cell array of flight log (i.e.
%                    a group), or a cell array of groups. Note: the logs
%                    are assumed to have been cropped and resampled prior
%                    to being passed to this function.
%   Outputs:
%       - metrics:   Table of performance metrics for each log, with group
%                    identifier and group categoricals.
%
%   See also COMPAREFLIGHTS.
%
%   Written: 2021/03/16, J.X.J. Bannwarth

    arguments
        flogs
    end
    
    %% Input processing
    % Convert individual log and or standalone group into the same format
    % as cell arrays of groups to simplify subsequent code
    if ~iscell(flogs)
        % Individual log
        flogs = {{flogs}};
        isIndividual = true;
    elseif ~iscell(flogs{1})
        % Standalone group
        flogs = {flogs};
        isIndividual = false;
    else
        % Array of groups
        isIndividual = false;
    end
    
    nLogs = sum( cellfun( @(x)( length(x) ), flogs ) );
    
    %% Initialize output table
    % Table column properties
    varNames = { 'group', 'identifier', 'avgPosErr', 'avgPosErrNorm', ...
        'rmsPosErr', 'rmsPosErrNorm', 'maxPosErr', 'maxPosNorm', 'avgAtt', ...
        'rmsAttErr', 'rmsqDist', 'maxqDist', 'maxAttErr', 'fileName' }';
    varTypes = { 'categorical', 'categorical', 'double', 'double', ...
        'double', 'double', 'double', 'double', 'double', ...
        'double', 'double', 'double', 'double', 'string' }';
    varUnits = { '', '', 'm', 'm', 'm', 'm', 'm', 'm', 'deg', 'deg', ...
        'deg', 'deg', 'deg', '' };
    
    % Create table
    metrics = table( 'Size', [nLogs 14], 'VariableNames', varNames, ...
        'VariableTypes', varTypes );
    metrics.Properties.VariableUnits = varUnits;
    
    % Cannot set dimensions right away, so go through and change column
    % dimensions
    isTriplet = ~contains( varNames, {'Norm', 'qDist'} ) & ...
        strcmp( varTypes, 'double' ) ;
    for ii = 1:length( varNames )
        if isTriplet(ii)
            metrics.(varNames{ii}) = zeros( nLogs, 3 );
        end
    end
    
    %% Compute metrics
    idx = 1;
    for ii = 1:length( flogs )
        for jj = 1:length( flogs{ii} )
             % Get important data
            pos   = flogs{ii}{jj}.vehicle_local_position;
            posSp = flogs{ii}{jj}.vehicle_local_position_setpoint;
            att   = flogs{ii}{jj}.vehicle_attitude;
            attSp = flogs{ii}{jj}.vehicle_attitude_setpoint;

            % Calculate position error
            posErr = [posSp.x posSp.y posSp.z] - [pos.x pos.y pos.z];
            posErrNorm = sqrt( sum( posErr.^2, 2 ) );
            
            % Calculate attitude error
            q     = quaternion( att.q );
            qDes  = quaternion( attSp.q_d );
            qErr  = conj(q) .* qDes;
            qDist = dist( q, qDes );
            attErr = eulerd( qErr, 'ZYX', 'frame' );
            attErr = attErr(:,[3 2 1]); % Switch to [roll pitch yaw]
            avgAtt = eulerd( meanrot(q), 'ZYX', 'frame' );
            avgAtt = avgAtt(:,[3 2 1]); % Switch to [roll pitch yaw]
            
            % Fill table
            if isIndividual
                metrics.group(idx)     = 'NA';
                metrics.identifier(idx)= 'NA';
            else
                metrics.group(idx)     = flogs{ii}{jj}.group;
                metrics.identifier(idx)= flogs{ii}{jj}.identifier(1:end-3);
            end
            metrics.avgPosErr(idx,:)   = mean( posErr, 1 );
            metrics.avgPosErrNorm(idx) = mean( posErrNorm );
            metrics.rmsPosErr(idx,:)   = rms( posErr, 1 );
            metrics.rmsPosErrNorm(idx) = rms( posErrNorm );
            metrics.maxPosErr(idx,:)   = max( abs(posErr), [], 1 );
            metrics.maxPosErrNorm(idx) = max( posErrNorm );
            metrics.avgAtt(idx,:)      = avgAtt;
            metrics.rmsAttErr(idx,:)   = rms( attErr, 1 );
            metrics.maxqDist(idx)      = rad2deg( max( qDist ) );
            metrics.maxAttErr(idx,:)   = max( abs(attErr), [], 1 );
            metrics.rmsqDist(idx)      = rad2deg( rms( qDist ) );
            metrics.fileName(idx)      = flogs{ii}{jj}.filename;
            
            idx = idx+1;
        end
    end 
end