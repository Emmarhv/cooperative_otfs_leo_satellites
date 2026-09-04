function results = main_load_tradeoff()
% ============================================================
% main_load_tradeoff.m
%
% Official, read-only load-tradeoff pipeline.
%
% Loads the ALREADY VALIDATED AND SAVED load-tradeoff BER
% Monte Carlo archives and the already-computed rate/SE
% results, joins them by key (modulation, k, NR, powerPolicy),
% filters to the officially characterized family, and packages
% every point into the common official result-struct schema
% (build_result_struct.m / build_load_tradeoff_result.m).
%
% This script launches NO Monte Carlo simulation and calls NO
% B2/B3/B4 simulation engine (run_baseline_point,
% run_no_compensation_point, run_proposal_point,
% main_different_grid, ...). It only reads:
%
%   archive/load_tradeoff/
%       load_tradeoff_ber_boosted.mat
%       load_tradeoff_ber_unboosted.mat
%       rate_per_load_results.mat
%
% Officially characterized family (nominal marked with *):
%
%   QPSK    k = 7*, 8, 9, 10
%   16-QAM  k = 4*, 5, 6, 7, 8
%
% k > 10 (QPSK) / k > 8 (16-QAM) exist in the saved archives
% as additional experimental spot-checks (partial N_R
% coverage) but are NOT part of the officially characterized
% family and are explicitly excluded here. The archive .mat
% files themselves are never modified.
%
% N_R grid: only the four values that actually have saved
% Monte Carlo results are used here: [64 144 256 400]. N_R=100
% and N_R=576 belong to the later final-comparison grid
% (build_official_config.m finalComparisonNR) and are
% deliberately NOT interpolated or fabricated in this
% load-tradeoff study.
%
% Output:
% - results : struct with fields
%     .boosted    : 1x36 array of common result structs
%     .unboosted  : 1x36 array of common result structs
%     .all        : 1x72 array, [boosted, unboosted]
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Project setup
% ------------------------------------------------------------

mainFolder = fileparts(mfilename('fullpath'));
projectRoot = mainFolder;

while ~isfolder(fullfile(projectRoot, 'pipeline'))

    parentFolder = fileparts(projectRoot);

    if strcmp(parentFolder, projectRoot)
        error('main_load_tradeoff:ProjectRootNotFound', ...
            'Could not locate the project root.');
    end

    projectRoot = parentFolder;
end

addpath(genpath(projectRoot));

% ------------------------------------------------------------
% 2. Officially characterized family and N_R grid
% ------------------------------------------------------------

familyMod = { ...
    'QPSK', 'QPSK', 'QPSK', 'QPSK', ...
    '16-QAM', '16-QAM', '16-QAM', '16-QAM', '16-QAM'};

familyK = [7, 8, 9, 10, 4, 5, 6, 7, 8];

characterizedNR = [64 144 256 400];

% ------------------------------------------------------------
% 3. Load archives (read-only, no simulation)
% ------------------------------------------------------------

resultsDir = fullfile( ...
    projectRoot, 'archive', 'load_tradeoff');

boostedFile = fullfile(resultsDir, 'load_tradeoff_ber_boosted.mat');
unboostedFile = fullfile(resultsDir, 'load_tradeoff_ber_unboosted.mat');
rateFile = fullfile(resultsDir, 'rate_per_load_results.mat');

local_require_file(boostedFile);
local_require_file(unboostedFile);
local_require_file(rateFile);

Sboosted = load(boostedFile);
Sunboosted = load(unboostedFile);
Srate = load(rateFile);

% Bandwidth is not stored in simulationMetadata; it is the
% same fixed physical bandwidth already used to validate
% Srate.rateResults (cross-checked in Section 5 below).
bandwidth = simulation_parameters('baseline').bandwidth;

% ------------------------------------------------------------
% 4. Build the two 36-point result sets
% ------------------------------------------------------------

boostedResults = local_build_result_set( ...
    Sboosted, Srate, bandwidth, familyMod, familyK, characterizedNR);

unboostedResults = local_build_result_set( ...
    Sunboosted, Srate, bandwidth, familyMod, familyK, characterizedNR);

if numel(boostedResults) ~= 36
    error('main_load_tradeoff:UnexpectedBoostedCount', ...
        'Expected exactly 36 boosted results, got %d.', ...
        numel(boostedResults));
end

if numel(unboostedResults) ~= 36
    error('main_load_tradeoff:UnexpectedUnboostedCount', ...
        'Expected exactly 36 unboosted results, got %d.', ...
        numel(unboostedResults));
end

