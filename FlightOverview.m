%FLIGHTOVERVIEW Plot all important signals to give an overview of a flight
%
%   By default load the latest flight log. To plot other logs, call
%       [flog, ulog] = LoadLog( LOGNAME )
%   before running FLIGHTOVERVIEW.
%
%   Note that the north-east-down convention is used whenever applicable.
%   The axes for down velocities and positions are swapped around to
%   provide a more intuitive view of the system response.
%
%   See also LOADLOG, LOADLATESTLOG, COMPAREPOSITIONSENSORS.
%
%   Written: 2021/02/07, J.X.J. Bannwarth

%% Set-up
clc;
close all;
clearvars -except flog ulog;

% Only read-in data if it has not already been loaded
if ~exist( 'flog', 'var' )
    [flog, ulog] = LoadLatestLog();
end

% Formatting
timeFormat = 'mm:ss.SS';
xAxisLabel = 'Time from boot (mm:ss)';

%% Get data
att     = flog.vehicle_attitude;
attSp   = flog.vehicle_attitude_setpoint;
ratesSp = flog.vehicle_rates_setpoint;
act     = flog.actuator_outputs;
pos     = flog.vehicle_local_position;
mode    = flog.vehicle_control_mode;
rcIn    = flog.rc_channels;
manual  = flog.manual_control_setpoint;
battery = flog.battery_status;
if isfield( flog, 'vehicle_local_position_setpoint' )
    posSp = flog.vehicle_local_position_setpoint;
end
if any( strcmp( attSp.Properties.VariableNames, 'controller_selected' ) )
    ctrl = attSp(:, find(strcmp(fields(attSp), 'controller_selected')));
else
    ctrl = -1;
end

%% Plot attitude
% Get Euler angles
att.eul   = rad2deg( QuatToEuler( att.q ) );
attSp.eul = rad2deg( QuatToEuler( attSp.q_d ) );

% Plot
figure( 'name', 'Attitude' )
axs = { 'Roll', 'Pitch', 'Yaw' };
for ii = 1:length(axs)
    subplot( 3, 1, ii ); hold on; grid on; box on;
    plot( att.timestamp, att.eul(:,ii) )
    plot( attSp.timestamp, attSp.eul(:,ii) )
    
    % Format
    ylabel( [ axs{ii} ' (deg)' ] )
    xtickformat( timeFormat )
    AddModeLabels( mode, false, ctrl )
    axis tight
end

% Extra info on bottom plot
xlabel( xAxisLabel )
legend( {'Estimated', 'Setpoint'}, 'AutoUpdate', 'off' )

%% Plot attitude rates
figure( 'name', 'Attitude rates' )
axs = { 'Roll', 'Pitch', 'Yaw' };
for ii = 1:length(axs)
    subplot( 3, 1, ii ); hold on; grid on; box on;
    plot( att.timestamp, rad2deg( att.([lower(axs{ii}) 'speed']) ) )
    plot( ratesSp.timestamp, rad2deg( ratesSp.(lower(axs{ii})) ) )
    
    % Format
    ylabel( [ axs{ii} ' rate (deg/s)' ] )
    xtickformat( timeFormat )
    AddModeLabels( mode, false, ctrl )
    axis tight
end

% Extra info on bottom plot
xlabel( xAxisLabel )
legend( {'Estimated', 'Setpoint'}, 'AutoUpdate', 'off' )

%% Plot position
% Handle cases where no position setpoints have been given
if ~exist( 'posSp', 'var' )
    posSp = pos;
    for ii = 1:size( posSp, 2 )
        posSp{:,ii} = nan( size(posSp{:,ii}) );
    end
end

% Plot
figure( 'name', 'Position' )
axs = { 'North, x', 'East, y', 'Down, z' };
for ii = 1:length(axs)
    subplot( 3, 1, ii ); hold on; grid on; box on;
    plot( pos.timestamp, pos{:,3+ii} )
    plot( posSp.timestamp, posSp{:,ii} )
    
    % Format
    ylabel( [ axs{ii} ' (m)' ] )
    xtickformat( timeFormat )
    if ii == 3
        set ( gca, 'ydir', 'reverse' )
        AddModeLabels( mode, true, ctrl )
    else
        AddModeLabels( mode, false, ctrl )
    end
    axis tight
