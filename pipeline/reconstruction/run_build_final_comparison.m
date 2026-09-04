% ============================================================
% run_build_final_comparison.m
%
% One-click, read-only launcher that consolidates the FOUR
% official main scenarios into a single canonical archive:
%
%   results/final_comparison_results.mat
%
% for finalComparisonNR = [64 100 144 256 400 576], QPSK and
% 16-QAM:
%
%   1. single_satellite
%   2. baseline_compensated
%   3. no_compensation
%   4. proposal (nominal, boosted only: QPSK k=7 / 16-QAM k=4)
%
% The canonical archive contains two separate result sets:
%
%   mainResults
%       Four main comparison scenarios:
%       - single_satellite
%       - baseline_compensated
%       - no_compensation
%       - proposal boosted
%
%   proposalPowerResults
%       Separate boosted-vs-unboosted analysis of the nominal
%       heterogeneous-grid proposal.
%
% Explicitly OUT OF SCOPE:
%   - legacy independent-data / interference Scenario B.
%
% Proposal unboosted results are official, but they belong only
% to proposalPowerResults and are never treated as a fifth main
% scenario.
%
% Source files:
%   single_satellite      : comparison_scenarios/results/
%                           montecarlo_scenario_a_b_results.mat
%                           (allResultsA.QPSK / .QAM16)
%   baseline_compensated  : archive/baseline_validation_reference/
%                           baseline_no_geom_ber_results.mat
%   no_compensation       : results/
%                           no_compensation_final_results.mat
%   proposal QPSK k=7     : results/los_channel_noise/data/
%                           checkpoint_f_ber_montecarlo_results_finalized.mat
%   proposal 16-QAM k=4   : archive/proposal_16qam/
%                           results/
%                           checkpoint_f_16qam_ber_montecarlo_boosted_results.mat
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

clear;
clc;

fprintf('============================================================\n');
fprintf('FINAL COMPARISON CONSOLIDATION (read-only)\n');
fprintf('============================================================\n\n');

% ------------------------------------------------------------
% 1. Project setup
% ------------------------------------------------------------

thisFile = mfilename('fullpath');
thisFolder = fileparts(thisFile);

projectRoot = thisFolder;

while ~isfolder(fullfile(projectRoot, 'pipeline'))

    parentFolder = fileparts(projectRoot);

    if strcmp(parentFolder, projectRoot)
        error('run_build_final_comparison:ProjectRootNotFound', ...
            'Could not locate the project root.');
    end

    projectRoot = parentFolder;
end

addpath(genpath(projectRoot));

finalComparisonNR = [64 100 144 256 400 576];
modulations = {'QPSK', '16-QAM'};

% ------------------------------------------------------------
% 2. Common M=1024,N=32 frame constants (single_satellite,
%    baseline_compensated, no_compensation all share this
%    frame; only 'proposal' uses the RCP/framing-based
%    duration instead)
% ------------------------------------------------------------

simParamsBaseline = simulation_parameters('baseline');
berParamsBaseline = reference_ber_parameters();

M_sg = simParamsBaseline.M;
N_sg = simParamsBaseline.N;
Ts = simParamsBaseline.samplePeriod;
bandwidth = simParamsBaseline.bandwidth;
physicalSamples_sg = M_sg * N_sg + simParamsBaseline.referenceCpLength;

if physicalSamples_sg ~= 33791
    error('run_build_final_comparison:UnexpectedPhysicalSamples', ...
        'Expected 33791 physical samples for the M=1024,N=32 frame.');
end

% ------------------------------------------------------------
% 3. Load source files (read-only)
% ------------------------------------------------------------

fileA = fullfile(projectRoot, 'archive', 'comparison_scenarios', ...
    'montecarlo_scenario_a_b_results.mat');

fileBaseline = fullfile(projectRoot, 'archive', 'baseline_validation_reference', ...
    'baseline_no_geom_ber_results.mat');

fileNC = fullfile(projectRoot, 'results', ...
    'no_compensation_final_results.mat');

fileProposalQPSK = fullfile(projectRoot, 'archive', 'proposal_qpsk', ...
    'checkpoint_f_ber_montecarlo_results_finalized.mat');

