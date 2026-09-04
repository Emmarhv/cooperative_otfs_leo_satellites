function export_final_results_tables( ...
    mainResults, proposalPowerResults, ...
    boostedResults, unboostedResults, ...
    rateResults, outputDir)
% ============================================================
% export_final_results_tables.m
%
% Export the numerical results used by the final official
% reporting figures.
%
% Outputs:
%
%   main_results.csv
%   proposal_power_results.csv
%   load_tradeoff_results.csv
%   nominal_se_summary.csv
%
% No simulation is performed.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

if ~isfolder(outputDir)
    mkdir(outputDir);
end

% ------------------------------------------------------------
% 1. Main results
% ------------------------------------------------------------

Tmain = local_final_result_table(mainResults);

writetable( ...
    Tmain, ...
    fullfile(outputDir, 'main_results.csv'));

% ------------------------------------------------------------
% 2. Proposal power-policy results
% ------------------------------------------------------------

Tpower = ...
    local_final_result_table( ...
        proposalPowerResults);

writetable( ...
    Tpower, ...
    fullfile(outputDir, ...
        'proposal_power_results.csv'));

% ------------------------------------------------------------
% 3. Load-tradeoff results
% ------------------------------------------------------------

TloadBoosted = ...
    local_load_table( ...
        boostedResults, ...
        rateResults, ...
        'boosted');

TloadUnboosted = ...
    local_load_table( ...
        unboostedResults, ...
        rateResults, ...
        'unboosted');

Tload = [ ...
    TloadBoosted; ...
    TloadUnboosted];

writetable( ...
    Tload, ...
    fullfile(outputDir, ...
        'load_tradeoff_results.csv'));

% ------------------------------------------------------------
% 4. Compact nominal SE summary
% ------------------------------------------------------------

scenarioList = { ...
    'single_satellite', ...
    'baseline_compensated', ...
    'no_compensation', ...
    'proposal'};

modulations = {'QPSK', '16-QAM'};

scenario = strings(8, 1);
modulation = strings(8, 1);
throughputMbps = zeros(8, 1);
payloadSE = zeros(8, 1);

idx = 0;

for scenarioIdx = 1:numel(scenarioList)

    for modIdx = 1:numel(modulations)

        mask = ...
            strcmp( ...
                {mainResults.scenario}, ...
                scenarioList{scenarioIdx}) & ...
            strcmp( ...
                {mainResults.modulation}, ...
                modulations{modIdx});

        rows = mainResults(mask);

        if isempty(rows)
            error('export_final_results_tables:MissingSECombination', ...
                'Missing scenario/modulation combination.');
        end

        if max([rows.payloadSE]) - ...
                min([rows.payloadSE]) > 1e-12

            error('export_final_results_tables:SENotConstant', ...
                'Nominal SE changes unexpectedly with N_R.');
        end

        idx = idx + 1;

        scenario(idx) = ...
            string(scenarioList{scenarioIdx});

        modulation(idx) = ...
            string(modulations{modIdx});

        throughputMbps(idx) = ...
            rows(1).throughputMbps;

        payloadSE(idx) = ...
            rows(1).payloadSE;
    end
end

Tse = table( ...
    scenario, ...
    modulation, ...
    throughputMbps, ...
    payloadSE);

writetable( ...
    Tse, ...
    fullfile(outputDir, ...
        'nominal_se_summary.csv'));

fprintf('Saved reporting tables in:\n%s\n', outputDir);

end


% ============================================================
% Final comparison table
% ============================================================

function T = local_final_result_table(results)