end

% Extra info on bottom plot
xlabel( xAxisLabel )
legend( {'Estimated', 'Setpoint'}, 'AutoUpdate', 'off' )

%% Plot velocity
figure( 'name', 'Velocity' )
for ii = 1:length(axs)
    subplot( 3, 1, ii ); hold on; grid on; box on;
    plot( pos.timestamp, pos{:,8+ii} )
    plot( posSp.timestamp, posSp{:,5+ii} )
    
    % Format
    ylabel( [ axs{ii} ' vel (m/s)' ] )
    xtickformat( timeFormat )
    if ii == 3
        set ( gca, 'ydir', 'reverse' )
        AddModeLabels( mode, true, ctrl )
    else
        AddModeLabels( mode, false, ctrl )
    end
    axis tight
end

% Extra info on bottom plot
xlabel( xAxisLabel )
legend( {'Estimated', 'Setpoint'}, 'AutoUpdate', 'off' )

%% Plot raw actuator outputs
% Get simulation ordering
act.outputSim = RotorMapPx4ToSim( act.output, act.noutputs(1) );
act.outputMean = mean( act.outputSim, 2);

% Rotor labels, assuming X-frame
if size(act.outputSim,2) == 4
    rotorLabels = { '1-FR', '2-BR', '3-BL', '4-FR' };
elseif size(act.outputSim,2) == 8
    rotorLabels = { '1-FR', '2-RF', '3-RB', '4-BR', '5-BL', '6-LB', ...
        '7-LF', '8-FL' };
