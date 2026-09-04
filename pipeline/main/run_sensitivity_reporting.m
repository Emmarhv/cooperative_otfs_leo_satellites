% ============================================================
% run_sensitivity_reporting.m
%
% One-click reporting launcher for the final sensitivity
% analyses of the heterogeneous-grid proposal.
%
% Generates:
%
%   1) Residual timing sensitivity:
%      - QPSK
%      - 16-QAM
%
%   2) Residual Doppler sensitivity:
%      - QPSK
%      - 16-QAM
%
%   3) Slant-range imbalance sensitivity:
%      - QPSK
%      - 16-QAM
%
%   4) Joint timing-Doppler 2-D sensitivity:
%      - QPSK
%      - 16-QAM
%
% Input:
%
%   results/sensitivity_analysis/
%
% Output:
%
%   results/sensitivity_analysis/
%       figures/
%
% No simulation is performed here. This script only loads
% completed production results and calls reporting functions.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

clear;
clc;

fprintf('============================================================\n');
fprintf('SENSITIVITY ANALYSIS REPORTING\n');
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
        error('run_sensitivity_reporting:ProjectRootNotFound', ...
            'Could not locate the project root.');
    end

    projectRoot = parentFolder;
end

fprintf('Project root:\n%s\n\n', projectRoot);

addpath(genpath(projectRoot));

% ------------------------------------------------------------
% 2. Input / output folders
% ------------------------------------------------------------

resultsFolder = fullfile( ...
    projectRoot, ...
    'results', ...
    'sensitivity_analysis');

figureFolder = fullfile( ...
    resultsFolder, ...
    'figures');

if ~isfolder(resultsFolder)
    error('run_sensitivity_reporting:ResultsFolderNotFound', ...
        'Sensitivity results folder not found:\n%s', ...
        resultsFolder);
end

if ~isfolder(figureFolder)
    mkdir(figureFolder);
end

residualFile = fullfile( ...
    resultsFolder, ...
    'residual_sensitivity_results.mat');

timingDoppler2DFile = fullfile( ...
    resultsFolder, ...
    'timing_doppler_2d_sensitivity_results.mat');

% ------------------------------------------------------------
% 3. Verify required production results
% ------------------------------------------------------------

if ~isfile(residualFile)
    error('run_sensitivity_reporting:ResidualResultsNotFound', ...
        'Missing results file:\n%s', residualFile);
end

if ~isfile(timingDoppler2DFile)
    error('run_sensitivity_reporting:TwoDResultsNotFound', ...
        'Missing results file:\n%s', timingDoppler2DFile);
end

fprintf('Input files found.\n\n');

% ------------------------------------------------------------
% 4. Generate 1-D sensitivity figures
% ------------------------------------------------------------

fprintf('Generating residual sensitivity figures...\n');

plot_residual_sensitivity( ...
    residualFile, ...
    figureFolder);

fprintf('Residual sensitivity figures complete.\n\n');

% ------------------------------------------------------------
% 5. Generate joint timing-Doppler figures
% ------------------------------------------------------------

fprintf('Generating joint timing-Doppler heatmaps...\n');

plot_timing_doppler_2d_sensitivity( ...
    timingDoppler2DFile, ...
    figureFolder);

fprintf('Joint timing-Doppler heatmaps complete.\n\n');

% ------------------------------------------------------------
% 6. Final summary
% ------------------------------------------------------------

fprintf('============================================================\n');
fprintf('SENSITIVITY REPORTING COMPLETE\n');
fprintf('============================================================\n');
fprintf('Figures saved in:\n%s\n', figureFolder);
fprintf('============================================================\n\n');