fileProposal16QAM = fullfile(projectRoot, 'archive', 'proposal_16qam', ...
    'checkpoint_f_16qam_ber_montecarlo_boosted_results.mat');

local_require_file(fileA);
local_require_file(fileBaseline);
local_require_file(fileNC);
local_require_file(fileProposalQPSK);
local_require_file(fileProposal16QAM);

SA = load(fileA);
Sbaseline = load(fileBaseline);
SNC = load(fileNC);
SPropQPSK = load(fileProposalQPSK);
SProp16QAM = load(fileProposal16QAM);

fileProposalQPSKUnboosted = fullfile(projectRoot, 'archive', 'proposal_qpsk', ...
    'checkpoint_f_unboosted_ber_montecarlo_results.mat');

fileProposal16QAMUnboosted = fullfile(projectRoot, 'archive', 'proposal_16qam', ...
    'checkpoint_f_16qam_ber_montecarlo_unboosted_results.mat');

local_require_file(fileProposalQPSKUnboosted);
local_require_file(fileProposal16QAMUnboosted);

SPropQPSKUnboosted = load(fileProposalQPSKUnboosted);
SProp16QAMUnboosted = load(fileProposal16QAMUnboosted);

% Bandwidth consistency cross-check (proposal files store their
% own bandwidth; must match the same-grid bandwidth used above).
if abs(SPropQPSK.proposalBandwidth - bandwidth) > 1e-6
    error('run_build_final_comparison:BandwidthMismatch', ...
        'QPSK proposal bandwidth does not match the baseline bandwidth.');
end

if abs(SProp16QAM.proposalBandwidth - bandwidth) > 1e-6
    error('run_build_final_comparison:BandwidthMismatch', ...
        '16-QAM proposal bandwidth does not match the baseline bandwidth.');
end

if abs(SPropQPSKUnboosted.proposalBandwidth - bandwidth) > 1e-6
    error('run_build_final_comparison:BandwidthMismatch', ...
        'QPSK unboosted proposal bandwidth does not match the baseline bandwidth.');
end

if abs(SProp16QAMUnboosted.proposalBandwidth - bandwidth) > 1e-6
    error('run_build_final_comparison:BandwidthMismatch', ...
        '16-QAM unboosted proposal bandwidth does not match the baseline bandwidth.');
end

% ------------------------------------------------------------
% 4. Build the 48 normalized results
% ------------------------------------------------------------

allResults = cell(1, 48);
cellIdx = 0;

