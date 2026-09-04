function result = run_baseline_point(config)
% ============================================================
% run_baseline_point.m
%
% Single-operating-point physical BER Monte Carlo engine for
% the official same-grid baseline (M=1024, N=32, P=3 truncated
% precoder), reproducing the published reference scenario.
%
% Physical chain (unchanged from main_baseline_no_geom.m):
%
%   bits -> QAM symbols -> M-by-N DD grid
%   Sat1: otfs_modulate -> los_channel(0,0,0,1)
%   Sat2: apply_precoder_blocks -> otfs_modulate
%         -> los_channel(iEff,kEff,kappaEff,1)
%   combine_weighted_links (gamma1, gamma2)
%   add_normalized_complex_noise (gammaOut)
%   otfs_demodulate
%   /gammaOut -> QAM detection -> BER
%
% Reproducibility: this function resets rng() once, from a
% seed built only out of this config's own fields (base seed,
% modulation code, N_R code). Every call with the same config
% therefore reproduces exactly, independent of call order or
% of any other operating point. This is a DIFFERENT
% reproducibility policy than the frozen historical script
% main_baseline_no_geom.m, which draws all of its
% modulation x N_R sweep from one continuous RNG stream. See
% build_official_config.m and
% official/validation/run_legacy_baseline_sweep.m for the
% historical-equivalence regression.
%
% Input:
% - config : struct returned by
%            build_official_config('baseline', ...)
%
% Output:
% - result : common official result struct, see
%            build_result_struct.m
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
    error('run_baseline_point:UnknownModulation', ...
        'Unknown modulation "%s".', modulation);
end

symbolsPerFrame = M * N;
bitsPerFrame = symbolsPerFrame * qamParams.bitsPerSymbol;

% ------------------------------------------------------------
% 3. Link budget
% ------------------------------------------------------------

gamma1 = compute_link_snr(NR, slantRange(1), linkParams);
gamma2 = compute_link_snr(NR, slantRange(2), linkParams);
gammaOut = gamma1 + gamma2;

% ------------------------------------------------------------
% 4. Deterministic per-point seed
% ------------------------------------------------------------

modSeedCode = baseline_modulation_seed_code(modulation);
nrSeedCode = nr_seed_code(NR);

resolvedSeed = ...
    randomSeed * 1e7 + ...
    modSeedCode * 1e6 + ...
    nrSeedCode * 1e4;

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

    bits = randi([0 1], bitsPerFrame, 1);

    symbols = modulate_symbols(bits, qamParams);

    xDD = reshape(symbols, M, N);

    % ----------------------------------------------------
    % Satellite 1: synchronization reference
    % ----------------------------------------------------

    s1 = otfs_modulate(xDD, cpLength);

    r1 = los_channel(s1, M, N, 0, 0, 0, 1);

    % ----------------------------------------------------
    % Satellite 2: P=3 transmitter compensation
    % ----------------------------------------------------

    pDD2 = apply_precoder_blocks( ...
        xDD, precoderBlocks, iEff);

    s2 = otfs_modulate(pDD2, cpLength);

    r2 = los_channel( ...
        s2, M, N, iEff, kEff, kappaEff, 1);

    % ----------------------------------------------------
    % Cooperative clean combination and noise
    % ----------------------------------------------------

    zClean = combine_weighted_links( ...
        r1, r2, gamma1, gamma2);

    zNoisy = add_normalized_complex_noise( ...
        zClean, gammaOut);

    % ----------------------------------------------------
    % Single OTFS demodulator after combination
    % ----------------------------------------------------

    yDD = otfs_demodulate(zNoisy, M, N, cpLength);

    xHatDD = yDD ./ gammaOut;

    symbolsHat = xHatDD(:);

    bitsHat = demodulate_symbols(symbolsHat, qamParams);

    % ----------------------------------------------------
    % Respect maxBits exactly
    % ----------------------------------------------------

    bitsRemaining = maxBits - bitCount;
    bitsToCompare = min(bitsPerFrame, bitsRemaining);

    [frameErrors, frameBits] = compute_ber( ...
        bits(1:bitsToCompare), ...
        bitsHat(1:bitsToCompare));

    errorCount = errorCount + frameErrors;
    bitCount = bitCount + frameBits;
end

elapsedSeconds = toc(ticPoint);

% ------------------------------------------------------------
% 6. BER metrics
% ------------------------------------------------------------

hitMaxBits = bitCount >= maxBits && errorCount < minErrors;

BER = errorCount / bitCount;

upper95 = NaN;

if errorCount == 0
    upper95 = compute_zero_error_upper_bound(bitCount, 0.95);
end

% ------------------------------------------------------------
% 7. Throughput bookkeeping (same formula as
%    compute_user_rate.m / compute_rate_comparison.m, not
%    reinvented: throughput = usefulBits / (samples*Ts))
% ------------------------------------------------------------

bitsPerBlock = bitsPerFrame;
blockDurationSeconds = physicalSamples * Ts;

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

mcOut.resolvedSeed = resolvedSeed;

result = build_result_struct(config, mcOut);

end