% ------------------------------------------------------------
% 5. Independent throughput/SE self-consistency check
%    (rate_per_load_results.mat vs. its own base columns; no
%    simulation, pure arithmetic, matches build_result_struct's
%    own throughput = bits/duration, SE = throughput/bandwidth)
% ------------------------------------------------------------

Ts = Sboosted.simulationMetadata.sampleTime;

for idx = 1:numel(Srate.rateResults)

    rr = Srate.rateResults(idx);

    physicalDuration = rr.physicalSamples * Ts;
    recomputedThroughputMbps = ...
        (rr.usefulBits / physicalDuration) / 1e6;
    recomputedSE = ...
        (rr.usefulBits / physicalDuration) / bandwidth;

    throughputOk = ...
        abs(recomputedThroughputMbps - rr.throughputMbps) < 1e-3;
    seOk = abs(recomputedSE - rr.payloadSE) < 1e-6;

    if ~throughputOk || ~seOk
        error('main_load_tradeoff:RateSelfConsistencyFailed', ...
            ['rate_per_load_results.mat internal mismatch for ' ...
             '%s k=%d: recomputed throughput=%.6f (stored %.6f), ' ...
             'recomputed SE=%.8f (stored %.8f).'], ...
            rr.modulation, rr.k, ...
            recomputedThroughputMbps, rr.throughputMbps, ...
            recomputedSE, rr.payloadSE);
    end
end

% ------------------------------------------------------------
% 6. Assemble output
% ------------------------------------------------------------

results = struct();
results.boosted = boostedResults;
results.unboosted = unboostedResults;
results.all = [boostedResults, unboostedResults];

fprintf('============================================================\n');
fprintf('OFFICIAL LOAD-TRADEOFF PIPELINE (read-only, archived results)\n');
fprintf('============================================================\n');
fprintf('Boosted results  : %d\n', numel(boostedResults));
fprintf('Unboosted results: %d\n', numel(unboostedResults));
fprintf('Total            : %d\n', numel(results.all));
fprintf('Rate/SE self-consistency check: PASS (%d candidates)\n', ...
    numel(Srate.rateResults));
fprintf('============================================================\n\n');

end


% ============================================================
% Local helpers
% ============================================================

function resultSet = local_build_result_set( ...
    Sber, Srate, bandwidth, familyMod, familyK, characterizedNR)

allResults = Sber.allResults;
simulationMetadata = Sber.simulationMetadata;

numFamily = numel(familyK);
numNR = numel(characterizedNR);

resultSet = cell(1, numFamily * numNR);
cellIdx = 0;

for famIdx = 1:numFamily

    modulation = familyMod{famIdx};
    k = familyK(famIdx);

    rateMask = local_modulation_key_match( ...
        {Srate.rateResults.modulation}, modulation) & ...
        [Srate.rateResults.k] == k;

    if nnz(rateMask) ~= 1
        error('main_load_tradeoff:RateJoinMismatch', ...
            'Expected exactly one rate result for %s k=%d, found %d.', ...
            modulation, k, nnz(rateMask));
    end

    rateRow = Srate.rateResults(rateMask);

    for nrIdx = 1:numNR

        NR = characterizedNR(nrIdx);

        berMask = local_modulation_key_match( ...
            {allResults.modulation}, modulation) & ...
            [allResults.k] == k & ...
            [allResults.NR] == NR;

        if nnz(berMask) ~= 1
            error('main_load_tradeoff:BerJoinMismatch', ...
                ['Expected exactly one BER result for %s k=%d ' ...
                 'NR=%d (%s), found %d.'], ...
                modulation, k, NR, Sber.powerPolicy, nnz(berMask));
        end

        berRow = allResults(berMask);

        cellIdx = cellIdx + 1;

        resultSet{cellIdx} = build_load_tradeoff_result( ...
            berRow, rateRow, simulationMetadata, bandwidth);
    end
end

resultSet = [resultSet{:}];

end


function mask = local_modulation_key_match(storedLabels, requested)

requestedNorm = local_normalize_modulation(requested);

mask = false(size(storedLabels));

for idx = 1:numel(storedLabels)
    mask(idx) = strcmp( ...
        local_normalize_modulation(storedLabels{idx}), requestedNorm);
end

end


function normalized = local_normalize_modulation(modulation)

value = upper(regexprep(char(modulation), '[^A-Z0-9]', ''));

if strcmp(value, 'QPSK')
    normalized = 'QPSK';
elseif strcmp(value, '16QAM') || strcmp(value, 'QAM16')
    normalized = '16QAM';
else
    error('main_load_tradeoff:UnknownModulation', ...
        'Unknown modulation label: %s', char(modulation));
end

end


function local_require_file(filePath)

if ~isfile(filePath)
    error('main_load_tradeoff:MissingFile', ...
        'Missing input file: %s', filePath);
end

end
