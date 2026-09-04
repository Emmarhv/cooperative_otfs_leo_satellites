function config = build_proposal_config( ...
    modulation, k, powerPolicy, NR, varargin)
% ------------------------------------------------------------
% build_proposal_config.m
%
% Assemble the official heterogeneous-grid proposal
% configuration.
%
% Extracted unmodified from the 'proposal' branch of
% build_official_config.m (the previous single-scenario
% implementation). Only the input signature changed: the
% 'scenario' argument was removed because this function is now
% called exclusively for the 'proposal' scenario, dispatched by
% build_official_config.m.
%
% Optional proposal-specific sensitivity overrides:
%
%   'Delta'       residual timing offset [samples], integer
%   'NuRelHz'     residual Doppler offset [Hz]
%   'RangeSat1'   satellite-1 slant range [m], positive
%   'RangeSat2'   satellite-2 slant range [m], positive
%
% If omitted, all four parameters recover exactly the frozen
% nominal proposal configuration.
% ------------------------------------------------------------

% ------------------------------------------------------------
% 1. Modulation
% ------------------------------------------------------------

modulation = normalize_modulation_label(modulation);

% ------------------------------------------------------------
% 2. Load
% ------------------------------------------------------------

validateattributes(k, ...
    {'numeric'}, ...
    {'scalar', 'real', 'finite', 'integer', 'positive'}, ...
    mfilename, ...
    'k');

% ------------------------------------------------------------
% 3. Power policy
% ------------------------------------------------------------

if isstring(powerPolicy)

    if ~isscalar(powerPolicy)
        error('build_proposal_config:InvalidPowerPolicy', ...
            'powerPolicy must be a scalar string or character vector.');
    end

    powerPolicy = char(powerPolicy);
end

if ~ischar(powerPolicy)
    error('build_proposal_config:InvalidPowerPolicy', ...
        'powerPolicy must be a scalar string or character vector.');
end

powerPolicy = lower(strtrim(powerPolicy));

if ~ismember(powerPolicy, {'boosted', 'unboosted'})
    error('build_proposal_config:InvalidPowerPolicy', ...
        'powerPolicy must be ''boosted'' or ''unboosted''.');
end

% ------------------------------------------------------------
% 4. Receive-array size
% ------------------------------------------------------------

validateattributes(NR, ...
    {'numeric'}, ...
    {'scalar', 'real', 'finite', 'integer', 'positive'}, ...
    mfilename, ...
    'NR');

% ------------------------------------------------------------
% 5. Optional overrides
% ------------------------------------------------------------

isOptionalSeed = @(x) ...
    isempty(x) || ...
    (isnumeric(x) && isscalar(x) && isreal(x) && ...
     isfinite(x) && x >= 0 && x == floor(x));

isOptionalPositiveInteger = @(x) ...
    isempty(x) || ...
    (isnumeric(x) && isscalar(x) && isreal(x) && ...
     isfinite(x) && x > 0 && x == floor(x));

% Residual timing is implemented as an integer sample shift.
isOptionalInteger = @(x) ...
    isempty(x) || ...
    (isnumeric(x) && isscalar(x) && isreal(x) && ...
     isfinite(x) && x == floor(x));

% Residual Doppler may be any finite real value in Hz.
isOptionalReal = @(x) ...
    isempty(x) || ...
    (isnumeric(x) && isscalar(x) && isreal(x) && ...
     isfinite(x));

% Physical slant ranges must be strictly positive.
isOptionalPositiveReal = @(x) ...
    isempty(x) || ...
    (isnumeric(x) && isscalar(x) && isreal(x) && ...
     isfinite(x) && x > 0);

p = inputParser;

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

% Proposal sensitivity-analysis overrides.
%
% Defaults are unchanged:
%   Delta   = 504 samples
%   NuRelHz = -13.23 kHz
addParameter(p, ...
    'Delta', ...
    [], ...
    isOptionalInteger);

addParameter(p, ...
    'NuRelHz', ...
    [], ...
    isOptionalReal);