for modIdx = 1:2

    modulation = modulations{modIdx};

    if strcmp(modulation, 'QPSK')
        bitsPerSymbol_sg = 2;
        modOrderBaseline = 4;
        modKeyA = 'QPSK';
    else
        bitsPerSymbol_sg = 4;
        modOrderBaseline = 16;
        modKeyA = 'QAM16';
    end

    usefulBits_sg = M_sg * N_sg * bitsPerSymbol_sg;
    physicalDuration_sg = physicalSamples_sg * Ts;
    throughputMbps_sg = (usefulBits_sg / physicalDuration_sg) / 1e6;
    payloadSE_sg = (usefulBits_sg / physicalDuration_sg) / bandwidth;

    for nrIdx = 1:numel(finalComparisonNR)

        NR = finalComparisonNR(nrIdx);

        % ---------------- 1. single_satellite ----------------

        rowsA = SA.allResultsA.(modKeyA);
        matchA = find([rowsA.NR] == NR);

        if numel(matchA) ~= 1
            error('run_build_final_comparison:ScenarioAJoinMismatch', ...
                'Expected one Scenario A row for %s NR=%d, found %d.', ...
                modulation, NR, numel(matchA));
        end

        rowA = rowsA(matchA);

        provA = struct( ...
            'sourceFile', fileA, ...
            'sourceField', sprintf('allResultsA.%s', modKeyA), ...
            'notes', 'Single-satellite reference (y = g1*r1 + w).');

        resA = build_final_comparison_result( ...
            'single_satellite', modulation, NaN, 'not_applicable', NR, ...
            rowA.E, rowA.Nbits, rowA.BERupper95, rowA.numRealizations, ...
            throughputMbps_sg, payloadSE_sg, NaN, NaN, SA.baseSeed, provA);

        local_cross_check_ber(rowA.BER, resA.BER, ...
            'single_satellite', modulation, NR);

        cellIdx = cellIdx + 1;
        allResults{cellIdx} = resA;

        % ------------- 2. baseline_compensated -------------

        modMaskB = Sbaseline.modOrders == modOrderBaseline;
        nrMaskB = Sbaseline.numRxElementsVec == NR;

        if nnz(modMaskB) ~= 1 || nnz(nrMaskB) ~= 1
            error('run_build_final_comparison:BaselineJoinMismatch', ...
                'Expected exactly one baseline row for %s NR=%d.', ...
                modulation, NR);
        end

        errB = Sbaseline.numErrors(modMaskB, nrMaskB);
        bitsB = Sbaseline.numBits(modMaskB, nrMaskB);
        framesB = Sbaseline.numFrames(modMaskB, nrMaskB);
        berStoredB = Sbaseline.ber(modMaskB, nrMaskB);

        provB = struct( ...
            'sourceFile', fileBaseline, ...
            'sourceField', 'numErrors/numBits/numFrames (modOrders x numRxElementsVec)', ...
            'notes', ['No upper95 stored in this legacy file; ' ...
                'computed post-hoc from numBits when Ecomb=0. ' ...
                'No simulation re-run.']);

        resB = build_final_comparison_result( ...
            'baseline_compensated', modulation, NaN, 'not_applicable', NR, ...
            errB, bitsB, [], framesB, ...
            throughputMbps_sg, payloadSE_sg, NaN, NaN, ...
            berParamsBaseline.randomSeed, provB);

        local_cross_check_ber(berStoredB, resB.BER, ...
            'baseline_compensated', modulation, NR);

        cellIdx = cellIdx + 1;
        allResults{cellIdx} = resB;

        % ---------------- 3. no_compensation ----------------

        maskNC = strcmp({SNC.results.modulation}, modulation) & ...
            [SNC.results.NR] == NR;

        if nnz(maskNC) ~= 1
            error('run_build_final_comparison:NoCompJoinMismatch', ...
                'Expected exactly one no_compensation row for %s NR=%d.', ...
                modulation, NR);
        end

        rowNC = SNC.results(maskNC);

        resolvedSeedNC = rowNC.seed * 1e7 + ...
            baseline_modulation_seed_code(modulation) * 1e6 + ...
            nr_seed_code(NR) * 1e4;

        provNC = struct( ...
            'sourceFile', fileNC, ...
            'sourceField', 'results(i)', ...
            'notes', sprintf(['resolvedSeed=%.0f reconstructed during ' ...
                'consolidation (build_result_struct.m did not ' ...
                'propagate mcOut.resolvedSeed for B3; no ' ...
                're-simulation was performed).'], resolvedSeedNC));

        resNC = build_final_comparison_result( ...
            'no_compensation', modulation, NaN, 'not_applicable', NR, ...
            rowNC.numErrors, rowNC.numBits, rowNC.upper95, ...
            rowNC.runtimeMetadata.numRealizations, ...
            rowNC.throughputMbps, rowNC.payloadSE, NaN, NaN, ...
            rowNC.seed, provNC);

        local_cross_check_ber(rowNC.BER, resNC.BER, ...
            'no_compensation', modulation, NR);

        cellIdx = cellIdx + 1;
        allResults{cellIdx} = resNC;

        % ------------------- 4. proposal --------------------

        if strcmp(modulation, 'QPSK')
            SProp = SPropQPSK;
            fileProp = fileProposalQPSK;
        else
            SProp = SProp16QAM;
            fileProp = fileProposal16QAM;
        end

        maskProp = [SProp.results.NR] == NR;

        if nnz(maskProp) ~= 1
            error('run_build_final_comparison:ProposalJoinMismatch', ...
                'Expected exactly one proposal row for %s NR=%d.', ...
                modulation, NR);
        end

        rowProp = SProp.results(maskProp);

        blockDurationSeconds = SProp.physical.blockLengthSat1 * Ts;
        throughputMbpsProp = ...
            (SProp.bitsPerRealization / blockDurationSeconds) / 1e6;
        payloadSEProp = ...
            (SProp.bitsPerRealization / blockDurationSeconds) / bandwidth;

        occupancyPctProp = SProp.occupancyRatio * 100;
        boostDbProp = 10 * log10(SProp.energyScale);

        provProp = struct( ...
            'sourceFile', fileProp, ...
            'sourceField', 'results(i)', ...
            'notes', ['Nominal boosted proposal checkpoint. ' ...
                'Modulation label set explicitly by source file, ' ...
                'never inferred from cfg.modOrder.']);

        resProp = build_final_comparison_result( ...
            'proposal', modulation, SProp.mapper.k, 'boosted', NR, ...
            rowProp.Ecomb, rowProp.Nbits, rowProp.upper95BERcomb, ...
            rowProp.numRealizations, ...
            throughputMbpsProp, payloadSEProp, ...
            occupancyPctProp, boostDbProp, SProp.randomSeed, provProp);

        local_cross_check_ber(rowProp.BERcomb, resProp.BER, ...
            'proposal', modulation, NR);

        cellIdx = cellIdx + 1;
        allResults{cellIdx} = resProp;
    end
