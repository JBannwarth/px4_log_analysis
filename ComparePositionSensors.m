%COMPAREPOSITIONSENSORS Compare mocap, LIDAR-lite, and optical flow
%
%   Note that the altitude reported by the motion capture (mocap) system
%   will be dependent on the origin. In addition, the altitude reported by
%   the LIDAR-lite and optical flow sensors is dependent on the location of
%   those sensors and the user-set offset parameters in PX4 Firmware.
%
%   See also FLIGHTOVERVIEW, LOADLATESTLOG, LOADLOG.
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

timeFormat = 'mm:ss.SS';
xAxisLabel = 'Time from boot (mm:ss)';

%% Get data
mocap = flog.vehicle_vision_position;
lidar = flog.distance_sensor;
flow  = flog.optical_flow;
ekf2  = flog.vehicle_local_position;
mode  = flog.vehicle_control_mode;

%% Plot 2-D data
figure( 'name', '2-D trajectories' )
% North
subplot( 3, 1, 1 ); hold on; box on; grid on;
plot( ekf2.timestamp, ekf2.x )
plot( mocap.timestamp, mocap.x )

% Formatting
ylabel( 'North, x (m)' )
xtickformat( timeFormat )
axis tight
AddModeLabels( mode )

% East
subplot( 3, 1, 2 ); hold on; box on; grid on;
plot( ekf2.timestamp, ekf2.y )
plot( mocap.timestamp, mocap.y )

% Formatting
ylabel( 'East, y (m)' )
xtickformat( timeFormat )
axis tight
AddModeLabels( mode )

% Down
subplot( 3, 1, 3 ); hold on; box on; grid on;
plot( ekf2.timestamp, ekf2.z )
plot( mocap.timestamp, mocap.z )
plot( flow.timestamp, -flow.ground_distance_m )
plot( lidar.timestamp, -lidar.current_distance )

% Formatting
set ( gca, 'ydir', 'reverse' )
ylim( [-2, 0] )
xlabel( xAxisLabel )
ylabel( 'Down, z (m)' )
xtickformat( timeFormat )
legend( {'EKF2', 'Mocap', 'PX4Flow', 'LIDAR'}, 'location', 'best', ...
    'AutoUpdate', 'off' )
axis tight
AddModeLabels( mode, true )

%% Plot 3-D data
figure( 'name', '3-D trajectory' )
plot3( ekf2.x, ekf2.y, ekf2.z )
hold on; grid on; box on
plot3( mocap.x, mocap.y, mocap.z )
plot3( mocap.x(1), mocap.y(1), mocap.z(1), 'ko' )
xlabel( 'North, x (m)' )
ylabel( 'East, y (m)' )
zlabel( 'Down, z (m)' )
legend( {'EKF2', 'Mocap', 'Takeoff'} )
set( gca, 'ydir', 'reverse' )
set( gca, 'zdir', 'reverse' )