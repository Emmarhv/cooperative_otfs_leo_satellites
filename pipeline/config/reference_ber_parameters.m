function berParams = reference_ber_parameters()
% ============================================================
% reference_ber_parameters.m
%
% Configuration specific to the reference BER experiment.
%
% Physical parameters are defined in channel_scenario.m.
% OTFS and baseline simulation parameters are defined in
% simulation_parameters('baseline').
%
% This file contains only experiment-specific settings:
% - receive-array sweep;
% - tested modulations;
% - Monte Carlo stopping criteria;
% - random seed;
% - output configuration.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Receive-array sweep
% ------------------------------------------------------------

% Square receive arrays from 8x8 to 24x24.
berParams.arraySideVec = 8:2:24;

berParams.numRxElementsVec = ...
    berParams.arraySideVec.^2;

berParams.numRxElementsDbVec = ...
    10 * log10(berParams.numRxElementsVec);

% ------------------------------------------------------------
% 2. Modulation and Monte Carlo
% ------------------------------------------------------------
berParams.modOrdersToTest = [4, 16];

berParams.minErrors = 200;
berParams.maxBits = 2e7;
berParams.randomSeed = 1;

% ------------------------------------------------------------
% 3. Output options
% ------------------------------------------------------------
berParams.saveResults = true;

berParams.resultFolder = fullfile( ...
    'archive', 'baseline_validation_reference');

end