end

finalResults = [allResults{:}];

fprintf('Built %d normalized results.\n\n', numel(finalResults));
% ------------------------------------------------------------
% 5. Validation
% ------------------------------------------------------------

if numel(finalResults) ~= 48
    error('run_build_final_comparison:UnexpectedCount', ...
        'Expected exactly 48 results, got %d.', numel(finalResults));
end

expectedScenarios = { ...
    'single_satellite', 'baseline_compensated', ...
    'no_compensation', 'proposal'};

keys = cell(1, numel(finalResults));

for i = 1:numel(finalResults)

    r = finalResults(i);

    if ~ismember(r.scenario, expectedScenarios)
        error('run_build_final_comparison:UnexpectedScenario', ...
            'Unexpected scenario label: %s.', r.scenario);
    end

    if strcmp(r.scenario, 'proposal') ~= strcmp(r.powerPolicy, 'boosted')
        error('run_build_final_comparison:PowerPolicyMismatch', ...
            'powerPolicy inconsistent with scenario for entry %d.', i);
    end

    keys{i} = sprintf('%s|%s|%d', r.scenario, r.modulation, r.NR);
end

if numel(unique(keys)) ~= 48
    error('run_build_final_comparison:DuplicateKeys', ...
        'Duplicate scenario|modulation|NR keys detected.');
end

for sIdx = 1:numel(expectedScenarios)
    for modIdx = 1:2
        for nrIdx = 1:numel(finalComparisonNR)

            expectedKey = sprintf('%s|%s|%d', ...
                expectedScenarios{sIdx}, ...
                modulations{modIdx}, ...
                finalComparisonNR(nrIdx));

            if ~ismember(expectedKey, keys)
                error('run_build_final_comparison:MissingCombination', ...
                    'Missing combination: %s.', expectedKey);
            end
        end
    end
end

for i = 1:numel(finalResults)

    r = finalResults(i);

    if abs(r.BER - r.numErrors / r.numBits) > 1e-15
        error('run_build_final_comparison:BerFormulaMismatch', ...
            'BER ~= numErrors/numBits for entry %d.', i);
    end

    if r.numErrors == 0 && (~isfinite(r.upper95) || r.upper95 <= 0)
        error('run_build_final_comparison:MissingUpperBound', ...
            'Zero-error entry %d lacks a valid upper95 bound.', i);
    end

    if r.numErrors > 0 && ~isnan(r.upper95)
        error('run_build_final_comparison:UnexpectedUpperBound', ...
            'Observed-error entry %d unexpectedly carries an upper95 bound.', i);
    end
end

fprintf(['Validation PASS: 48 results, no duplicates, no missing ' ...
    'combinations, BER==numErrors/numBits, zero-error handling correct.\n\n']);

% ------------------------------------------------------------
% 5b. Build proposalPowerResults (24 points): official
%     boosted-vs-unboosted power-policy analysis for the
%     proposal. This is a SEPARATE analysis, not a fifth
%     "main scenario" -- it stays out of mainResults and is
%     never mixed with the 4-scenario comparison above.
% ------------------------------------------------------------

