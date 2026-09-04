function result = run_proposal_point(config)
% ============================================================
% run_proposal_point.m
%
% Single-operating-point physical BER Monte Carlo engine for
% the official N1~=N2 cooperative proposal.
%
% This is a single-point specialization of the validated
% load-tradeoff BER engine. The physical chain is unchanged.
%
% Physical chain:
%
%   common cooperative payload
%   -> active-symbol power policy
%   -> RCP framing and relative timing
%   -> physical differential Doppler
%   -> linear combination of satellite streams
%   -> common AWGN realization
%   -> Sat1/Sat2 receiver references
%   -> equalization
%   -> SNR-weighted cooperative combining
%   -> detection
%   -> BER
%
% Input:
% - config : struct returned by build_official_config.m
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

cfg = config.cfg;
physical = config.physical;
mapper = config.mapper;

modulation = config.modulation;
k = config.k;
powerPolicy = config.powerPolicy;
NR = config.NR;

delta = config.delta;
nuRelHz = config.nuRelHz;

Ts = cfg.sampleTime;
Ncommon = cfg.Ncommon;
blockLen = physical.blockLengthSat1;

numBlocksMain = config.numBlocksMain;
centerIdxMain = config.centerIdxMain;

linkParams = config.linkParams;
slantRange = config.slantRange;

randomSeed = config.seed;
minErrors = config.targetErrors;
maxBits = config.maxBits;

if mapper.k ~= k
    error('run_proposal_point:MapperKMismatch', ...
        'config.mapper.k does not match config.k.');
end

% ------------------------------------------------------------
% 2. Active-symbol power policy
% ------------------------------------------------------------

activePerRow = 2 * k;

switch powerPolicy

    case 'boosted'
        A = sqrt(Ncommon / activePerRow);

    case 'unboosted'
        A = 1;

    otherwise
        error('run_proposal_point:InvalidPowerPolicy', ...
            'Unknown power policy: %s.', powerPolicy);
end

% ------------------------------------------------------------
% 3. Modulation
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

    error('run_proposal_point:UnknownModulation', ...
        'Unknown modulation "%s".', modulation);
end

candidateSeedCode = ...
    candidate_seed_code(modulation, k);

% ------------------------------------------------------------
% 4. Mapper indices
% ------------------------------------------------------------

[sat1IdxAllRows, sat2IdxAllRows] = ...
    build_mapper_resource_indices( ...
        mapper, ...
        cfg.M, ...
        cfg.N1, ...
        cfg.activeRows);

sat1IdxAllRows = sat1IdxAllRows(:);
sat2IdxAllRows = sat2IdxAllRows(:);

blockSizeSat1 = ...
    cfg.K1 * cfg.M * cfg.N1;

blockSizeSat2 = ...
    cfg.M * cfg.N2;

bitsPerRealization = ...
    numel(sat1IdxAllRows) * qamParams.bitsPerSymbol;

% ------------------------------------------------------------
% 5. Link budget
% ------------------------------------------------------------

% Fixed lookup (not sorted position) so seeds for the four
% originally characterized N_R values never change when the
% N_R grid is extended. See nr_seed_code.m.
nrSeedCode = nr_seed_code(NR);

gamma1 = compute_link_snr( ...
    NR, ...
    slantRange(1), ...
    linkParams);

gamma2 = compute_link_snr( ...
    NR, ...
    slantRange(2), ...
    linkParams);

g1 = sqrt(gamma1);

% ------------------------------------------------------------
% 6. Monte Carlo initialization
% ------------------------------------------------------------

E1 = 0;
E2 = 0;
Ecomb = 0;

Nbits = 0;
r = 0;

dopplerInit = false;

dSrc = [];
dSat2AtRxConj = [];

firstResolvedSeed = NaN;
lastResolvedSeed = NaN;

ticPoint = tic;

% ------------------------------------------------------------
% 7. Monte Carlo realizations
% ------------------------------------------------------------