scenario = string({results.scenario}.');
modulation = string({results.modulation}.');

NR = [results.NR].';
NRdB = 10 * log10(NR);

k = [results.k].';
powerPolicy = string({results.powerPolicy}.');

BER = [results.BER].';
upper95 = [results.upper95].';

numErrors = [results.numErrors].';
numBits = [results.numBits].';
numRealizations = [results.numRealizations].';

throughputMbps = [results.throughputMbps].';
payloadSE = [results.payloadSE].';

occupancyPct = [results.occupancyPct].';
boostDb = [results.boostDb].';

seed = [results.seed].';

sourceFile = strings(numel(results), 1);

for idx = 1:numel(results)

    if isfield(results(idx).provenance, 'sourceFile')
        sourceFile(idx) = ...
            string(results(idx).provenance.sourceFile);
    end
end

T = table( ...
    scenario, ...
    modulation, ...
    NR, ...
    NRdB, ...
    k, ...
    powerPolicy, ...
    BER, ...
    upper95, ...
    numErrors, ...
    numBits, ...
    numRealizations, ...
    throughputMbps, ...
    payloadSE, ...
    occupancyPct, ...
    boostDb, ...
    seed, ...
    sourceFile);

end


% ============================================================
% Load-tradeoff table
% ============================================================

function T = local_load_table( ...
    results, rateResults, powerPolicy)

officialNR = [64 144 256 400];

modulations = {'QPSK', '16-QAM'};

rows = struct( ...
    'modulation', {}, ...
    'powerPolicy', {}, ...
    'k', {}, ...
    'NR', {}, ...
    'NRdB', {}, ...
    'status', {}, ...
    'BER', {}, ...
    'upper95', {}, ...
    'numErrors', {}, ...
    'numBits', {}, ...
    'numRealizations', {}, ...
    'throughputMbps', {}, ...
    'payloadSE', {});

rowIdx = 0;

for modIdx = 1:numel(modulations)

    modulation = modulations{modIdx};

    if strcmp(modulation, 'QPSK')
        kList = [7 8 9 10];
    else
        kList = [4 5 6 7 8];
    end

    for kIdx = 1:numel(kList)

        k = kList(kIdx);

        rateMask = ...
            local_modulation_mask( ...
                rateResults, modulation) & ...
            [rateResults.k] == k;

        if nnz(rateMask) ~= 1
            error('export_final_results_tables:RateJoinMismatch', ...
                'Missing rate row for %s k=%d.', ...
                modulation, k);
        end

        rateRow = rateResults(rateMask);

        throughput = ...
            local_rate_throughput_mbps(rateRow);

        for nrIdx = 1:numel(officialNR)

            NR = officialNR(nrIdx);

            resultMask = ...
                local_modulation_mask( ...
                    results, modulation) & ...
                [results.k] == k & ...
                [results.NR] == NR;

            if nnz(resultMask) ~= 1
                error('export_final_results_tables:LoadJoinMismatch', ...
                    'Missing load row for %s k=%d NR=%d.', ...
                    modulation, k, NR);
            end

            r = results(resultMask);

            if r.Ecomb == 0

                if isfield(r, 'upper95BERcomb') && ...
                        isfinite(r.upper95BERcomb)

                    upper95 = ...
                        r.upper95BERcomb;

                else

                    upper95 = ...
                        1 - 0.05^(1 / r.Nbits);
                end

            else

                upper95 = NaN;
            end

            rowIdx = rowIdx + 1;

            rows(rowIdx).modulation = modulation;
            rows(rowIdx).powerPolicy = powerPolicy;
            rows(rowIdx).k = k;
            rows(rowIdx).NR = NR;
            rows(rowIdx).NRdB = 10 * log10(NR);

            if isfield(r, 'status')
                rows(rowIdx).status = r.status;
            else
                rows(rowIdx).status = '';
            end

            rows(rowIdx).BER = r.BERcomb;
            rows(rowIdx).upper95 = upper95;

            rows(rowIdx).numErrors = r.Ecomb;
            rows(rowIdx).numBits = r.Nbits;
            rows(rowIdx).numRealizations = ...
                r.numRealizations;

            rows(rowIdx).throughputMbps = throughput;
            rows(rowIdx).payloadSE = rateRow.payloadSE;
        end
    end
end

T = struct2table(rows);

end


function throughput = local_rate_throughput_mbps(rateRow)

if isfield(rateRow, 'throughputMbps')

    throughput = rateRow.throughputMbps;

elseif isfield(rateRow, 'throughputBps')

    throughput = ...
        rateRow.throughputBps / 1e6;

else

    throughput = NaN;
end

end


function mask = local_modulation_mask(results, requested)

mask = false(size(results));

requested = ...
    local_normalize_modulation(requested);

for idx = 1:numel(results)

    stored = ...
        local_normalize_modulation( ...
            results(idx).modulation);

    mask(idx) = ...
        strcmp(stored, requested);
end

end


function normalized = local_normalize_modulation(value)

value = ...
    upper(regexprep( ...
        char(value), ...
        '[^A-Z0-9]', ...
        ''));

if strcmp(value, 'QPSK')

    normalized = 'QPSK';

elseif strcmp(value, '16QAM') || ...
        strcmp(value, 'QAM16')

    normalized = '16QAM';

else

    error('export_final_results_tables:UnknownModulation', ...
        'Unknown modulation label: %s.', value);
end

end