proposalPowerCell = cell(1, 24);
ppIdx = 0;

for modIdx = 1:2

    modulation = modulations{modIdx};

    if strcmp(modulation, 'QPSK')
        SBoosted = SPropQPSK;
        SUnboosted = SPropQPSKUnboosted;
        fileBoosted = fileProposalQPSK;
        fileUnboosted = fileProposalQPSKUnboosted;
    else
        SBoosted = SProp16QAM;
        SUnboosted = SProp16QAMUnboosted;
        fileBoosted = fileProposal16QAM;
        fileUnboosted = fileProposal16QAMUnboosted;
    end

    % ---- Same mapper/k/physical config between boosted and
    %      unboosted for this modulation (checked once, not
    %      per N_R) ----

    if SBoosted.mapper.k ~= SUnboosted.mapper.k
        error('run_build_final_comparison:PowerMapperKMismatch', ...
            '%s boosted/unboosted mapper.k differ.', modulation);
    end

    if ~isequal(SBoosted.mapper.componentIds, SUnboosted.mapper.componentIds) || ...
            ~isequal(SBoosted.mapper.assignment, SUnboosted.mapper.assignment)
        error('run_build_final_comparison:PowerMapperMismatch', ...
            '%s boosted/unboosted mapper differs.', modulation);
    end

    if SBoosted.bitsPerRealization ~= SUnboosted.bitsPerRealization || ...
            SBoosted.physical.blockLengthSat1 ~= SUnboosted.physical.blockLengthSat1
        error('run_build_final_comparison:PowerPhysicalConfigMismatch', ...
            '%s boosted/unboosted physical frame configuration differs.', modulation);
    end

    if SBoosted.A <= 1
        error('run_build_final_comparison:BoostedAmplitudeNotGreaterThanOne', ...
            '%s boosted amplitude scale A=%.6f is not > 1.', ...
            modulation, SBoosted.A);
    end

    if SUnboosted.A ~= 1
        error('run_build_final_comparison:UnboostedAmplitudeNotOne', ...
            '%s unboosted amplitude scale A=%.6f is not exactly 1.', ...
            modulation, SUnboosted.A);
    end

    k_pp = SBoosted.mapper.k;

    for nrIdx = 1:numel(finalComparisonNR)

        NR = finalComparisonNR(nrIdx);

        % -------- boosted --------

        maskBoosted = [SBoosted.results.NR] == NR;

        if nnz(maskBoosted) ~= 1
            error('run_build_final_comparison:PowerBoostedJoinMismatch', ...
                'Expected one boosted row for %s NR=%d, found %d.', ...
                modulation, NR, nnz(maskBoosted));
        end

        rowBoosted = SBoosted.results(maskBoosted);

        blockDurationBoosted = SBoosted.physical.blockLengthSat1 * Ts;
        throughputBoosted = (SBoosted.bitsPerRealization / blockDurationBoosted) / 1e6;
        seBoosted = (SBoosted.bitsPerRealization / blockDurationBoosted) / bandwidth;
        occupancyBoosted = SBoosted.occupancyRatio * 100;
        boostDbBoosted = 10 * log10(SBoosted.energyScale);

        provBoosted = struct( ...
            'sourceFile', fileBoosted, ...
            'sourceField', 'results(i)', ...
            'notes', 'Proposal power-policy analysis: boosted (A>1).');

        resBoosted = build_final_comparison_result( ...
            'proposal', modulation, k_pp, 'boosted', NR, ...
            rowBoosted.Ecomb, rowBoosted.Nbits, rowBoosted.upper95BERcomb, ...
            rowBoosted.numRealizations, ...
            throughputBoosted, seBoosted, occupancyBoosted, boostDbBoosted, ...
            SBoosted.randomSeed, provBoosted);

        local_cross_check_ber(rowBoosted.BERcomb, resBoosted.BER, ...
            'proposal(boosted)', modulation, NR);

        ppIdx = ppIdx + 1;
        proposalPowerCell{ppIdx} = resBoosted;

        % -------- unboosted --------

        maskUnboosted = [SUnboosted.results.NR] == NR;

        if nnz(maskUnboosted) ~= 1
            error('run_build_final_comparison:PowerUnboostedJoinMismatch', ...
                'Expected one unboosted row for %s NR=%d, found %d.', ...
                modulation, NR, nnz(maskUnboosted));
        end

        rowUnboosted = SUnboosted.results(maskUnboosted);

        blockDurationUnboosted = SUnboosted.physical.blockLengthSat1 * Ts;
        throughputUnboosted = (SUnboosted.bitsPerRealization / blockDurationUnboosted) / 1e6;
        seUnboosted = (SUnboosted.bitsPerRealization / blockDurationUnboosted) / bandwidth;
        occupancyUnboosted = SUnboosted.occupancyRatio * 100;
        boostDbUnboosted = 10 * log10(SUnboosted.energyScale);

        provUnboosted = struct( ...
            'sourceFile', fileUnboosted, ...
            'sourceField', 'results(i)', ...
            'notes', 'Proposal power-policy analysis: unboosted (A=1).');

        resUnboosted = build_final_comparison_result( ...
            'proposal', modulation, k_pp, 'unboosted', NR, ...
            rowUnboosted.Ecomb, rowUnboosted.Nbits, rowUnboosted.upper95BERcomb, ...
            rowUnboosted.numRealizations, ...
            throughputUnboosted, seUnboosted, occupancyUnboosted, boostDbUnboosted, ...
            SUnboosted.randomSeed, provUnboosted);

        local_cross_check_ber(rowUnboosted.BERcomb, resUnboosted.BER, ...
            'proposal(unboosted)', modulation, NR);

        ppIdx = ppIdx + 1;
        proposalPowerCell{ppIdx} = resUnboosted;

        % -------- throughput/SE equality check --------

        if abs(throughputBoosted - throughputUnboosted) > 1e-9 || ...
                abs(seBoosted - seUnboosted) > 1e-12
            error('run_build_final_comparison:PowerThroughputMismatch', ...
                ['Boosted/unboosted throughput or SE differ for ' ...
                 '%s NR=%d, but payload and physical duration ' ...
                 'should be identical.'], modulation, NR);
        end
    end
