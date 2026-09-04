% ============================================================
% run_load_tradeoff_pipeline.m
%
% One-click launcher for the official, read-only load-tradeoff
% pipeline (main_load_tradeoff.m).
%
% This script:
%   1. Adds the complete project to the MATLAB path.
%   2. Calls main_load_tradeoff(), which reads the already
%      validated and saved BER/rate archives and packages them
%      into the common official result-struct schema.
%   3. Prints a compact per-scenario summary.
%
% No Monte Carlo simulation is executed by this script or by
% main_load_tradeoff.m. Every number comes from:
%
%   archive/load_tradeoff/
%       load_tradeoff_ber_boosted.mat
%       load_tradeoff_ber_unboosted.mat
%       rate_per_load_results.mat
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

clear;
clc;

fprintf('============================================================\n');
fprintf('OFFICIAL LOAD-TRADEOFF PIPELINE LAUNCHER\n');
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
        error('run_load_tradeoff_pipeline:ProjectRootNotFound', ...
            'Could not locate the project root.');
    end

    projectRoot = parentFolder;
end

fprintf('Project root:\n%s\n\n', projectRoot);

addpath(genpath(projectRoot));

% ------------------------------------------------------------
% 2. Run the read-only load-tradeoff pipeline
% ------------------------------------------------------------

results = main_load_tradeoff();

% ------------------------------------------------------------
% 3. Per-scenario summary
% ------------------------------------------------------------

fprintf('Per-candidate summary (boosted):\n');
fprintf('------------------------------------------------------------\n');

for idx = 1:numel(results.boosted)

    r = results.boosted(idx);

    fprintf('%-7s k=%-2d NR=%-3d : BER=%.3e (Ecomb=%d/%d bits) upper95=%.3e\n', ...
        r.modulation, r.k, r.NR, r.BER, r.numErrors, r.numBits, r.upper95);
end

fprintf('\nPer-candidate summary (unboosted):\n');
fprintf('------------------------------------------------------------\n');

for idx = 1:numel(results.unboosted)

    r = results.unboosted(idx);

    fprintf('%-7s k=%-2d NR=%-3d : BER=%.3e (Ecomb=%d/%d bits) upper95=%.3e\n', ...
        r.modulation, r.k, r.NR, r.BER, r.numErrors, r.numBits, r.upper95);
end

fprintf('\n============================================================\n');
fprintf('Total official load-tradeoff results: %d (boosted=%d, unboosted=%d)\n', ...
    numel(results.all), numel(results.boosted), numel(results.unboosted));
fprintf('============================================================\n\n');

% ------------------------------------------------------------
% 4. Save the packaged results for downstream reporting
% ------------------------------------------------------------

outFolder = fullfile( ...
    projectRoot, 'results');

if ~isfolder(outFolder)
    mkdir(outFolder);
end

outFile = fullfile(outFolder, 'load_tradeoff_official_results.mat');

save(outFile, 'results');

fprintf('Saved packaged results: %s\n\n', outFile);