while true

    r = r + 1;

    seed = ...
        randomSeed * 1e7 + ...
        candidateSeedCode * 1e6 + ...
        nrSeedCode * 1e4 + ...
        r;

    if r == 1
        firstResolvedSeed = seed;
    end

    lastResolvedSeed = seed;

    rng(seed, 'twister');

    % --------------------------------------------------------
    % Common cooperative payload
    % --------------------------------------------------------

    payloads = generate_common_block_payloads( ...
        numBlocksMain, ...
        sat1IdxAllRows, ...
        sat2IdxAllRows, ...
        blockSizeSat1, ...
        blockSizeSat2, ...
        qamParams);

    txBitsCenter = ...
        payloads.txBits{centerIdxMain};

    txBitsCenter = ...
        txBitsCenter(:);

    if numel(txBitsCenter) ~= bitsPerRealization
        error('run_proposal_point:PayloadSizeMismatch', ...
            ['Unexpected number of useful bits in the ' ...
             'center realization.']);
    end

    % --------------------------------------------------------
    % Relative complex phase
    % --------------------------------------------------------

    phiRel = 2 * pi * rand();

    g2 = ...
        sqrt(gamma2) * exp(1j * phiRel);

    % --------------------------------------------------------
    % Active-resource power policy
    % --------------------------------------------------------

    dSat1Scaled = ...
        payloads.dSat1Blocks;

    dSat2Scaled = ...
        payloads.dSat2Blocks;

    for blockIdx = 1:numBlocksMain

        dSat1Scaled{blockIdx} = ...
            scale_active_symbols( ...
                payloads.dSat1Blocks{blockIdx}, ...
                sat1IdxAllRows, ...
                A);

        dSat2Scaled{blockIdx} = ...
            scale_active_symbols( ...
                payloads.dSat2Blocks{blockIdx}, ...
                sat2IdxAllRows, ...
                A);
    end

    % --------------------------------------------------------
    % Physical framing and relative timing
    % --------------------------------------------------------

    stream = build_and_combine_streams( ...
        dSat1Scaled, ...
        dSat2Scaled, ...
        cfg, ...
        delta);

    streamLen = numel(stream.s1Stream);

    % --------------------------------------------------------
    % Physical differential Doppler
    % --------------------------------------------------------

    if ~dopplerInit

        m = ...
            (0:streamLen-1).' - ...
            (stream.centerBlockIndex - 1) * blockLen;

        dSrc = exp( ...
            1j * 2 * pi * nuRelHz * m * Ts);

        dSat2AtRxConj = conj(exp( ...
            1j * 2 * pi * nuRelHz * ...
            (m - delta) * Ts));

        dopplerInit = true;
    end

    % --------------------------------------------------------
    % Satellite channels
    % --------------------------------------------------------

    s1Channel = ...
        g1 .* stream.s1Stream;

    s2Channel = ...
        g2 .* dSrc .* stream.s2Stream;

    combined = ...
        linear_shift_combine( ...
            s1Channel, ...
            s2Channel, ...
            delta);

    yRx1Clean = combined.y;

    % --------------------------------------------------------
    % Common thermal-noise realization
    % --------------------------------------------------------

    w = ...
        (randn(streamLen, 1) + ...
         1j * randn(streamLen, 1)) / sqrt(2);

    yRx1Noisy = ...
        yRx1Clean + w;

    % Sat2-referenced digital branch.
    yRx2Noisy = ...
        dSat2AtRxConj .* yRx1Noisy;

    % --------------------------------------------------------
    % OTFS demodulation
    % --------------------------------------------------------

    xrec1 = r1_sat1_demodulate_block( ...
        yRx1Noisy(stream.rx1Window), ...
        cfg.M, ...
        cfg.N1, ...
        cfg.Lcp);

    xrec2 = r2_sat2_demodulate_block( ...
        yRx2Noisy(stream.rx2Window), ...
        cfg.M, ...
        cfg.N2, ...
        cfg.Lcp);

    rxSym1 = ...
        xrec1(sat1IdxAllRows);

    rxSym2 = ...
        xrec2(sat2IdxAllRows);

    % --------------------------------------------------------
    % Equalization and cooperative combining
    % --------------------------------------------------------

    d1 = ...
        rxSym1 / (g1 * A);

    d2 = ...
        rxSym2 / (g2 * A);

    dHat = ...
        combine_snr_weighted( ...
            d1, ...
            d2, ...
            gamma1, ...
            gamma2);

    % --------------------------------------------------------
    % Detection
    % --------------------------------------------------------

    rxBits1 = ...
        demodulate_symbols(d1, qamParams);

    rxBits2 = ...
        demodulate_symbols(d2, qamParams);

    rxBitsComb = ...
        demodulate_symbols(dHat, qamParams);

    rxBits1 = rxBits1(:);
    rxBits2 = rxBits2(:);
    rxBitsComb = rxBitsComb(:);

    % --------------------------------------------------------
    % BER accumulation
    % --------------------------------------------------------

    [bitErr1, bitsCmp1] = ...
        compute_ber( ...
            txBitsCenter, ...
            rxBits1);

    [bitErr2, bitsCmp2] = ...
        compute_ber( ...
            txBitsCenter, ...
            rxBits2);

    [bitErrComb, bitsCmpComb] = ...
        compute_ber( ...
            txBitsCenter, ...
            rxBitsComb);

    if bitsCmp1 ~= bitsPerRealization || ...
            bitsCmp2 ~= bitsPerRealization || ...
            bitsCmpComb ~= bitsPerRealization

        error('run_proposal_point:BerSizeMismatch', ...
            ['BER comparison used an unexpected number ' ...
             'of useful bits.']);
    end

    E1 = E1 + bitErr1;
    E2 = E2 + bitErr2;
    Ecomb = Ecomb + bitErrComb;

    Nbits = Nbits + bitsCmp1;

    % --------------------------------------------------------
    % Stopping criterion
    % --------------------------------------------------------

    enoughErrors = ...
        E1 >= minErrors && ...
        E2 >= minErrors && ...
        Ecomb >= minErrors;

    if enoughErrors || Nbits >= maxBits
        break;
    end
