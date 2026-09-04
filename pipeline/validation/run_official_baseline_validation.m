% ============================================================
% run_official_baseline_validation.m
%
% One-click validation launcher for the official same-grid
% baseline (M=1024, N=32, P=3 truncated precoder).
%
% This script:
%   1. Adds the complete project to the MATLAB path.
%   2. Runs the baseline-vs-frozen-script regression
%      (bit-exact for the first two QPSK operating points,
%      plus a 9-point link-budget cross-check).
%   3. Runs a short, capped-budget spot check of the official
%      run_baseline_point.m engine itself (deterministic
%      isolated-point seed policy, NOT the continuous-RNG
%      sweep used by the regression above).
%   4. Stops with an error if any check fails.
%
% No full production Monte Carlo (minErrors=200,
% maxBits=2e7 across all 9 N_R x 2 modulations) is executed
% here.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

clear;
clc;

fprintf('============================================================\n');
fprintf('OFFICIAL BASELINE VALIDATION\n');
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
        error('run_official_baseline_validation:ProjectRootNotFound', ...
            'Could not locate the project root.');
    end

    projectRoot = parentFolder;
end

fprintf('Project root:\n%s\n\n', projectRoot);

addpath(genpath(projectRoot));

fprintf('[1/3] Project path loaded.\n');

% ------------------------------------------------------------
% 2. Baseline-vs-frozen-script regression
% ------------------------------------------------------------

fprintf('\n[2/3] Running baseline-vs-reference regression...\n\n');

validate_official_baseline_vs_reference();

evidenceFile = fullfile( ...
    projectRoot, 'results', ...
    'validate_official_baseline_vs_reference.mat');

if ~isfile(evidenceFile)
    error('run_official_baseline_validation:MissingEvidence', ...
        'Baseline regression evidence file was not created.');
end

regressionEvidence = load(evidenceFile, 'allPass');

if ~isfield(regressionEvidence, 'allPass')
    error('run_official_baseline_validation:InvalidEvidence', ...
        'Evidence file is missing field "allPass".');
end

% ------------------------------------------------------------
% 3. Short spot check of the official runtime engine
% ------------------------------------------------------------

fprintf('\n[3/3] Running official engine spot check (short budget)...\n\n');

spotCheckPass = true;

spotCases = struct( ...
    'modulation', {'QPSK', '16-QAM'}, ...
    'NR', {144, 144});

for idx = 1:numel(spotCases)

    cfgSpot = build_official_config( ...
        'baseline', spotCases(idx).modulation, ...
        NaN, 'not_applicable', spotCases(idx).NR, ...
        'TargetErrors', 20, ...
        'MaxBits', 2000000);

    resultSpot1 = run_baseline_point(cfgSpot);
    resultSpot2 = run_baseline_point(cfgSpot);

    reproducible = isequal(resultSpot1.numErrors, resultSpot2.numErrors) && ...
        isequal(resultSpot1.numBits, resultSpot2.numBits);

    schemaOk = isnan(resultSpot1.k) && ...
        strcmp(resultSpot1.powerPolicy, 'not_applicable') && ...
        isnan(resultSpot1.occupancyPct) && ...
        isnan(resultSpot1.boostDb);

    casePass = reproducible && schemaOk;
    spotCheckPass = spotCheckPass && casePass;

    fprintf('%-7s NR=%-3d : BER=%.3e reproducible=%d schemaOk=%d : %s\n', ...
        spotCases(idx).modulation, spotCases(idx).NR, ...
        resultSpot1.BER, reproducible, schemaOk, ...
        local_pass_label(casePass));
end

% ------------------------------------------------------------
% 4. Final verdict
% ------------------------------------------------------------

allPass = regressionEvidence.allPass && spotCheckPass;

fprintf('\n');
fprintf('============================================================\n');
fprintf('FINAL OFFICIAL BASELINE VERDICT\n');
fprintf('============================================================\n');

fprintf('Baseline-vs-reference regression : %s\n', local_pass_label(regressionEvidence.allPass));
fprintf('Official engine spot check       : %s\n', local_pass_label(spotCheckPass));
fprintf('Overall                          : %s\n', local_pass_label(allPass));

fprintf('============================================================\n\n');

if ~allPass
    error('run_official_baseline_validation:RegressionFailed', ...
        ['Official baseline validation FAILED. ' ...
         'Do not continue with pipeline promotion.']);
end

fprintf('Official baseline pipeline validation completed successfully.\n');
fprintf('B2 can be considered CLOSED.\n\n');


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
