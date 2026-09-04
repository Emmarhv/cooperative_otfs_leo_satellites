function outFile = build_frozen_mapper_catalog()
% ============================================================
% build_frozen_mapper_catalog.m
%
% Promote the physically characterized heterogeneous-grid
% mappers from the experimental load-tradeoff results into a
% frozen catalog used by the official runtime pipeline.
%
% This function is a one-time promotion/validation utility.
% The official runtime does NOT call the experimental mapper
% design pipeline.
%
% Promoted family:
%
%   QPSK    k = 7, 8, 9, 10
%   16-QAM  k = 4, 5, 6, 7, 8
%
% Output:
%
%   official/mapper/frozen_mapper_configs.mat
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Locate project root
% ------------------------------------------------------------

thisFolder = fileparts(mfilename('fullpath'));
projectRoot = thisFolder;

while ~isfolder(fullfile(projectRoot, 'pipeline'))

    parentFolder = fileparts(projectRoot);

    if strcmp(parentFolder, projectRoot)
        error('build_frozen_mapper_catalog:ProjectRootNotFound', ...
            'Could not locate the project root.');
    end

    projectRoot = parentFolder;
end

addpath(genpath(projectRoot));

% ------------------------------------------------------------
% 2. Load validated candidate family
% ------------------------------------------------------------

sourceFile = fullfile( ...
    projectRoot, ...
    'archive', ...
    'load_tradeoff', ...
    'load_tradeoff_candidates.mat');

if ~isfile(sourceFile)
    error('build_frozen_mapper_catalog:MissingSource', ...
        'Missing source candidate file:\n  %s', sourceFile);
end

S = load(sourceFile, 'candidates');

if ~isfield(S, 'candidates') || isempty(S.candidates)
    error('build_frozen_mapper_catalog:InvalidSource', ...
        'The source file does not contain a valid candidates struct.');
end

candidates = S.candidates;

% ------------------------------------------------------------
% 3. Final characterized family
% ------------------------------------------------------------

modList = { ...
    'QPSK', 'QPSK', 'QPSK', 'QPSK', ...
    '16-QAM', '16-QAM', '16-QAM', '16-QAM', '16-QAM'};

kList = [ ...
    7, 8, 9, 10, ...
    4, 5, 6, 7, 8];

numConfigs = numel(kList);

frozenMappers = repmat(struct( ...
    'modulation', '', ...
    'k', NaN, ...
    'status', '', ...
    'designSearchMinMargin', NaN, ...
    'designValidationMinMargin', NaN, ...
    'mapper', struct()), ...
    1, numConfigs);

storedMods = cell(1, numel(candidates));

for idx = 1:numel(candidates)
    storedMods{idx} = normalize_modulation_label( ...
        candidates(idx).modulation);
end

% ------------------------------------------------------------
% 4. Copy only the final characterized mappers
% ------------------------------------------------------------

for idx = 1:numConfigs

    modulation = modList{idx};
    k = kList(idx);

    matchIdx = find( ...
        strcmp(storedMods, modulation) & ...
        [candidates.k] == k);

    if numel(matchIdx) ~= 1
        error('build_frozen_mapper_catalog:CandidateMismatch', ...
            ['Expected exactly one candidate for %s k=%d, ' ...
             'found %d.'], ...
            modulation, k, numel(matchIdx));
    end

    candidate = candidates(matchIdx);

    frozenMappers(idx).modulation = modulation;
    frozenMappers(idx).k = k;
    frozenMappers(idx).status = candidate.status;
    frozenMappers(idx).designSearchMinMargin = ...
        candidate.designSearchMinMargin;
    frozenMappers(idx).designValidationMinMargin = ...
        candidate.designValidationMinMargin;
    frozenMappers(idx).mapper = candidate.mapper;
end

% ------------------------------------------------------------
% 5. Catalog metadata
% ------------------------------------------------------------

catalogInfo = struct();

catalogInfo.description = ...
    'Frozen physically characterized heterogeneous-grid mapper family';

catalogInfo.QPSK = [7 8 9 10];
catalogInfo.QAM16 = [4 5 6 7 8];

catalogInfo.sourceRelativePath = fullfile( ...
    'archive', ...
    'load_tradeoff', ...
    'load_tradeoff_candidates.mat');

% ------------------------------------------------------------
% 6. Save official catalog
% ------------------------------------------------------------

mapperFolder = fullfile( ...
    projectRoot, ...
    'pipeline', ...
    'mapper');

if ~isfolder(mapperFolder)
    mkdir(mapperFolder);
end

outFile = fullfile( ...
    mapperFolder, ...
    'frozen_mapper_configs.mat');

save(outFile, ...
    'frozenMappers', ...
    'catalogInfo');

% ------------------------------------------------------------
% 7. Reload sanity check
% ------------------------------------------------------------

Scheck = load(outFile, 'frozenMappers');

if numel(Scheck.frozenMappers) ~= numConfigs
    error('build_frozen_mapper_catalog:SaveCheckFailed', ...
        'Unexpected number of saved mapper configurations.');
end

fprintf('============================================================\n');
fprintf('FROZEN MAPPER CATALOG CREATED\n');
fprintf('============================================================\n');
fprintf('Configurations: %d\n', numConfigs);
fprintf('Saved: %s\n', outFile);

end