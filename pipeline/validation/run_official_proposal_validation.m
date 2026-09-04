% ============================================================
% run_official_proposal_validation.m
%
% One-click validation launcher for the official heterogeneous-
% grid cooperative proposal.
%
% This script:
%   1. Adds the complete project to the MATLAB path.
%   2. Creates the frozen official mapper catalog only if it
%      does not exist yet.
%   3. Runs the official mapper and physical-flow regressions.
%   4. Reads the saved validation evidence.
%   5. Stops with an error if any official regression fails.
%
% No full production Monte Carlo is executed here.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

clear;
clc;

fprintf('============================================================\n');
fprintf('OFFICIAL PROPOSAL VALIDATION\n');
fprintf('============================================================\n\n');

% ------------------------------------------------------------
% 1. Locate project root
% ------------------------------------------------------------

thisFile = mfilename('fullpath');
thisFolder = fileparts(thisFile);

projectRoot = thisFolder;

while ~isfolder(fullfile(projectRoot, 'pipeline'))

    parentFolder = fileparts(projectRoot);

    if strcmp(parentFolder, projectRoot)
        error('run_official_proposal_validation:ProjectRootNotFound', ...
            'Could not locate the project root.');
    end

    projectRoot = parentFolder;
end

fprintf('Project root:\n%s\n\n', projectRoot);

% ------------------------------------------------------------
% 2. Add project to MATLAB path
% ------------------------------------------------------------

addpath(genpath(projectRoot));

fprintf('[1/3] Project path loaded.\n');

% ------------------------------------------------------------
% 3. Create frozen mapper catalog if needed
% ------------------------------------------------------------

catalogFile = fullfile( ...
    projectRoot, ...
    'pipeline', ...
    'mapper', ...
    'frozen_mapper_configs.mat');

if ~isfile(catalogFile)

    fprintf('[2/3] Frozen mapper catalog not found.\n');
    fprintf('      Creating it from validated candidates...\n\n');

    build_frozen_mapper_catalog();

    if ~isfile(catalogFile)
        error('run_official_proposal_validation:CatalogCreationFailed', ...
            'Frozen mapper catalog was not created.');
    end

else

    fprintf('[2/3] Frozen mapper catalog found.\n');
    fprintf('      Existing official catalog will be validated.\n');
end

% ------------------------------------------------------------
% 4. Run official proposal regression
% ------------------------------------------------------------

fprintf('\n[3/3] Running official proposal regression...\n\n');

validate_official_proposal_vs_reference();

% ------------------------------------------------------------
% 5. Read saved validation evidence
% ------------------------------------------------------------

evidenceFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'validate_official_proposal_vs_reference.mat');

if ~isfile(evidenceFile)
    error('run_official_proposal_validation:MissingEvidence', ...
        'Validation evidence file was not created.');
end

S = load( ...
    evidenceFile, ...
    'mapperPass', ...
    'physicalPass', ...
    'allPass');

requiredFields = { ...
    'mapperPass', ...
    'physicalPass', ...
    'allPass'};

for idx = 1:numel(requiredFields)

    if ~isfield(S, requiredFields{idx})
        error('run_official_proposal_validation:InvalidEvidence', ...
            'Evidence file is missing field "%s".', ...
            requiredFields{idx});
    end
end

% ------------------------------------------------------------
% 6. Final verdict
% ------------------------------------------------------------

fprintf('\n');
fprintf('============================================================\n');
fprintf('FINAL OFFICIAL PROPOSAL VERDICT\n');
fprintf('============================================================\n');

fprintf('Frozen mapper regression : %s\n', ...
    local_pass_label(S.mapperPass));

fprintf('Physical-flow regression : %s\n', ...
    local_pass_label(S.physicalPass));

fprintf('Overall                   : %s\n', ...
    local_pass_label(S.allPass));

fprintf('============================================================\n\n');

if ~S.allPass
    error('run_official_proposal_validation:RegressionFailed', ...
        ['Official proposal validation FAILED. ' ...
         'Do not continue with pipeline promotion.']);
end

fprintf('Official proposal pipeline validation completed successfully.\n');
fprintf('B4 can be considered CLOSED.\n\n');


% ============================================================
% Local helper
% ============================================================

function label = local_pass_label(pass)

if pass
    label = 'PASS';
else
    label = 'FAIL';
end

end