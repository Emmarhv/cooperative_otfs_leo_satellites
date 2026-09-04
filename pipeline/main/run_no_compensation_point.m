function result = run_no_compensation_point(config)
% ============================================================
% run_no_compensation_point.m
%
% Single-operating-point physical BER Monte Carlo engine for
% the official B3 ablation.
%
% B3 uses the same physical model as the compensated baseline:
%
%   M = 1024
%   N = 32
%   same residual delay and Doppler
%   same link budget
%   same noise model
%   same receiver processing
%   same Monte Carlo seed policy
%
% The only physical toggle is satellite-2 TX compensation:
%
%   applyPrecoder = true
%       Validation mode. Satellite 2 applies the same
%       compensation as the official baseline.
%
%   applyPrecoder = false
%       Actual B3 scenario. Satellite 2 transmits xDD directly,
%       without apply_precoder_blocks.
%
% The same resolved seed is deliberately used in both modes.
% This creates a paired Monte Carlo comparison: common frames
% use the same transmitted bits and random-noise sequence, so
% the relevant physical difference is the presence or absence
% of satellite-2 TX compensation.
%
% Physical chain:
%
%   bits -> QAM symbols -> M-by-N DD grid
%
%   Sat1:
%       otfs_modulate
%       -> los_channel(0,0,0,1)
%
%   Sat2:
%       optional apply_precoder_blocks
%       -> otfs_modulate
%       -> los_channel(iEff,kEff,kappaEff,1)
%
%   weighted time-domain combination
%   -> normalized complex noise
%   -> OTFS demodulation
%   -> equalization
%   -> QAM detection
%   -> BER
%
% Input:
% - config : struct returned by
%            build_official_config('no_compensation', ...)
%
% Output:
% - result : common official result struct
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Unpack configuration
% ------------------------------------------------------------

M = config.M;
N = config.N;
cpLength = config.cpLength;

iEff = config.iEff;
kEff = config.kEff;
kappaEff = config.kappaEff;

precoderBlocks = config.precoderBlocks;
applyPrecoder = config.applyPrecoder;

modulation = config.modulation;
NR = config.NR;

linkParams = config.linkParams;
slantRange = config.slantRange;

randomSeed = config.seed;
minErrors = config.targetErrors;
maxBits = config.maxBits;

Ts = config.Ts;
physicalSamples = config.physicalSamples;

% ------------------------------------------------------------
% 2. Modulation
% ------------------------------------------------------------

if strcmp(modulation, 'QPSK')

    qamParams = struct( ...
        'modOrder', 4, ...
        'bitsPerSymbol', 2);

elseif strcmp(modulation, '16-QAM')

    qamParams = struct( ...
        'modOrder', 16, ...
        'bitsPerSymbol', 4);

else

    error('run_no_compensation_point:UnknownModulation', ...
        'Unknown modulation "%s".', modulation);
end

symbolsPerFrame = M * N;

bitsPerFrame = ...
    symbolsPerFrame * qamParams.bitsPerSymbol;

% ------------------------------------------------------------
% 3. Link budget
% ------------------------------------------------------------

gamma1 = compute_link_snr( ...
    NR, ...
    slantRange(1), ...
    linkParams);

gamma2 = compute_link_snr( ...
    NR, ...
    slantRange(2), ...
    linkParams);

gammaOut = gamma1 + gamma2;

% ------------------------------------------------------------
% 4. Deterministic paired seed
% ------------------------------------------------------------

modSeedCode = ...
    baseline_modulation_seed_code(modulation);

nrSeedCode = ...
    nr_seed_code(NR);

resolvedSeed = ...
    randomSeed * 1e7 + ...
    modSeedCode * 1e6 + ...
    nrSeedCode * 1e4;

% IMPORTANT:
% Do not modify the seed according to applyPrecoder.
%
% The compensated and uncompensated cases intentionally use
% the same Monte Carlo stream. This makes B3 a paired ablation
% of B2 rather than an independent Monte Carlo experiment.
rng(resolvedSeed, 'twister');

% ------------------------------------------------------------
% 5. Monte Carlo frames
% ------------------------------------------------------------

errorCount = 0;
bitCount = 0;
frameCount = 0;

ticPoint = tic;

