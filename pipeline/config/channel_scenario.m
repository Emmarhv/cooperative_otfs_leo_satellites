function scenario = channel_scenario()
% ============================================================
% channel_scenario.m
%
% Physical configuration shared by the cooperative baseline
% and the proposed different-grid method.
%
% This file contains scenario, geometry and link-budget
% parameters only. OTFS and simulation settings are defined in
% simulation_parameters.m.
%
% Published effective residual indices are kept only as
% validation references. They are not used as physical inputs.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Physical constants
% ------------------------------------------------------------
scenario.constants.speedOfLight = 299792458;       % m/s
scenario.constants.boltzmann = 1.380649e-23;       % J/K

% ------------------------------------------------------------
% 2. Carrier and link-budget parameters
% ------------------------------------------------------------
scenario.carrierFrequency = 13.5e9;                % Hz
scenario.eirpDbm = 67.7;                           % dBm
scenario.systemTemperature = 290;                  % K
scenario.rxElementGainDb = 0;                      % dB

% ------------------------------------------------------------
% 3. Constellation description
% ------------------------------------------------------------
scenario.constellation.numOrbitalPlanes = 72;
scenario.constellation.satellitesPerPlane = 22;
scenario.constellation.orbitAltitude = 550e3;      % m
scenario.constellation.inclinationDeg = 53;        % deg

% Walker phasing and orbital epoch are not reported.
scenario.constellation.walkerPhasing = [];
scenario.constellation.epoch = [];

% ------------------------------------------------------------
% 4. Earth-fixed reference beam
% ------------------------------------------------------------
scenario.referencePoint.name = 'Munich beam center';
scenario.referencePoint.positionEnu = [0; 0; 0];   % local origin
scenario.referencePoint.latitudeDeg = [];
scenario.referencePoint.longitudeDeg = [];

scenario.beam.radius = 50e3;                       % m

% ------------------------------------------------------------
% 5. Published dual-satellite snapshot
% ------------------------------------------------------------
% Local-frame angles:
% - azimuth   : clockwise from North
% - elevation : above the local horizon

scenario.satellites(1).name = 'Satellite 1';
scenario.satellites(1).slantRange = 588.08e3;      % m
scenario.satellites(1).elevationDeg = 68.35;       % deg
scenario.satellites(1).azimuthDeg = 359.91;        % deg
scenario.satellites(1).velocityEnu = [];

scenario.satellites(2).name = 'Satellite 2';
scenario.satellites(2).slantRange = 657.97e3;      % m
scenario.satellites(2).elevationDeg = 55.12;       % deg
scenario.satellites(2).azimuthDeg = 349.19;        % deg
scenario.satellites(2).velocityEnu = [];

% ------------------------------------------------------------
% 6. User position
% ------------------------------------------------------------
% The exact coordinates of Position 1 are not numerically
% reported and will be reconstructed later.
scenario.user.name = 'Position 1 user';
scenario.user.positionEnu = [];

% Current baseline assumes a stationary ground user.
scenario.user.velocityEnu = [0; 0; 0];

% ------------------------------------------------------------
% 7. Published residual values for validation only
% ------------------------------------------------------------
scenario.validationReference.ieff = 504;
scenario.validationReference.keff = -2;
scenario.validationReference.kappaeff = 0.236;

end