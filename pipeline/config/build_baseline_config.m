function config = build_baseline_config( ...
    modulation, NR, varargin)
% ------------------------------------------------------------
% build_baseline_config.m
%
% Assemble the official same-grid configuration shared by the
% 'baseline' (compensated) and 'no_compensation' scenarios.
%
% Both scenarios use the identical physical grid, residual
% offsets, precoder blocks and link budget; they differ only in
% whether the Satellite-2 residual precoder is actually applied
% at the receiver, controlled by the required 'ApplyPrecoder'
% name-value pair:
%
%   'ApplyPrecoder', true   -> baseline (compensated)
%   'ApplyPrecoder', false  -> no_compensation
%
% Every value assembled here is read directly from already
% validated sources; no new formulas are introduced:
%
%   simulation_parameters('baseline')   -> M, N, cpLength,
%                                           referenceCpLength,
%                                           samplePeriod,
%                                           precoderTruncationOrder,
%                                           bandwidth
%   channel_scenario()                  -> validationReference
%                                           (iEff, kEff, kappaEff),
%                                           satellite slant ranges,
%                                           link-budget constants
%   build_precoder_blocks_adapted(...)  -> precoderBlocks
%   reference_ber_parameters()          -> seed, minErrors, maxBits,
%                                           numRxElementsVec
%
% This mirrors the field-by-field mapping extracted (read-only)
% from the historical reference script main_baseline_no_geom.m.
%
% Optional overrides:
%
%   'Seed'          Monte Carlo base seed
%   'MaxBits'       Monte Carlo bit budget
%   'TargetErrors'  Monte Carlo error-count stopping criterion
%
% If omitted, all three recover the frozen nominal values from
% reference_ber_parameters().
% ------------------------------------------------------------

% ------------------------------------------------------------
% 1. Modulation
% ------------------------------------------------------------

modulation = normalize_modulation_label(modulation);

% ------------------------------------------------------------
% 2. Receive-array size
% ------------------------------------------------------------

validateattributes(NR, ...
    {'numeric'}, ...
    {'scalar', 'real', 'finite', 'integer', 'positive'}, ...
    mfilename, ...
    'NR');

% ------------------------------------------------------------
% 3. Optional overrides and required ApplyPrecoder flag
% ------------------------------------------------------------

isOptionalSeed = @(x) ...
    isempty(x) || ...
    (isnumeric(x) && isscalar(x) && isreal(x) && ...
     isfinite(x) && x >= 0 && x == floor(x));

isOptionalPositiveInteger = @(x) ...
    isempty(x) || ...
    (isnumeric(x) && isscalar(x) && isreal(x) && ...
     isfinite(x) && x > 0 && x == floor(x));

isScalarLogical = @(x) ...
    (islogical(x) && isscalar(x)) || ...
    (isnumeric(x) && isscalar(x) && (x == 0 || x == 1));

p = inputParser;

addParameter(p, ...
    'ApplyPrecoder', ...
    true, ...
    isScalarLogical);

addParameter(p, ...
    'Seed', ...
    [], ...
    isOptionalSeed);

addParameter(p, ...
    'MaxBits', ...
    [], ...
    isOptionalPositiveInteger);

addParameter(p, ...
    'TargetErrors', ...
    [], ...
    isOptionalPositiveInteger);

parse(p, varargin{:});

applyPrecoder = logical(p.Results.ApplyPrecoder);

% ------------------------------------------------------------
% 4. Centralized configuration sources
% ------------------------------------------------------------

scenarioRef = channel_scenario();
simParams = simulation_parameters('baseline');
berParams = reference_ber_parameters();

% ------------------------------------------------------------
% 5. OTFS grid and discrete-simulation CP
% ------------------------------------------------------------

M = simParams.M;
N = simParams.N;

% Discrete-simulation CP: los_channel.m operates directly on the
% useful CP-protected circular block, so cpLength = 0 here. This
% is distinct from the physical reduced CP used for throughput
% and spectral-efficiency reporting (see physicalSamples below).
cpLength = simParams.cpLength;