% Slant-range overrides.
%
% Defaults are taken directly from channel_scenario().
% Units are meters.
addParameter(p, ...
    'RangeSat1', ...
    [], ...
    isOptionalPositiveReal);

addParameter(p, ...
    'RangeSat2', ...
    [], ...
    isOptionalPositiveReal);

parse(p, varargin{:});

% ------------------------------------------------------------
% 6. Frozen mapper
% ------------------------------------------------------------

mapper = get_mapper_config(modulation, k);

% ------------------------------------------------------------
% 7. Physical proposal configuration
% ------------------------------------------------------------

cfg = nominal_proposal_config_1024_16_64();

physical = nominal_block_framing_16_64(cfg);

% Frozen nominal residual values unless explicitly overridden.
if isempty(p.Results.Delta)
    delta = 504;
else
    delta = p.Results.Delta;
end

if isempty(p.Results.NuRelHz)
    nuRelHz = -13.23e3;
else
    nuRelHz = p.Results.NuRelHz;
end

% Recompute the required physical runway for the actual delta
% of this operating point. This is essential for the timing
% sensitivity sweep, especially for large positive/negative
% residual offsets.
nSide = required_side_blocks( ...
    [0 delta], ...
    physical.blockLengthSat1);

numBlocksMain = 2 * nSide + 1;
centerIdxMain = nSide + 1;

% ------------------------------------------------------------
% 8. Link budget
% ------------------------------------------------------------

% Receive-array sizes already characterized in the completed
% load-tradeoff study.
characterizedNR = [64 144 256 400];

% Full grid used throughout the final official comparison and
% the present sensitivity study.
finalComparisonNR = [64 100 144 256 400 576];

if ~ismember(NR, finalComparisonNR)
    error('build_proposal_config:UnsupportedNR', ...
        'NR=%d is not supported. Allowed values: %s.', ...
        NR, mat2str(finalComparisonNR));
end

isCharacterizedNR = ismember(NR, characterizedNR);

scenarioRef = channel_scenario();
simParamsBaseline = simulation_parameters('baseline');
berParamsBaseline = reference_ber_parameters();

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
    simParamsBaseline.bandwidth;

% Nominal published slant ranges unless explicitly overridden.
if isempty(p.Results.RangeSat1)
    rangeSat1 = scenarioRef.satellites(1).slantRange;
else
    rangeSat1 = p.Results.RangeSat1;
end

if isempty(p.Results.RangeSat2)
    rangeSat2 = scenarioRef.satellites(2).slantRange;
else
    rangeSat2 = p.Results.RangeSat2;
end

slantRange = [rangeSat1, rangeSat2];

% ------------------------------------------------------------
% 9. Monte Carlo parameters
% ------------------------------------------------------------

if isempty(p.Results.Seed)
    seed = berParamsBaseline.randomSeed;
else
    seed = p.Results.Seed;
end

if isempty(p.Results.MaxBits)
    maxBits = berParamsBaseline.maxBits;
else
    maxBits = p.Results.MaxBits;
end

if isempty(p.Results.TargetErrors)
    targetErrors = berParamsBaseline.minErrors;
else
    targetErrors = p.Results.TargetErrors;
end

% ------------------------------------------------------------
% 10. Assemble output
% ------------------------------------------------------------

config = struct();

config.scenario = 'proposal';
config.modulation = modulation;
config.k = k;
config.powerPolicy = powerPolicy;
config.NR = NR;

% Base seed. run_proposal_point.m resolves the deterministic
% per-realization seed from this value and the operating-point
% configuration.
config.seed = seed;

config.maxBits = maxBits;
config.targetErrors = targetErrors;

config.cfg = cfg;
config.physical = physical;
config.mapper = mapper;

config.linkParams = linkParams;
config.slantRange = slantRange;

config.delta = delta;
config.nuRelHz = nuRelHz;

config.nSide = nSide;
config.numBlocksMain = numBlocksMain;
config.centerIdxMain = centerIdxMain;

config.characterizedNR = characterizedNR;
config.finalComparisonNR = finalComparisonNR;
config.isCharacterizedNR = isCharacterizedNR;

end
