function result = build_final_comparison_result( ...
    scenario, modulation, k, powerPolicy, NR, ...
    numErrors, numBits, storedUpper95, numRealizations, ...
    throughputMbps, payloadSE, occupancyPct, boostDb, seed, ...
    provenance)
% ============================================================
% build_final_comparison_result.m
%
% Normalize one already-computed, already-saved production
% Monte Carlo point (from any historical or official source
% file) into the common official result-struct schema used by
% final_comparison_results.mat.
%
% This function performs NO simulation. It only reformats
% numbers that are already stored on disk and, when a source
% file did not itself store a one-sided 95%% zero-error upper
% bound, computes that bound from the already-recorded bit
% count (a pure post-hoc statistical calculation, not a new
% Monte Carlo run).
%
% Inputs:
% - scenario     : 'single_satellite' | 'baseline_compensated'
%                  | 'no_compensation' | 'proposal'
% - modulation   : 'QPSK' or '16-QAM' (must be the explicit
%                  label from the source experiment metadata,
%                  never inferred from a stale cfg.modOrder
%                  field)
% - k            : NaN when not applicable (single_satellite,
%                  baseline_compensated, no_compensation)
% - powerPolicy  : 'not_applicable', 'boosted' or 'unboosted'
% - NR           : receive-array size
% - numErrors, numBits : verbatim counters from the source
% - storedUpper95 : the source file's own one-sided 95%% upper
%                  bound if it stored one, otherwise []/NaN
% - numRealizations, throughputMbps, payloadSE, occupancyPct,
%   boostDb, seed : verbatim/derived from the source
% - provenance   : struct describing exactly where this point
%                  came from (sourceFile, sourceField, notes)
%
% Output:
% - result : struct with fields
%     scenario, modulation, k, powerPolicy, NR
%     BER, numErrors, numBits, upper95, numRealizations
%     throughputMbps, payloadSE, occupancyPct, boostDb, seed
%     provenance
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate counters
% ------------------------------------------------------------

if numBits <= 0
    error('build_final_comparison_result:InvalidNumBits', ...
        'numBits must be positive (%s %s NR=%d).', ...
        scenario, modulation, NR);
end

if numErrors < 0 || numErrors > numBits
    error('build_final_comparison_result:InvalidNumErrors', ...
        'numErrors out of range (%s %s NR=%d).', ...
        scenario, modulation, NR);
end

BER = numErrors / numBits;

% ------------------------------------------------------------
% 2. Zero-error upper bound: use the source's own stored value
%    if present; otherwise compute it now from numBits (never
%    report a fabricated positive BER for a zero-error point)
% ------------------------------------------------------------

if numErrors > 0

    % An observed-error point never carries an upper bound.
    upper95 = NaN;

else

    if isempty(storedUpper95) || ~isfinite(storedUpper95)
        upper95 = compute_zero_error_upper_bound(numBits, 0.95);
    else
        upper95 = storedUpper95;
    end

    if ~isfinite(upper95) || upper95 <= 0
        error('build_final_comparison_result:InvalidUpperBound', ...
            ['Zero-error point without a valid 95%% upper ' ...
             'bound (%s %s NR=%d).'], ...
            scenario, modulation, NR);
    end
end

% ------------------------------------------------------------
% 3. Assemble output
% ------------------------------------------------------------

result = struct();

result.scenario = scenario;
result.modulation = modulation;
result.k = k;
result.powerPolicy = powerPolicy;
result.NR = NR;

result.BER = BER;
result.numErrors = numErrors;
result.numBits = numBits;
result.upper95 = upper95;
result.numRealizations = numRealizations;

result.throughputMbps = throughputMbps;
result.payloadSE = payloadSE;
result.occupancyPct = occupancyPct;
result.boostDb = boostDb;

result.seed = seed;

result.provenance = provenance;

end