% ------------------------------------------------------------
% 6. Published residual snapshot
% ------------------------------------------------------------

% Effective residual delay/Doppler applied to Satellite 2 after
% reference-point compensation. Read directly from the frozen
% reference scenario, not recomputed from geometry.
iEff = scenarioRef.validationReference.ieff;
kEff = scenarioRef.validationReference.keff;
kappaEff = scenarioRef.validationReference.kappaeff;

% ------------------------------------------------------------
% 7. Truncated residual precoder (built once, always)
% ------------------------------------------------------------

% The precoder blocks are always constructed identically for
% both scenarios; only run_baseline_point.m /
% run_no_compensation_point.m decide, via applyPrecoder, whether
% they are actually applied to the Satellite-2 branch.
P = simParams.precoderTruncationOrder;

[precoderBlocks, numActiveCoeffs, cvec] = ...
    build_precoder_blocks_adapted( ...
    M, N, ...
    iEff, kEff, kappaEff, ...
    P);

% ------------------------------------------------------------
% 8. Link budget
% ------------------------------------------------------------

linkParams = struct();

linkParams.speedOfLight = ...
    scenarioRef.constants.speedOfLight;

linkParams.boltzmann = ...
    scenarioRef.constants.boltzmann;

linkParams.carrierFrequency = ...
    scenarioRef.carrierFrequency;

linkParams.eirpDbm = ...
    scenarioRef.eirpDbm;

linkParams.systemTemperature = ...
    scenarioRef.systemTemperature;

linkParams.rxElementGainDb = ...
    scenarioRef.rxElementGainDb;

linkParams.bandwidth = ...
    simParams.bandwidth;

rangeSat1 = scenarioRef.satellites(1).slantRange;
rangeSat2 = scenarioRef.satellites(2).slantRange;

slantRange = [rangeSat1, rangeSat2];

% Allowed receive-array sizes: the full characterized sweep used
% throughout the baseline/no_compensation Monte Carlo campaign.
characterizedNR = berParams.numRxElementsVec;

if ~ismember(NR, characterizedNR)
    error('build_baseline_config:UnsupportedNR', ...
        'NR=%d is not supported. Allowed values: %s.', ...
        NR, mat2str(characterizedNR));
end

% ------------------------------------------------------------
% 9. Physical sample count (throughput / spectral efficiency)
% ------------------------------------------------------------

% Physical reduced-CP OTFS frame length, distinct from the
% discrete-simulation cpLength = 0 used above.
physicalSamples = M * N + simParams.referenceCpLength;

Ts = simParams.samplePeriod;

% ------------------------------------------------------------
% 10. Monte Carlo parameters
% ------------------------------------------------------------

if isempty(p.Results.Seed)
    seed = berParams.randomSeed;
else
    seed = p.Results.Seed;
end

if isempty(p.Results.MaxBits)
    maxBits = berParams.maxBits;
else
    maxBits = p.Results.MaxBits;
end

if isempty(p.Results.TargetErrors)
    targetErrors = berParams.minErrors;
else
    targetErrors = p.Results.TargetErrors;
end

% ------------------------------------------------------------
% 11. Assemble output
% ------------------------------------------------------------

config = struct();

if applyPrecoder
    config.scenario = 'baseline';
else
    config.scenario = 'no_compensation';
end

config.modulation = modulation;
config.NR = NR;

config.M = M;
config.N = N;
config.cpLength = cpLength;

config.iEff = iEff;
config.kEff = kEff;
config.kappaEff = kappaEff;

config.precoderBlocks = precoderBlocks;
config.applyPrecoder = applyPrecoder;

% Retained for diagnostics/documentation, not required by
% run_baseline_point.m / run_no_compensation_point.m.
config.numActiveCoeffs = numActiveCoeffs;
config.cvec = cvec;

config.linkParams = linkParams;
config.slantRange = slantRange;

config.seed = seed;
config.maxBits = maxBits;
config.targetErrors = targetErrors;

config.Ts = Ts;
config.physicalSamples = physicalSamples;

config.characterizedNR = characterizedNR;

end