end

proposalPowerResults = [proposalPowerCell{:}];

fprintf('Built %d proposal power-policy results.\n\n', numel(proposalPowerResults));

% ------------------------------------------------------------
% 5c. Validate proposalPowerResults
% ------------------------------------------------------------

if numel(proposalPowerResults) ~= 24
    error('run_build_final_comparison:UnexpectedPowerCount', ...
        'Expected exactly 24 proposalPowerResults, got %d.', ...
        numel(proposalPowerResults));
end

numBoostedPP = nnz(strcmp({proposalPowerResults.powerPolicy}, 'boosted'));
numUnboostedPP = nnz(strcmp({proposalPowerResults.powerPolicy}, 'unboosted'));

if numBoostedPP ~= 12 || numUnboostedPP ~= 12
    error('run_build_final_comparison:UnexpectedPowerSplit', ...
        'Expected 12 boosted + 12 unboosted, got %d + %d.', ...
        numBoostedPP, numUnboostedPP);
end

ppKeys = cell(1, numel(proposalPowerResults));

for i = 1:numel(proposalPowerResults)
    r = proposalPowerResults(i);
    ppKeys{i} = sprintf('%s|%s|%d', r.modulation, r.powerPolicy, r.NR);
end

if numel(unique(ppKeys)) ~= 24
    error('run_build_final_comparison:PowerDuplicateKeys', ...
        'Duplicate modulation|powerPolicy|NR keys in proposalPowerResults.');
end

powerPolicies = {'boosted', 'unboosted'};

for modIdx = 1:2
    for polIdx = 1:2
        for nrIdx = 1:numel(finalComparisonNR)

            expectedKey = sprintf('%s|%s|%d', ...
                modulations{modIdx}, powerPolicies{polIdx}, ...
                finalComparisonNR(nrIdx));

            if ~ismember(expectedKey, ppKeys)
                error('run_build_final_comparison:PowerMissingCombination', ...
                    'Missing proposalPowerResults combination: %s.', expectedKey);
            end
        end
    end
