function mapperConfig = get_mapper_config(modulation, k)
% ============================================================
% get_mapper_config.m
%
% Load one frozen, physically characterized heterogeneous-grid
% mapper from the official mapper catalog.
%
% No mapper design, greedy growth, Jrobust computation or
% assignment optimization is executed at runtime.
%
% Selectable family:
%
%   QPSK    k = 7, 8, 9, 10
%   16-QAM  k = 4, 5, 6, 7, 8
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Input validation
% ------------------------------------------------------------

if nargin ~= 2
    error('get_mapper_config:InvalidNumInputs', ...
        'Exactly two inputs are required: modulation and k.');
end

modulation = normalize_modulation_label(modulation);

validateattributes(k, ...
    {'numeric'}, ...
    {'scalar', 'real', 'finite', 'integer', 'positive'}, ...
    mfilename, ...
    'k');

% ------------------------------------------------------------
% 2. Characterized-family whitelist
% ------------------------------------------------------------

if strcmp(modulation, 'QPSK')
    allowedK = [7 8 9 10];
else
    allowedK = [4 5 6 7 8];
end

if ~ismember(k, allowedK)
    error('get_mapper_config:UncharacterizedK', ...
        ['k=%d has no completed physical BER characterization ' ...
         'for %s. Allowed values: %s.'], ...
        k, modulation, mat2str(allowedK));
end

% ------------------------------------------------------------
% 3. Load frozen official catalog
% ------------------------------------------------------------

mapperFolder = fileparts(mfilename('fullpath'));

catalogFile = fullfile( ...
    mapperFolder, ...
    'frozen_mapper_configs.mat');

if ~isfile(catalogFile)
    error('get_mapper_config:MissingCatalog', ...
        ['Frozen mapper catalog not found:\n  %s\n' ...
         'Run build_frozen_mapper_catalog once.'], ...
        catalogFile);
end

S = load(catalogFile, 'frozenMappers');

if ~isfield(S, 'frozenMappers') || isempty(S.frozenMappers)
    error('get_mapper_config:InvalidCatalog', ...
        'Frozen mapper catalog is missing or empty.');
end

frozenMappers = S.frozenMappers;

% ------------------------------------------------------------
% 4. Select requested mapper
% ------------------------------------------------------------

matchIdx = find( ...
    strcmp({frozenMappers.modulation}, modulation) & ...
    [frozenMappers.k] == k);

if numel(matchIdx) ~= 1
    error('get_mapper_config:CatalogMismatch', ...
        ['Expected exactly one frozen mapper for %s k=%d, ' ...
         'found %d.'], ...
        modulation, k, numel(matchIdx));
end

entry = frozenMappers(matchIdx);

% ------------------------------------------------------------
% 5. Validate stored mapper
% ------------------------------------------------------------

mapper = entry.mapper;

if mapper.N1 ~= 16 || mapper.N2 ~= 64
    error('get_mapper_config:UnexpectedGrid', ...
        'Expected frozen N1=16, N2=64 mapper family.');
end

if mapper.k ~= k
    error('get_mapper_config:MapperKMismatch', ...
        'Stored mapper.k does not match requested k.');
end

% ------------------------------------------------------------
% 6. Assemble output
% ------------------------------------------------------------

mapperConfig = mapper;

mapperConfig.status = ...
    entry.status;

mapperConfig.designSearchMinMargin = ...
    entry.designSearchMinMargin;

mapperConfig.designValidationMinMargin = ...
    entry.designValidationMinMargin;

end