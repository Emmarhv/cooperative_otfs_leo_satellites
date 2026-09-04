function result = build_result_struct(config, mcOut)
% ============================================================
% build_result_struct.m
%
% Assemble the common official result struct.
%
% The same output schema is intended for:
%
%   proposal
%   baseline
%   no_compensation
%
% Scenario-specific quantities that do not have a physical
% meaning are represented as NaN or 'not_applicable'.
%
% In particular, baseline/no-compensation do not use the
% heterogeneous-grid load parameter k or active-resource boost.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Required common inputs
% ------------------------------------------------------------

requiredFields = { ...
    'Ecomb', ...
    'BERcomb', ...
    'Nbits', ...
    'numRealizations', ...
    'hitMaxBits', ...
    'upper95', ...
    'bitsPerBlock', ...
    'blockDurationSeconds', ...
    'elapsedSeconds'};

for idx = 1:numel(requiredFields)

    if ~isfield(mcOut, requiredFields{idx})
        error('build_result_struct:MissingMonteCarloField', ...
            'mcOut.%s is required.', ...
            requiredFields{idx});
    end
end

% ------------------------------------------------------------
% 2. Throughput and spectral efficiency
% ------------------------------------------------------------

if mcOut.blockDurationSeconds <= 0
    error('build_result_struct:InvalidDuration', ...
        'blockDurationSeconds must be positive.');
end

if config.linkParams.bandwidth <= 0
    error('build_result_struct:InvalidBandwidth', ...
        'Configured bandwidth must be positive.');
end

throughputBps = ...
    mcOut.bitsPerBlock / mcOut.blockDurationSeconds;

throughputMbps = ...
    throughputBps / 1e6;

payloadSE = ...
    throughputBps / config.linkParams.bandwidth;

% ------------------------------------------------------------
% 3. Scenario-specific metadata
% ------------------------------------------------------------

if strcmp(config.scenario, 'proposal')

    k = config.k;
    powerPolicy = config.powerPolicy;

    if ~isfield(config, 'mapper') || ...
            ~isfield(config.mapper, 'rowUtilizationPct')
        error('build_result_struct:MissingProposalMapper', ...
            'Proposal result requires mapper.rowUtilizationPct.');
    end

    if ~isfield(mcOut, 'amplitudeScale')
        error('build_result_struct:MissingAmplitudeScale', ...
            'Proposal result requires mcOut.amplitudeScale.');
    end

    occupancyPct = ...
        config.mapper.rowUtilizationPct;

    boostDb = ...
        20 * log10(mcOut.amplitudeScale);

else

    % These quantities do not apply to the same-grid baseline
    % or no-compensation scenarios.
    k = NaN;
    powerPolicy = 'not_applicable';
    occupancyPct = NaN;
    boostDb = NaN;
end

% ------------------------------------------------------------
% 4. Assemble common result
% ------------------------------------------------------------

result = struct();

result.config = config;

result.scenario = config.scenario;
result.modulation = config.modulation;

result.k = k;
result.powerPolicy = powerPolicy;
result.NR = config.NR;

result.numBits = mcOut.Nbits;
result.numErrors = mcOut.Ecomb;
result.BER = mcOut.BERcomb;
result.upper95 = mcOut.upper95;

result.throughputMbps = throughputMbps;
result.payloadSE = payloadSE;

result.occupancyPct = occupancyPct;
result.boostDb = boostDb;

% Monte Carlo BASE seed. This is distinct from any resolved
% per-point or per-realization seed.
result.seed = config.seed;

% ------------------------------------------------------------
% 5. Runtime metadata
% ------------------------------------------------------------

runtimeMetadata = struct();

runtimeMetadata.numRealizations = ...
    mcOut.numRealizations;

runtimeMetadata.hitMaxBits = ...
    mcOut.hitMaxBits;

runtimeMetadata.elapsedSeconds = ...
    mcOut.elapsedSeconds;

runtimeMetadata.E1 = ...
    local_optional_field(mcOut, 'E1', NaN);

runtimeMetadata.E2 = ...
    local_optional_field(mcOut, 'E2', NaN);

runtimeMetadata.BER1 = ...
    local_optional_field(mcOut, 'BER1', NaN);

runtimeMetadata.BER2 = ...
    local_optional_field(mcOut, 'BER2', NaN);

runtimeMetadata.amplitudeScale = ...
    local_optional_field(mcOut, 'amplitudeScale', NaN);

% Some engines use one resolved seed per operating point.
runtimeMetadata.resolvedSeed = ...
    local_optional_field(mcOut, 'resolvedSeed', NaN);

% The proposal engine may instead store the first and last
% resolved realization seeds used during its Monte Carlo run.
runtimeMetadata.firstResolvedSeed = ...
    local_optional_field(mcOut, 'firstResolvedSeed', NaN);

runtimeMetadata.lastResolvedSeed = ...
    local_optional_field(mcOut, 'lastResolvedSeed', NaN);

result.runtimeMetadata = runtimeMetadata;

end


% ============================================================
% Local helper
% ============================================================

function value = local_optional_field(S, fieldName, defaultValue)

if isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end

end