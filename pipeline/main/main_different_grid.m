function results = main_different_grid(requests, varargin)
% ============================================================
% main_different_grid.m
%
% Official entry point for the heterogeneous-grid cooperative
% proposal.
%
% One physical Monte Carlo point is executed per requested
% operating configuration.
%
% Request fields:
%
%   .modulation
%   .k
%   .powerPolicy
%   .NR
%
% Optional common overrides:
%
%   'Seed'
%   'MaxBits'
%   'TargetErrors'
%
% Example:
%
%   req.modulation = 'QPSK';
%   req.k = 8;
%   req.powerPolicy = 'boosted';
%   req.NR = 256;
%
%   results = main_different_grid(req);
%
% For a short regression:
%
%   results = main_different_grid(req, ...
%       'MaxBits', 5e5, ...
%       'TargetErrors', 20);
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
        error('main_different_grid:ProjectRootNotFound', ...
            'Could not locate the project root.');
    end

    projectRoot = parentFolder;
end

addpath(genpath(projectRoot));

% ------------------------------------------------------------
% 2. Default request
% ------------------------------------------------------------

if nargin < 1 || isempty(requests)

    % One nominal proposal point.
    requests = struct( ...
        'modulation', 'QPSK', ...
        'k', 7, ...
        'powerPolicy', 'boosted', ...
        'NR', 256);
end

% ------------------------------------------------------------
% 3. Optional Monte Carlo overrides
% ------------------------------------------------------------

isOptionalSeed = @(x) ...
    isempty(x) || ...
    (isnumeric(x) && isscalar(x) && isreal(x) && ...
     isfinite(x) && x >= 0 && x == floor(x));

isOptionalPositiveInteger = @(x) ...
    isempty(x) || ...
    (isnumeric(x) && isscalar(x) && isreal(x) && ...
     isfinite(x) && x > 0 && x == floor(x));

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

parse(p, varargin{:});

% ------------------------------------------------------------
% 4. Validate request schema
% ------------------------------------------------------------

requiredRequestFields = { ...
    'modulation', ...
    'k', ...
    'powerPolicy', ...
    'NR'};

for reqIdx = 1:numel(requests)

    if ~all(isfield(requests(reqIdx), requiredRequestFields))
        error('main_different_grid:InvalidRequest', ...
            ['Every request must contain modulation, k, ' ...
             'powerPolicy and NR.']);
    end
end

% ------------------------------------------------------------
% 5. Execute requested operating points
% ------------------------------------------------------------

numRequests = numel(requests);
resultsCell = cell(1, numRequests);

fprintf('============================================================\n');
fprintf('OFFICIAL HETEROGENEOUS-GRID PROPOSAL\n');
fprintf('============================================================\n\n');

for reqIdx = 1:numRequests

    req = requests(reqIdx);

    fprintf( ...
        '[%d/%d] %s k=%d %s NR=%d ... ', ...
        reqIdx, ...
        numRequests, ...
        req.modulation, ...
        req.k, ...
        req.powerPolicy, ...
        req.NR);

    config = build_official_config( ...
        'proposal', ...
        req.modulation, ...
        req.k, ...
        req.powerPolicy, ...
        req.NR, ...
        'Seed', p.Results.Seed, ...
        'MaxBits', p.Results.MaxBits, ...
        'TargetErrors', p.Results.TargetErrors);

    result = run_proposal_point(config);

    resultsCell{reqIdx} = result;

    fprintf( ...
        ['BER=%.3e ' ...
         '(Ecomb=%d/%d bits, %d real., hitMaxBits=%d)\n'], ...
        result.BER, ...
        result.numErrors, ...
        result.numBits, ...
        result.runtimeMetadata.numRealizations, ...
        result.runtimeMetadata.hitMaxBits);
end

results = [resultsCell{:}];

fprintf('\n');
fprintf('============================================================\n');
fprintf('main_different_grid finished: %d operating point(s).\n', ...
    numRequests);
fprintf('============================================================\n');

end