end

elapsedSeconds = toc(ticPoint);

% ------------------------------------------------------------
% 8. BER metrics
% ------------------------------------------------------------

hitMaxBits = ...
    Nbits >= maxBits && ...
    ~(E1 >= minErrors && ...
      E2 >= minErrors && ...
      Ecomb >= minErrors);

BER1 = E1 / Nbits;
BER2 = E2 / Nbits;
BERcomb = Ecomb / Nbits;

upper95 = NaN;

if Ecomb == 0
    upper95 = compute_zero_error_upper_bound( ...
        Nbits, ...
        0.95);
end

% ------------------------------------------------------------
% 9. Throughput bookkeeping
% ------------------------------------------------------------

bitsPerBlock = ...
    bitsPerRealization;

blockDurationSeconds = ...
    blockLen * Ts;

% ------------------------------------------------------------
% 10. Assemble common result
% ------------------------------------------------------------

mcOut = struct();

mcOut.E1 = E1;
mcOut.E2 = E2;
mcOut.Ecomb = Ecomb;

mcOut.BER1 = BER1;
mcOut.BER2 = BER2;
mcOut.BERcomb = BERcomb;

mcOut.Nbits = Nbits;

mcOut.numRealizations = r;
mcOut.hitMaxBits = hitMaxBits;

mcOut.upper95 = upper95;

mcOut.amplitudeScale = A;

mcOut.bitsPerBlock = bitsPerBlock;
mcOut.blockDurationSeconds = blockDurationSeconds;

mcOut.elapsedSeconds = elapsedSeconds;

mcOut.firstResolvedSeed = firstResolvedSeed;
mcOut.lastResolvedSeed = lastResolvedSeed;

result = build_result_struct( ...
    config, ...
    mcOut);

end