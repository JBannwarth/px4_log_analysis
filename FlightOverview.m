%FLIGHTOVERVIEW Plot all important signals to give an overview of a flight
%   Written: 2021/02/07, J.X.J. Bannwarth

%% Set-up
clearvars;
clc;
close all;
flog = LoadLatestLog();
timeFormat = 'mm:ss.SS';

%% Get data
att   = flog.vehicle_attitude;
attSp = flog.vehicle_attitude_setpoint;
act   = flog.actuator_outputs;
pos   = flog.vehicle_local_position;
mode  = flog.vehicle_control_mode;
if isfield( flog, 'vehicle_local_position_setpoint' )
    posSp = flog.vehicle_local_position_setpoint;
end

%% Plot attitude
% Get Euler angles
att.eul   = rad2deg( QuatToEuler( att.q ) );
attSp.eul = rad2deg( QuatToEuler( attSp.q_d ) );

figure( 'name', 'Attitude' )
axs = { 'Roll', 'Pitch', 'Yaw' };
for ii = 1:length(axs)
    subplot( 3, 1, ii ); hold on; grid on; box on;
    plot( att.timestamp, att.eul(:,ii) )
    plot( attSp.timestamp, attSp.eul(:,ii) )
    ylabel( [ axs{ii} ' (deg)' ] )
    xtickformat( timeFormat )
end

% Extra info on bottom plot
xlabel( 'Time from boot (mm:ss)' )
legend( {'Estimated', 'Setpoint'}, 'location', 'best' )

%% Plot position/velocity
% Handle cases where no position setpoints have been given
if ~exist( 'posSp' )
    posSp = pos;
    for ii = 1:size( posSp, 2 )
        posSp{:,ii} = nan( size(posSp{:,ii}) );
    end
end

figure( 'name', 'Position' )
axs = { 'North, x', 'East, y', 'Down, z' };
for ii = 1:length(axs)
    subplot( 3, 1, ii ); hold on; grid on; box on;
    plot( pos.timestamp, pos{:,3+ii} )
    plot( posSp.timestamp, posSp{:,ii} )
    ylabel( [ axs{ii} ' (m)' ] )
    xtickformat( timeFormat )
    if ii == 3
        set ( gca, 'ydir', 'reverse' )
    end
end

% Extra info on bottom plot
xlabel( 'Time from boot (mm:ss)' )
legend( {'Estimated', 'Setpoint'}, 'location', 'best' )

figure( 'name', 'Velocity' )
for ii = 1:length(axs)
    subplot( 3, 1, ii ); hold on; grid on; box on;
    plot( pos.timestamp, pos{:,8+ii} )
    plot( posSp.timestamp, posSp{:,5+ii} )
    ylabel( [ axs{ii} ' vel (m/s)' ] )
    xtickformat( timeFormat )
end

% Extra info on bottom plot
xlabel( 'Time from boot (mm:ss)' )
legend( {'Estimated', 'Setpoint'}, 'location', 'best' )

%% Plot actuators
% Get simulation ordering
act.outputSim = RotorMapPx4ToSim( act.output, act.noutputs(1) );
act.outputMean = mean( act.outputSim, 2);

figure( 'name', 'Actuator outputs (simulation ordering)' )
hold on; grid on; box on;
colors = colororder;
colors = [colors(1:4,:); colors(1,:)];
for ii = 1:act.noutputs(1)
    if rem(ii, 2) == 0
        lineStyle = '--';
    else
        lineStyle = '-';
    end
    plot( act.timestamp, act.outputSim(:,ii), ...
        'color', colors(1+floor((ii-1)/2),:), 'linestyle', lineStyle ) 
end

xtickformat( timeFormat )
xlabel( 'Time from boot (mm:ss)' )
ylabel( 'PWM signal (us)' )
legend( { '1-FR', '2-RF', '3-RB', '4-BR', '5-BL', '6-LB', '7-LF', '8-FL'}, ...
    'location', 'best' )

figure( 'name', 'Actuator output diff (simulation ordering)' )
hold on; grid on; box on;
for ii = 1:act.noutputs(1)
    if rem(ii, 2) == 0
        lineStyle = '--';
    else
        lineStyle = '-';
    end
    plot( act.timestamp, act.outputSim(:,ii) - act.outputMean, ...
        'color', colors(1+floor((ii-1)/2),:), 'linestyle', lineStyle ) 
end

xtickformat( timeFormat )
xlabel( 'Time from boot (mm:ss)' )
ylabel( '\Delta PWM from mean (us)' )
legend( { '1-FR', '2-RF', '3-RB', '4-BR', '5-BL', '6-LB', '7-LF', '8-FL'}, ...
    'location', 'best' )