end

for i = 1:numel(proposalPowerResults)
    r = proposalPowerResults(i);

    if abs(r.BER - r.numErrors / r.numBits) > 1e-15
        error('run_build_final_comparison:PowerBerFormulaMismatch', ...
            'BER ~= numErrors/numBits for proposalPowerResults entry %d.', i);
    end

    if r.numErrors == 0 && (~isfinite(r.upper95) || r.upper95 <= 0)
        error('run_build_final_comparison:PowerMissingUpperBound', ...
            'Zero-error proposalPowerResults entry %d lacks a valid upper95.', i);
    end

    if r.numErrors > 0 && ~isnan(r.upper95)
        error('run_build_final_comparison:PowerUnexpectedUpperBound', ...
            'Observed-error proposalPowerResults entry %d unexpectedly carries upper95.', i);
    end
end

fprintf(['proposalPowerResults validation PASS: 24 results (12+12), ' ...
    'no duplicates, no missing combinations, same mapper/k, ' ...
    'A>1 boosted / A=1 unboosted, matching throughput/SE.\n\n']);

mainResults = finalResults;

% ------------------------------------------------------------
% 6. Save canonical output (never overwrites any historical
%    source file: this is a brand-new consolidated archive)
% ------------------------------------------------------------

outFolder = fullfile(projectRoot, 'results');

if ~isfolder(outFolder)
    mkdir(outFolder);
end

outFile = fullfile(outFolder, 'final_comparison_results.mat');

metadata = struct();
metadata.finalComparisonNR = finalComparisonNR;
metadata.mainScenarios = expectedScenarios;
metadata.modulations = modulations;
metadata.numMainResults = numel(mainResults);
metadata.numProposalPowerResults = numel(proposalPowerResults);
metadata.excludedFromMainScenarios = { ...
    'legacy independent-data / interference Scenario B (dual ' ...
        'non-cooperative, out of TFG scope)', ...
    'proposal UNBOOSTED as a 5th main scenario (kept only as ' ...
        'the separate proposalPowerResults analysis below)'};
metadata.proposalPowerAnalysisNote = [ ...
    'proposalPowerResults is a SEPARATE official boosted-vs-' ...
    'unboosted power-policy analysis for the nominal proposal ' ...
    '(QPSK k=7, 16-QAM k=4). It is not one of the 4 main ' ...
    'scenarios and must not be mixed with mainResults. There ' ...
    'is no unboosted variant of B3 (no_compensation): B3 uses ' ...
    'powerPolicy=not_applicable, same-grid baseline physics.'];
metadata.sourceFiles = struct( ...
    'single_satellite', fileA, ...
    'baseline_compensated', fileBaseline, ...
    'no_compensation', fileNC, ...
    'proposal_qpsk_boosted', fileProposalQPSK, ...
    'proposal_16qam_boosted', fileProposal16QAM, ...
    'proposal_qpsk_unboosted', fileProposalQPSKUnboosted, ...
    'proposal_16qam_unboosted', fileProposal16QAMUnboosted);
metadata.generatedBy = mfilename('fullpath');
metadata.generatedAt = datestr(now);

save(outFile, 'mainResults', 'proposalPowerResults', 'metadata');

fprintf('============================================================\n');
fprintf('Saved canonical final comparison archive:\n%s\n', outFile);
fprintf('============================================================\n\n');


% ============================================================
% Local helpers
% ============================================================

function local_require_file(filePath)

if ~isfile(filePath)
    error('run_build_final_comparison:MissingFile', ...
        'Missing input file: %s', filePath);
end

end


function local_cross_check_ber(storedBer, recomputedBer, scenario, modulation, NR)

if isnan(storedBer) && isnan(recomputedBer)
    return;
end

if abs(storedBer - recomputedBer) > 1e-9
    error('run_build_final_comparison:StoredBerMismatch', ...
        ['Stored BER (%.6e) does not match recomputed ' ...
         'numErrors/numBits (%.6e) for %s %s NR=%d.'], ...
        storedBer, recomputedBer, scenario, modulation, NR);
end

end
