function summary = validate_official_baseline_vs_reference()
% ============================================================
% validate_official_baseline_vs_reference.m
%
% Bit-exact cross-check of the official baseline physics
% (the same function calls used inside run_baseline_point.m)
% against real, saved evidence produced by an actual past
% execution of the frozen script main_baseline_no_geom.m:
%
%   archive/baseline_validation_reference/baseline_no_geom_ber_results.mat
%
% The historical script resets rng() exactly ONCE
% (rng(berParams.randomSeed)) before its modulation x N_R
% sweep and then draws every frame from that single continuous
% stream, in a fixed loop order (QPSK then 16-QAM; N_R ordered
% as berParams.numRxElementsVec). Individual sweep points are
% therefore not independently reproducible in general -- EXCEPT
% the first one or two points immediately following the single
% reset, which this script reproduces exactly by replaying the
% same reset and the same first frames, with no shortcuts.
%
% This validation intentionally does NOT reset rng() per point
% (unlike the official runtime engine run_baseline_point.m,
% which uses a different, isolated-point seed policy -- see
% build_official_config.m). It exists only to prove that the
% physical chain reused by the official engine (otfs_modulate,
% los_channel, apply_precoder_blocks, combine_weighted_links,
% add_normalized_complex_noise, otfs_demodulate,
% demodulate_symbols, compute_ber) reproduces the frozen
% script bit-for-bit when driven the same way.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Project setup
% ------------------------------------------------------------

thisFolder = fileparts(mfilename('fullpath'));
projectRoot = thisFolder;

while ~isfolder(fullfile(projectRoot, 'pipeline'))

    parentFolder = fileparts(projectRoot);

    if strcmp(parentFolder, projectRoot)
        error('validate_official_baseline_vs_reference:ProjectRootNotFound', ...
            'Could not locate the project root.');
    end

    projectRoot = parentFolder;
end

addpath(genpath(projectRoot));

% ------------------------------------------------------------
% 2. Load real saved evidence from the frozen script
% ------------------------------------------------------------

evidenceFile = fullfile( ...
    projectRoot, 'archive', 'baseline_validation_reference', ...
    'baseline_no_geom_ber_results.mat');

if ~isfile(evidenceFile)
    error('validate_official_baseline_vs_reference:MissingEvidence', ...
        ['No saved baseline evidence found at:\n  %s\n' ...
         'Run main_baseline_no_geom.m at least once before ' ...
         'validating against it.'], evidenceFile);
end

evidence = load(evidenceFile);

% ------------------------------------------------------------
% 3. Rebuild the exact frozen-scenario physical parameters
% ------------------------------------------------------------

berParamsRef = reference_ber_parameters();
scenarioRef = channel_scenario();
simParamsRef = simulation_parameters('baseline');

M = simParamsRef.M;
N = simParamsRef.N;
cpLength = simParamsRef.cpLength;

iEff = scenarioRef.validationReference.ieff;
kEff = scenarioRef.validationReference.keff;
kappaEff = scenarioRef.validationReference.kappaeff;
P = simParamsRef.precoderTruncationOrder;

[precoderBlocks, ~, ~] = build_precoder_blocks_adapted( ...
    M, N, iEff, kEff, kappaEff, P);

linkParamsRef = struct();
linkParamsRef.speedOfLight = scenarioRef.constants.speedOfLight;
linkParamsRef.boltzmann = scenarioRef.constants.boltzmann;
linkParamsRef.carrierFrequency = scenarioRef.carrierFrequency;
linkParamsRef.eirpDbm = scenarioRef.eirpDbm;
linkParamsRef.systemTemperature = scenarioRef.systemTemperature;
linkParamsRef.rxElementGainDb = scenarioRef.rxElementGainDb;
linkParamsRef.bandwidth = simParamsRef.bandwidth;

rangeSat1 = scenarioRef.satellites(1).slantRange;
rangeSat2 = scenarioRef.satellites(2).slantRange;

numRxElementsVec = berParamsRef.numRxElementsVec;

modParams.modOrder = 4;
modParams.bitsPerSymbol = 2;
bitsPerFrame = M * N * modParams.bitsPerSymbol;

% ------------------------------------------------------------
% 4. Replay the historical single-reset continuous stream for
%    the first two QPSK operating points (NR=64, NR=100)
% ------------------------------------------------------------

rng(berParamsRef.randomSeed);

pointsToCheck = 2;
summary = repmat(struct( ...
    'nrIdx', NaN, 'NR', NaN, ...
    'refErrors', NaN, 'refBits', NaN, 'refFrames', NaN, ...
    'replicaErrors', NaN, 'replicaBits', NaN, 'replicaFrames', NaN, ...
    'pass', false), 1, pointsToCheck);

