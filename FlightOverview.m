%FLIGHTOVERVIEW Plot all important signals to give an overview of a flight
%   Written: 2021/02/07, J.X.J. Bannwarth

%% Set-up
clearvars;
clc;
close all;
flog = LoadLog( '14_35_57.ulg' );
timeFormat = 'mm:ss.SS';

%% Get data
att   = flog.vehicle_attitude;
attSp = flog.vehicle_attitude_setpoint;
act   = flog.actuator_outputs;

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