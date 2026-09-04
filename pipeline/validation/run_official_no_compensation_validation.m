% ============================================================
% run_official_no_compensation_validation.m
%
% One-click launcher for the official B3 no-compensation
% regression.
%
% Run this script directly from MATLAB.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

clear;
clc;

fprintf('============================================================\n');
fprintf('OFFICIAL B3 NO-COMPENSATION VALIDATION\n');
fprintf('============================================================\n\n');

% ------------------------------------------------------------
% 1. Locate project root
% ------------------------------------------------------------

thisFolder = ...
    fileparts(mfilename('fullpath'));

projectRoot = ...
    thisFolder;

while ~isfolder( ...
        fullfile(projectRoot, 'pipeline'))

    parentFolder = ...
        fileparts(projectRoot);

    if strcmp(parentFolder, projectRoot)

        error( ...
            'run_official_no_compensation_validation:ProjectRootNotFound', ...
            'Could not locate the project root.');
    end

    projectRoot = ...
        parentFolder;
end

fprintf('Project root: %s\n\n', projectRoot);

% ------------------------------------------------------------
% 2. Load project path
% ------------------------------------------------------------

addpath(genpath(projectRoot));

fprintf('[1/2] Project path loaded.\n');

% ------------------------------------------------------------
% 3. Run B3 validation
% ------------------------------------------------------------

fprintf('[2/2] Running no-compensation regression...\n\n');

summary = ...
    validate_official_no_compensation_vs_reference();

allPass = ...
    all([summary.pass]);

% ------------------------------------------------------------
% 4. Final launcher verdict
% ------------------------------------------------------------

fprintf('\n============================================================\n');
fprintf('OFFICIAL B3 LAUNCHER VEREDICT\n');
fprintf('============================================================\n');

if allPass

    fprintf('No-compensation validation PASS\n');
    fprintf('B3 can be considered CLOSED.\n');

else

    error( ...
        'run_official_no_compensation_validation:ValidationFailed', ...
        'Official B3 validation failed.');
end

fprintf('============================================================\n');