for nrIdx = 1:pointsToCheck

    NR = numRxElementsVec(nrIdx);

    gamma1 = compute_link_snr(NR, rangeSat1, linkParamsRef);
    gamma2 = compute_link_snr(NR, rangeSat2, linkParamsRef);
    gammaOut = gamma1 + gamma2;

    errorCount = 0;
    bitCount = 0;
    frameCount = 0;

    while errorCount < berParamsRef.minErrors && ...
            bitCount < berParamsRef.maxBits

        frameCount = frameCount + 1;

        bits = randi([0 1], bitsPerFrame, 1);
        symbols = modulate_symbols(bits, modParams);
        xDD = reshape(symbols, M, N);

        s1 = otfs_modulate(xDD, cpLength);
        r1 = los_channel(s1, M, N, 0, 0, 0, 1);

        pDD2 = apply_precoder_blocks(xDD, precoderBlocks, iEff);
        s2 = otfs_modulate(pDD2, cpLength);
        r2 = los_channel(s2, M, N, iEff, kEff, kappaEff, 1);

        zClean = combine_weighted_links(r1, r2, gamma1, gamma2);
        zNoisy = add_normalized_complex_noise(zClean, gammaOut);

        yDD = otfs_demodulate(zNoisy, M, N, cpLength);
        xHatDD = yDD ./ gammaOut;
        symbolsHat = xHatDD(:);
        bitsHat = demodulate_symbols(symbolsHat, modParams);

        bitsRemaining = berParamsRef.maxBits - bitCount;
        bitsToCompare = min(bitsPerFrame, bitsRemaining);

        [frameErrors, frameBits] = compute_ber( ...
            bits(1:bitsToCompare), bitsHat(1:bitsToCompare));

        errorCount = errorCount + frameErrors;
        bitCount = bitCount + frameBits;
    end

    refErrors = evidence.numErrors(1, nrIdx);
    refBits = evidence.numBits(1, nrIdx);
    refFrames = evidence.numFrames(1, nrIdx);

    pass = isequal(errorCount, refErrors) && ...
        isequal(bitCount, refBits) && ...
        isequal(frameCount, refFrames);

    summary(nrIdx).nrIdx = nrIdx;
    summary(nrIdx).NR = NR;
    summary(nrIdx).refErrors = refErrors;
    summary(nrIdx).refBits = refBits;
    summary(nrIdx).refFrames = refFrames;
    summary(nrIdx).replicaErrors = errorCount;
    summary(nrIdx).replicaBits = bitCount;
    summary(nrIdx).replicaFrames = frameCount;
    summary(nrIdx).pass = pass;

    fprintf( ...
        'QPSK NR=%-4d : ref(err=%d,bits=%d,frames=%d) replica(err=%d,bits=%d,frames=%d) : %s\n', ...
        NR, refErrors, refBits, refFrames, ...
        errorCount, bitCount, frameCount, ...
        local_pass_label(pass));
end

% ------------------------------------------------------------
% 5. Link-budget cross-check (all 9 historical N_R points,
%    independent of RNG)
% ------------------------------------------------------------

linkBudgetPass = true;

for nrIdx = 1:numel(numRxElementsVec)

    NR = numRxElementsVec(nrIdx);

    gamma1Check = compute_link_snr(NR, rangeSat1, linkParamsRef);
    gamma2Check = compute_link_snr(NR, rangeSat2, linkParamsRef);

    gamma1DbCheck = 10 * log10(gamma1Check);
    gamma2DbCheck = 10 * log10(gamma2Check);

    okG1 = abs(gamma1DbCheck - evidence.gamma1Db(nrIdx)) < 1e-9;
    okG2 = abs(gamma2DbCheck - evidence.gamma2Db(nrIdx)) < 1e-9;

    linkBudgetPass = linkBudgetPass && okG1 && okG2;
end

fprintf('Link budget (9 points) : %s\n', local_pass_label(linkBudgetPass));

% ------------------------------------------------------------
% 6. Overall verdict and evidence file
% ------------------------------------------------------------

allPass = all([summary.pass]) && linkBudgetPass;

fprintf('\nOVERALL: %s\n', local_pass_label(allPass));

resultsFolder = fullfile( ...
    projectRoot, 'results');

if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end

outFile = fullfile( ...
    resultsFolder, 'validate_official_baseline_vs_reference.mat');

save(outFile, 'summary', 'linkBudgetPass', 'allPass');

fprintf('Evidence saved: %s\n', outFile);

end


function label = local_pass_label(pass)

if pass
    label = 'PASS';
else
    label = 'FAIL';
end

end
