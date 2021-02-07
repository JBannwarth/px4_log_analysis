%COMPAREPOSITIONSENSORS Compare mocap, LIDAR-lite, and optical flow
%   Written: 2021/02/07, J.X.J. Bannwarth

%% Set-up
clearvars;
clc;
close all;
flog = LoadLog( '14_35_57.ulg' );
timeFormat = 'mm:ss.SS';

%% Get data
mocap = flog.vehicle_vision_position;
lidar = flog.distance_sensor;
flow  = flog.optical_flow;
ekf2  = flog.vehicle_local_position;

%% Plot data
% 2-D
figure( 'name', '2-D trajectories' )
% North
subplot( 3, 1, 1 ); hold on; box on; grid on;
plot( ekf2.timestamp, ekf2.x )
plot( mocap.timestamp, mocap.x )
ylabel( 'North, x (m)' )
xtickformat( timeFormat )

% East
subplot( 3, 1, 2 ); hold on; box on; grid on;
plot( ekf2.timestamp, ekf2.y )
plot( mocap.timestamp, mocap.y )
ylabel( 'East, y (m)' )
xtickformat( timeFormat )

% Down
subplot( 3, 1, 3 ); hold on; box on; grid on;
plot( ekf2.timestamp, ekf2.z )
plot( mocap.timestamp, mocap.z )
plot( flow.timestamp, -flow.ground_distance_m )
plot( lidar.timestamp, -lidar.current_distance )
set ( gca, 'ydir', 'reverse' )
ylim( [-2, 0] )
xlabel( 'Time from boot (HH:MM:SS)' )
ylabel( 'Down, z (m)' )
xtickformat( timeFormat )
legend( {'EKF2', 'Mocap', 'PX4Flow', 'LIDAR'}, 'location', 'best' )

% 3-D
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