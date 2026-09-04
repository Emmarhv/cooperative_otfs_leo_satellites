function result = build_load_tradeoff_result( ...
    berRow, rateRow, simulationMetadata, bandwidth)
% ============================================================
% build_load_tradeoff_result.m
%
% Package one already-computed load-tradeoff BER Monte Carlo
% result (a row from load_tradeoff_ber_boosted.mat or
% load_tradeoff_ber_unboosted.mat, joined with its matching
% row from rate_per_load_results.mat) into the common official
% result-struct schema used everywhere else in official/
% (see build_result_struct.m).
%
% This function performs NO simulation and calls NO B2/B3/B4
% engine. It only reformats numbers that are already stored on
% disk. All BER counters, error counts and stopping flags are
% taken verbatim from berRow; they are the source of truth and
% are never recomputed.
%
% Inputs:
% - berRow : one element of allResults from
%            load_tradeoff_ber_boosted.mat or
%            load_tradeoff_ber_unboosted.mat (already filtered
%            to the officially characterized family and
%            already matched to rateRow by modulation/k, and
%            to the caller's requested NR/powerPolicy)
% - rateRow : the matching element of rateResults from
%             rate_per_load_results.mat (same modulation/k)
% - simulationMetadata : the simulationMetadata struct stored
%             alongside berRow in the same BER .mat file
% - bandwidth : occupied bandwidth [Hz] (not stored in
%             simulationMetadata; supplied by the caller, same
%             value used to build rateRow.payloadSE)
%
% Output:
% - result : common official result struct, same schema as
%            build_result_struct.m, with an additional
%            result.source = 'load_tradeoff_archive' marker
%            and result.runtimeMetadata.candidateSeedCode /
%            .componentIds / .assignment / .status carried
%            through for traceability.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Consistency checks between the two joined rows
% ------------------------------------------------------------

if ~strcmp(berRow.modulation, rateRow.modulation)
    error('build_load_tradeoff_result:ModulationMismatch', ...
        'berRow/rateRow modulation mismatch: %s vs %s.', ...
        berRow.modulation, rateRow.modulation);
end

if berRow.k ~= rateRow.k
    error('build_load_tradeoff_result:LoadMismatch', ...
        'berRow/rateRow k mismatch: %d vs %d.', ...
        berRow.k, rateRow.k);
end

% ------------------------------------------------------------
% 2. Lightweight config-like struct (traceable, self-
%    contained; not produced by build_official_config, since
%    no B4 engine call is made here)
% ------------------------------------------------------------

config = struct();

config.scenario = 'proposal';
config.modulation = berRow.modulation;
config.k = berRow.k;
config.powerPolicy = berRow.powerPolicy;
config.NR = berRow.NR;

config.seed = simulationMetadata.randomSeed;
config.maxBits = simulationMetadata.maxBits;
config.targetErrors = simulationMetadata.minErrors;

config.delta = simulationMetadata.delta;
config.nuRelHz = simulationMetadata.nuRelHz;

config.mapper = struct();
config.mapper.rowUtilizationPct = rateRow.occupancyPct;

config.linkParams = struct();
config.linkParams.bandwidth = bandwidth;

config.characterizedNR = simulationMetadata.supportedNR;
config.finalComparisonNR = [64 100 144 256 400 576];
config.isCharacterizedNR = true;

% ------------------------------------------------------------
% 3. Monte Carlo counters (verbatim from the stored archive)
% ------------------------------------------------------------

mcOut = struct();

mcOut.Ecomb = berRow.Ecomb;
mcOut.BERcomb = berRow.BERcomb;
mcOut.Nbits = berRow.Nbits;

mcOut.numRealizations = berRow.numRealizations;
mcOut.hitMaxBits = berRow.hitMaxBits;
mcOut.upper95 = berRow.upper95BERcomb;

mcOut.amplitudeScale = berRow.amplitudeScale;

mcOut.E1 = berRow.E1;
mcOut.E2 = berRow.E2;
mcOut.BER1 = berRow.BER1;
mcOut.BER2 = berRow.BER2;

% ------------------------------------------------------------
% 4. Throughput/SE bookkeeping (taken from rateRow, the
%    validated independent rate computation; NOT recomputed
%    here from raw bits/samples)
% ------------------------------------------------------------

mcOut.bitsPerBlock = rateRow.usefulBits;

% Block duration from physicalSamples * Ts, matching the same
% formula build_result_struct.m applies elsewhere
% (throughputBps = bitsPerBlock / blockDurationSeconds). The
% module-level self-consistency check in main_load_tradeoff.m
% confirms this reproduces rateRow.throughputMbps /
% rateRow.payloadSE exactly, without recomputing them here.
mcOut.blockDurationSeconds = ...
    rateRow.physicalSamples * simulationMetadata.sampleTime;

mcOut.elapsedSeconds = NaN;

% ------------------------------------------------------------
% 5. Assemble common result
% ------------------------------------------------------------

result = build_result_struct(config, mcOut);

result.source = 'load_tradeoff_archive';

result.runtimeMetadata.candidateSeedCode = ...
    berRow.candidateSeedCode;

result.runtimeMetadata.componentIds = ...
    berRow.componentIds;

result.runtimeMetadata.assignment = ...
    berRow.assignment;

result.runtimeMetadata.status = ...
    berRow.status;

end