while errorCount < minErrors && bitCount < maxBits

    frameCount = frameCount + 1;

    % --------------------------------------------------------
    % Common transmitted payload
    % --------------------------------------------------------

    bits = ...
        randi([0 1], bitsPerFrame, 1);

    symbols = ...
        modulate_symbols(bits, qamParams);

    xDD = ...
        reshape(symbols, M, N);

    % --------------------------------------------------------
    % Satellite 1: synchronization reference
    % --------------------------------------------------------

    s1 = ...
        otfs_modulate(xDD, cpLength);

    r1 = ...
        los_channel( ...
            s1, ...
            M, ...
            N, ...
            0, ...
            0, ...
            0, ...
            1);

    % --------------------------------------------------------
    % Satellite 2: TX compensation toggle
    % --------------------------------------------------------

    if applyPrecoder

        pDD2 = ...
            apply_precoder_blocks( ...
                xDD, ...
                precoderBlocks, ...
                iEff);

    else

        % B3 ablation:
        % satellite 2 transmits the common DD payload directly.
        pDD2 = xDD;
    end

    s2 = ...
        otfs_modulate(pDD2, cpLength);

    r2 = ...
        los_channel( ...
            s2, ...
            M, ...
            N, ...
            iEff, ...
            kEff, ...
            kappaEff, ...
            1);

    % --------------------------------------------------------
    % Same receiver combining as the compensated baseline
    % --------------------------------------------------------

    % combine_weighted_links does not perform synchronization
    % or compensation. It only applies the frozen link weights.
    %
    % When applyPrecoder=false, the residual distortion of r2
    % is therefore intentionally preserved during combination.
    zClean = ...
        combine_weighted_links( ...
            r1, ...
            r2, ...
            gamma1, ...
            gamma2);

    zNoisy = ...
        add_normalized_complex_noise( ...
            zClean, ...
            gammaOut);

    % --------------------------------------------------------
    % OTFS demodulation and detection
    % --------------------------------------------------------

    yDD = ...
        otfs_demodulate( ...
            zNoisy, ...
            M, ...
            N, ...
            cpLength);

    xHatDD = ...
        yDD ./ gammaOut;

    symbolsHat = ...
        xHatDD(:);

    bitsHat = ...
        demodulate_symbols( ...
            symbolsHat, ...
            qamParams);

    % --------------------------------------------------------
    % Respect maxBits exactly
    % --------------------------------------------------------

    bitsRemaining = ...
        maxBits - bitCount;

    bitsToCompare = ...
        min(bitsPerFrame, bitsRemaining);

    [frameErrors, frameBits] = ...
        compute_ber( ...
            bits(1:bitsToCompare), ...
            bitsHat(1:bitsToCompare));

    errorCount = ...
        errorCount + frameErrors;

    bitCount = ...
        bitCount + frameBits;
end

elapsedSeconds = ...
    toc(ticPoint);

% ------------------------------------------------------------
% 6. BER metrics
% ------------------------------------------------------------

hitMaxBits = ...
    bitCount >= maxBits && ...
    errorCount < minErrors;

BER = ...
    errorCount / bitCount;

upper95 = NaN;

if errorCount == 0

    upper95 = ...
        compute_zero_error_upper_bound( ...
            bitCount, ...
            0.95);
end

% ------------------------------------------------------------
% 7. Throughput bookkeeping
% ------------------------------------------------------------

% Nominal useful throughput is identical to the baseline
% because the transmitted payload/framing is unchanged.
bitsPerBlock = ...
    bitsPerFrame;

blockDurationSeconds = ...
    physicalSamples * Ts;

% ------------------------------------------------------------
% 8. Assemble common result
% ------------------------------------------------------------

mcOut = struct();

mcOut.Ecomb = errorCount;
mcOut.BERcomb = BER;
mcOut.Nbits = bitCount;

mcOut.numRealizations = frameCount;
mcOut.hitMaxBits = hitMaxBits;
mcOut.upper95 = upper95;

mcOut.bitsPerBlock = bitsPerBlock;
mcOut.blockDurationSeconds = blockDurationSeconds;

mcOut.elapsedSeconds = elapsedSeconds;

% Store the actual seed used by this operating point for
% reproducibility metadata.
mcOut.resolvedSeed = resolvedSeed;

result = ...
    build_result_struct( ...
        config, ...
        mcOut);

end