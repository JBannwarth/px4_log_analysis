function sim = RotorMapPx4ToSim( px4, nRotors )
%ROTORMAPPX4TOSIM Map px4 rotor order to simulation rotor order
%   [ SIM ] = ROTORMAPPX4TOSIM( PX4 ) converts rotor signal ordering
%   [ SIM ] = ROTORMAPPX4TOSIM( PX4, NROTORS ) specifies the number of rotors
%
%   Input:
%       - px4:     rotor signals in PX4 ordering
%       - nRotors: number of rotors
%   Output:
%       - sim:     rotor signals in simulation ordering (CCW around down)
%
%   By default handle 4x and 8x frames
%   Simulation ordering is incremental in CCW order (NED frame)
%   See link below for PX4 ordering:
%       https://dev.px4.io/en/airframes/airframe_reference.html
%
%   Written: J.X.J. Bannwarth, 2019/02/20
    arguments
        px4     (:,:) double
        nRotors (1,1) double = size(px4, 2)
    end
    
    switch nRotors
        case 4
            sim = px4( :, [1 4 2 3] );
        case 8
            sim = px4( :, [ 1 3 8 4 2 6 7 5 ] );
        otherwise
            error( 'Unrecognized number of rotors' );
    end
end