else
    rotorLabels = cellstr( num2str( (1:size(act.outputSim,2) )') );
end

% Plot
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

% Format
xtickformat( timeFormat )
xlabel( xAxisLabel )
ylabel( 'PWM signal (us)' )
legend( rotorLabels, 'AutoUpdate', 'off', 'Location', 'best' )
AddModeLabels( mode, false, ctrl )
axis tight

%% Plot difference from mean actuator output
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

% Format
xtickformat( timeFormat )
xlabel( xAxisLabel )
ylabel( '\Delta PWM from mean (us)' )
legend( rotorLabels, 'AutoUpdate', 'off', 'Location', 'best' )
AddModeLabels( mode, false, ctrl )
axis tight

%% Plot RC channels
% Only plot the first 5 channels: roll, pitch, throttle, yaw, mode-switch
figure( 'name', 'RC channels' )
hold on; grid on; box on;
stairs( rcIn.timestamp, rcIn.channels(:, 1:5) )

% Format
xtickformat( timeFormat )
xlabel( xAxisLabel )
ylabel( 'Normalised RC input (-)' )
legend( {'1-roll', '2-pitch', '3-throttle', '4-yaw', '5-mode'}, ...
    'AutoUpdate', 'off', 'Location', 'best' )
xlim( [min(rcIn.timestamp), max(rcIn.timestamp)] )
ylim( [-1.1 1.1] )
AddModeLabels( mode, false, ctrl )

%% Plot manual control setpoints
% Redundant with RC channels but can be useful for debugging
figure( 'name', 'Manual control setpoints' )

% Analog signals
subplot( 2, 1, 1 )
hold on; grid on; box on;
stairs( manual.timestamp, manual{:,1:4} )

% Format
xtickformat( timeFormat )
xlabel( xAxisLabel )
ylabel( 'Normalised manual control (-)' )
legend( {'pitch stick', 'roll stick', 'throttle stick', 'yaw stick'}, ...
    'AutoUpdate', 'off', 'Location', 'best' )
xlim( [min(manual.timestamp), max(manual.timestamp)] )
ylim( [-1.1 1.1] )
AddModeLabels( mode, false, ctrl )
axis tight

% Mode slot - the mode selected depends on the drone configuration
subplot( 2, 1, 2 )
hold on; grid on; box on;
stairs( manual.timestamp, manual.mode_slot )

% Format
xlim( [min(manual.timestamp) max(manual.timestamp)] )
ylim( [min(double(manual.mode_slot))-0.5, max(double(manual.mode_slot))+0.5] )
xtickformat( timeFormat )
xlabel( xAxisLabel )
ylabel( 'Mode slot (-)' )
AddModeLabels( mode, false, ctrl )

%% Plot battery
figure( 'name', 'Battery status' )
axBattery = ones(1, 3);

% Voltage
axBattery(1) = subplot( 3, 1, 1 );
hold on; grid on; box on
stairs( battery.timestamp, battery.voltage_v );

% Format
ylabel( 'Battery voltage (V)' )
xtickformat( timeFormat )
xlim( [min(battery.timestamp), max(battery.timestamp)] )
AddModeLabels( mode, false, ctrl )
axis tight

% Current and discharged current
axBattery(2) = subplot( 3, 1, 2 );
hold on; grid on; box on;

% Current
yyaxis left
stairs( battery.timestamp, battery.current_a );
ylabel( 'Current drawn (A)' )

% Energy discharged
yyaxis right
stairs( battery.timestamp, battery.discharged_mah./1000 )
ylabel( 'Energy discharged (Ah)' )

% Format
xtickformat( timeFormat )
xlim( [min(battery.timestamp), max(battery.timestamp)] )
AddModeLabels( mode, false, ctrl )
axis tight

% Remaning battery
axBattery(3) = subplot( 3, 1, 3 );
hold on; grid on; box on
stairs( battery.timestamp, battery.remaining.*100 );

% Format
xlabel( xAxisLabel )
ylabel( 'Battery remaining (%)' )
xtickformat( timeFormat )
xlim( [min(battery.timestamp), max(battery.timestamp)] )
ylim( [-5, 105] )
AddModeLabels( mode, false, ctrl )
axis tight

% Link axes
linkaxes( axBattery ,'x' );

%% Plot horizontal thrust debugging values
if any( contains( fields(attSp), 'thrust_vec_1' ) )
    figure( 'name', 'Controller debug' )
    
    % x
    axController(1) = subplot( 3, 1, 1 );
    hold on; grid on; box on
    stairs( attSp.timestamp, attSp.thrust_vec_1(:,1) )
    stairs( attSp.timestamp, attSp.thrust_vec_2(:,1) )
    stairs( attSp.timestamp, attSp.hor_thrust_2(:,1) )
    ylabel( 'x-axis thrust (-)' )
    
    % Format
    legend( {'Baseline', 'H-inf', 'H-inf hor'}, ...
        'AutoUpdate', 'off', 'Location', 'best' )
    xtickformat( timeFormat )
    AddModeLabels( mode, false, ctrl )
    axis tight
    
    % y
    axController(2) = subplot( 3, 1, 2 );
    hold on; grid on; box on
    stairs( attSp.timestamp, attSp.thrust_vec_1(:,2) )
    stairs( attSp.timestamp, attSp.thrust_vec_2(:,2) )
    stairs( attSp.timestamp, attSp.hor_thrust_2(:,2) )
    ylabel( 'y-axis thrust (-)' )
    
    % Format
    xtickformat( timeFormat )
    AddModeLabels( mode, false, ctrl )
    axis tight
    
    % z
    axController(3) = subplot( 3, 1, 3 );
    hold on; grid on; box on
    stairs( attSp.timestamp, attSp.thrust_vec_1(:,3) )
    stairs( attSp.timestamp, attSp.thrust_vec_2(:,3) )
    ylabel( 'z-axis thrust (-)' )
    
    % Format
    xlabel( xAxisLabel )
    xtickformat( timeFormat )
    ylim( [-1, 0] )
    AddModeLabels( mode, false, ctrl )
    axis tight  
    linkaxes( axController, 'x' )
end