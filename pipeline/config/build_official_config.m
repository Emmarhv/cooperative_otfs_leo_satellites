function config = build_official_config( ...
    scenario, modulation, k, powerPolicy, NR, varargin)
% ------------------------------------------------------------
% build_official_config.m
%
% Thin dispatcher preserving the original single-entry-point
% interface used throughout the pipeline:
%
%   build_official_config(scenario, modulation, k, powerPolicy, NR, ...)
%
% The actual configuration logic lives in two dedicated
% builders, since 'baseline'/'no_compensation' and 'proposal'
% are structurally different configurations that happen to
% share a common calling convention:
%
%   scenario = 'baseline'         -> build_baseline_config(..., 'ApplyPrecoder', true)
%   scenario = 'no_compensation'  -> build_baseline_config(..., 'ApplyPrecoder', false)
%   scenario = 'proposal'         -> build_proposal_config(...)
%
% For 'baseline' and 'no_compensation', k and powerPolicy are
% not applicable: callers must pass k = NaN and
% powerPolicy = 'not_applicable', matching every existing call
% site in the pipeline.
% ------------------------------------------------------------

if ~(ischar(scenario) || isstring(scenario))
    error('build_official_config:InvalidScenario', ...
        'scenario must be a character vector or string scalar.');
end

scenario = char(lower(strtrim(string(scenario))));

switch scenario

    case {'baseline', 'no_compensation'}

        if ~(isnumeric(k) && isscalar(k) && isnan(k))
            error('build_official_config:InvalidLoad', ...
                'k must be NaN when it is not applicable to the selected scenario.');
        end

        powerPolicyChar = char(lower(strtrim(string(powerPolicy))));

        if ~strcmp(powerPolicyChar, 'not_applicable')
            error('build_official_config:InvalidPowerPolicy', ...
                'powerPolicy must be ''not_applicable'' when it is not applicable to the selected scenario.');
        end

        config = build_baseline_config( ...
            modulation, NR, ...
            'ApplyPrecoder', strcmp(scenario, 'baseline'), ...
            varargin{:});

    case 'proposal'

        config = build_proposal_config( ...
            modulation, k, powerPolicy, NR, ...
            varargin{:});

    otherwise
        error('build_official_config:UnknownScenario', ...
            'Unknown scenario ''%s''. Expected ''baseline'', ''no_compensation'' or ''proposal''.', ...
            scenario);
end

end
