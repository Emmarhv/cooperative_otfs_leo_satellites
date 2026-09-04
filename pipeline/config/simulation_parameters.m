function params = simulation_parameters(scenario)
% ============================================================
% simulation_parameters.m
%
% Centralized configuration for all simulation scenarios.
%
% Scenarios:
% - 'awgn'           : QAM over AWGN
% - 'otfs_awgn'      : OTFS over AWGN
% - 'single_los'     : single-satellite LoS channel
% - 'dual_no_comp'   : two satellites without precoding
% - 'baseline'       : cooperative system with common OTFS grid
% - 'different_grid' : proposed system with different Doppler
%                      grid sizes
%
% OTFS convention:
% - M : number of delay bins
% - N : number of Doppler bins
%
% Validation scenarios use Eb/N0.
% Physical cooperative scenarios use link-budget SNR gamma.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

if nargin == 0
    scenario = 'awgn';
end

% ------------------------------------------------------------
% 1. Common parameters
% ------------------------------------------------------------
params.modOrder = 4;              % Default: QPSK
params.modOrdersToTest = [4, 16];

% Monte Carlo stopping criteria.
params.minErrors = 200;
params.maxBits = 1e7;

% ------------------------------------------------------------
% 2. Scenario parameters
% ------------------------------------------------------------
switch scenario

    case 'awgn'
        % Phase 1: QAM + AWGN validation.
        params.ebN0DbVec = 0:2:20;
        params.numSymbolsFrame = 2500;

    case 'otfs_awgn'
        % Phase 2: OTFS should preserve the QAM + AWGN BER.
        params.M = 16;
        params.N = 16;

        params.ebN0DbVec = 0:2:20;

        % No channel delay is present.
        params.cpLength = 0;

        params.numSymbolsFrame = params.M * params.N;

    case 'single_los'
        % Phase 3: effective single-satellite LoS channel.
        params.M = 16;
        params.N = 16;

        params.ebN0DbVec = 0:2:20;

        % los_channel.m operates directly on the useful
        % CP-protected circular block.
        params.cpLength = 0;

        % Illustrative channel parameters, not derived from
        % satellite geometry.
        params.losDelayTap = 5;
        params.losDopplerTap = 3;
        params.losFractionalDoppler = 0.3;
        params.losGain = 0.6 * exp(1j * 0.4);

        params.numSymbolsFrame = params.M * params.N;

    case 'dual_no_comp'
        % Phase 4: satellite 1 is the synchronization reference.
        % Satellite 2 contains the residual differential
        % delay and Doppler.
        params.M = 16;
        params.N = 16;

        params.ebN0DbVec = 0:2:20;

        % Same useful-block circular-channel convention.
        params.cpLength = 0;

        % Satellite 1: zero residual offsets.
        params.sat1.h = 1;
        params.sat1.delayIndex = 0;
        params.sat1.dopplerIndex = 0;
        params.sat1.fractionalDoppler = 0;

        % Satellite 2: illustrative residual offsets.
        params.sat2.h = 1;
        params.sat2.delayIndex = 3;
        params.sat2.dopplerIndex = 2;
        params.sat2.fractionalDoppler = 0.25;

        params.numSymbolsFrame = params.M * params.N;

    case 'baseline'
        % Cooperative baseline: both satellites use the same
        % OTFS grid.
        %
        % The reference parameter table reports N = 128,
        % whereas the numerical-results section uses N = 32.
        params.M = 1024;
        params.N = 32;

        % Physical waveform parameters.
        params.subcarrierSpacing = 240e3;              % Hz

        params.symbolDuration = ...
            1 / params.subcarrierSpacing;              % s

        params.samplePeriod = ...
            1 / (params.M * params.subcarrierSpacing); % s

        params.bandwidth = ...
            params.M * params.subcarrierSpacing;       % Hz

        % los_channel.m works directly with the useful
        % CP-protected circular block.
        params.cpLength = 0;

        % Physical reduced CP of the reference system.
        params.referenceCpLength = params.M - 1;

        % Precoder truncation parameter P.
        % The mapping from P to the number of retained Doppler
        % coefficients will be fixed when the truncation model
        % is finalized.
        params.precoderTruncationOrder = 3;

        params.numSymbolsFrame = params.M * params.N;

    case 'different_grid'
        % Proposed system: common delay dimension M but
        % different Doppler dimensions N1 and N2.
        %
        % The physical channel parameters are intended to be
        % shared with the baseline scenario.
        params.M = 1024;
        params.N1 = 16;
        params.N2 = 32;

        % Physical waveform parameters.
        params.subcarrierSpacing = 240e3;              % Hz

        params.symbolDuration = ...
            1 / params.subcarrierSpacing;              % s

        params.samplePeriod = ...
            1 / (params.M * params.subcarrierSpacing); % s

        params.bandwidth = ...
            params.M * params.subcarrierSpacing;       % Hz

        % Useful-block simulation: CP samples are not added
        % explicitly before los_channel.m.
        params.cpLength1 = 0;
        params.cpLength2 = 0;

        % Physical reduced CP retained for validity checks and
        % future overhead / spectral-efficiency calculations.
        params.referenceCpLength1 = params.M - 1;
        params.referenceCpLength2 = params.M - 1;

        % Precoder truncation order P.
        % Its coefficient-count convention will be fixed later.
        params.precoderTruncationOrder = 3;

        params.numGridBinsSat1 = params.M * params.N1;
        params.numGridBinsSat2 = params.M * params.N2;

    otherwise
        error('simulation_parameters:UnknownScenario', ...
            'Unknown scenario: %s', scenario);
end

% ------------------------------------------------------------
% 3. Derived parameters
% ------------------------------------------------------------
params.bitsPerSymbol = log2(params.modOrder);

end