% ============================================================
% run_final_reporting.m
%
% One-click launcher for the FINAL TFG reporting pipeline.
%
% This script performs NO simulation.
%
% It only loads the already-frozen official/historical result
% archives and generates:
%
%   - main BER comparison figures
%   - proposal boosted/unboosted figures
%   - nominal payload-SE comparison
%   - load BER figures for different k
%   - load SE-vs-BER trade-off figures
%   - final CSV result tables
%
% Numerical Monte Carlo results are never modified.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

clear;
clc;
close all;

fprintf('============================================================\n');
fprintf('FINAL OFFICIAL REPORTING\n');
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
        error('run_final_reporting:ProjectRootNotFound', ...
            'Could not locate the project root.');
    end

    projectRoot = parentFolder;
end

addpath(genpath(projectRoot));

fprintf('Project root:\n%s\n\n', projectRoot);

% ------------------------------------------------------------
% 2. Input files
% ------------------------------------------------------------

finalComparisonFile = fullfile( ...
    projectRoot, ...
    'results', ...
    'final_comparison_results.mat');

loadTradeoffDir = fullfile( ...
    projectRoot, ...
    'archive', ...
    'load_tradeoff');

boostedFile = fullfile( ...
    loadTradeoffDir, ...
    'load_tradeoff_ber_boosted.mat');

unboostedFile = fullfile( ...
    loadTradeoffDir, ...
    'load_tradeoff_ber_unboosted.mat');

rateFile = fullfile( ...
    loadTradeoffDir, ...
    'rate_per_load_results.mat');

local_require_file(finalComparisonFile);
local_require_file(boostedFile);
local_require_file(unboostedFile);
local_require_file(rateFile);

% ------------------------------------------------------------
% 3. Load frozen results
% ------------------------------------------------------------

Sfinal = load(finalComparisonFile);

if ~isfield(Sfinal, 'mainResults') || ...
        ~isfield(Sfinal, 'proposalPowerResults')

    error('run_final_reporting:InvalidFinalComparisonFile', ...
        ['final_comparison_results.mat must contain ' ...
         'mainResults and proposalPowerResults.']);
end

mainResults = ...
    Sfinal.mainResults;

proposalPowerResults = ...
    Sfinal.proposalPowerResults;

if numel(mainResults) ~= 48
    error('run_final_reporting:UnexpectedMainCount', ...
        'Expected 48 mainResults, got %d.', ...
        numel(mainResults));
end

if numel(proposalPowerResults) ~= 24
    error('run_final_reporting:UnexpectedPowerCount', ...
        'Expected 24 proposalPowerResults, got %d.', ...
        numel(proposalPowerResults));
end

Sboosted = load(boostedFile);
Sunboosted = load(unboostedFile);
Srate = load(rateFile);

boostedResults = ...
    local_get_results(Sboosted);

unboostedResults = ...
    local_get_results(Sunboosted);

if ~isfield(Srate, 'rateResults')
    error('run_final_reporting:MissingRateResults', ...
        'rate_per_load_results.mat lacks rateResults.');
end

rateResults = ...
    Srate.rateResults;

% ------------------------------------------------------------
% 4. Output folders
% ------------------------------------------------------------

outputRoot = fullfile( ...
    projectRoot, ...
    'results');

figureDir = fullfile( ...
    outputRoot, ...
    'figures');

tableDir = fullfile( ...
    outputRoot, ...
    'tables');

if ~isfolder(figureDir)
    mkdir(figureDir);
end

if ~isfolder(tableDir)
    mkdir(tableDir);
end

% ------------------------------------------------------------
% 5. Main BER reporting
% ------------------------------------------------------------

fprintf('------------------------------------------------------------\n');
fprintf('Generating main BER comparison...\n');
fprintf('------------------------------------------------------------\n');

plot_main_ber_comparison( ...
    mainResults, ...
    figureDir);

% ------------------------------------------------------------
% 6. Proposal power-policy reporting
% ------------------------------------------------------------

fprintf('\n');
fprintf('------------------------------------------------------------\n');
fprintf('Generating boosted/unboosted comparison...\n');
fprintf('------------------------------------------------------------\n');

plot_proposal_power_comparison( ...
    proposalPowerResults, ...
    figureDir);

% ------------------------------------------------------------
% 7. Nominal SE comparison
% ------------------------------------------------------------

fprintf('\n');
fprintf('------------------------------------------------------------\n');
fprintf('Generating nominal payload-SE comparison...\n');
fprintf('------------------------------------------------------------\n');

plot_nominal_se_comparison( ...
    mainResults, ...
    figureDir);

% ------------------------------------------------------------
% 8. Load BER versus k
% ------------------------------------------------------------

fprintf('\n');
fprintf('------------------------------------------------------------\n');
fprintf('Generating BER load-tradeoff figures...\n');
fprintf('------------------------------------------------------------\n');

plot_load_ber_by_k( ...
    boostedResults, ...
    unboostedResults, ...
    figureDir);

% ------------------------------------------------------------
% 9. Load SE-versus-BER trade-off
% ------------------------------------------------------------

fprintf('\n');
fprintf('------------------------------------------------------------\n');
fprintf('Generating SE-vs-BER load-tradeoff figures...\n');
fprintf('------------------------------------------------------------\n');

plot_load_se_vs_ber( ...
    boostedResults, ...
    unboostedResults, ...
    rateResults, ...
    figureDir);

% ------------------------------------------------------------
% 10. Tables
% ------------------------------------------------------------

fprintf('\n');
fprintf('------------------------------------------------------------\n');
fprintf('Exporting final numerical tables...\n');
fprintf('------------------------------------------------------------\n');

export_final_results_tables( ...
    mainResults, ...
    proposalPowerResults, ...
    boostedResults, ...
    unboostedResults, ...
    rateResults, ...
    tableDir);

% ------------------------------------------------------------
% 11. Final summary
% ------------------------------------------------------------

fprintf('\n');
fprintf('============================================================\n');
fprintf('FINAL REPORTING COMPLETE\n');
fprintf('============================================================\n');
fprintf('Figures : %s\n', figureDir);
fprintf('Tables  : %s\n', tableDir);
fprintf('No Monte Carlo simulation was executed.\n');
fprintf('============================================================\n\n');


% ============================================================
% Local helpers
% ============================================================

function local_require_file(filePath)

if ~isfile(filePath)
    error('run_final_reporting:MissingFile', ...
        'Missing required file:\n%s', filePath);
end

end


function results = local_get_results(S)

if isfield(S, 'allResults')

    results = S.allResults;

elseif isfield(S, 'results')

    results = S.results;

else

    error('run_final_reporting:MissingResults', ...
        ['Load-tradeoff file contains neither ' ...
         'allResults nor results.']);
end

end