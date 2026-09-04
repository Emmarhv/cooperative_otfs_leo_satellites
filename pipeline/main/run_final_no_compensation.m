% ============================================================
% run_final_no_compensation.m
%
% One-click, resumable launcher for the FINAL B3 ablation
% Monte Carlo (same cooperative data, same-grid baseline
% physics, satellite-2 WITHOUT TX compensation).
%
% Runs EXACTLY these 12 operating points and nothing else:
%
%   QPSK,   NR = [64 100 144 256 400 576]
%   16-QAM, NR = [64 100 144 256 400 576]
%
% at TargetErrors=200, MaxBits=20e6 (production budget), using
% the already-validated official B3 chain:
%
%   build_official_config('no_compensation', ...)
%       -> run_no_compensation_point (ApplyPrecoder=false)
%
% This script does NOT touch B2 (baseline), B4 (proposal), the
% legacy Scenario A/B/C/D checkpoints, or any historical
% results file. It opens no new k values, power policies,
% mappers, or studies beyond these 12 points.
%
% Checkpointing / resumability:
%   Each completed point is appended to the output .mat file
%   IMMEDIATELY after it finishes (not batched at the end). On
%   a fresh run, the script loads the output file if it already
%   exists, builds the set of already-completed
%   (modulation, NR) keys, and SKIPS any point already present.
%   Re-running this script after an interruption therefore
%   resumes from the next missing point instead of repeating
%   completed ones.
%
% Output file (official B3 result archive, created here, never
% overwriting any historical file):
%
%   results/
%       no_compensation_final_results.mat
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

clear;
clc;

fprintf('============================================================\n');
fprintf('FINAL B3 NO-COMPENSATION LAUNCHER (12 points)\n');
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
        error('run_final_no_compensation:ProjectRootNotFound', ...
            'Could not locate the project root.');
    end

    projectRoot = parentFolder;
end

fprintf('Project root:\n%s\n\n', projectRoot);

addpath(genpath(projectRoot));

% ------------------------------------------------------------
% 2. Fixed work list: exactly 12 points, nothing else
% ------------------------------------------------------------

finalComparisonNR = [64 100 144 256 400 576];

workList = struct( ...
    'modulation', {}, 'NR', {});

idx = 0;

for modIdx = 1:2

    if modIdx == 1
        modulation = 'QPSK';
    else
        modulation = '16-QAM';
    end

    for nrIdx = 1:numel(finalComparisonNR)
        idx = idx + 1;
        workList(idx).modulation = modulation;
        workList(idx).NR = finalComparisonNR(nrIdx);
    end
end

if numel(workList) ~= 12
    error('run_final_no_compensation:UnexpectedWorkListSize', ...
        'Expected exactly 12 points, got %d.', numel(workList));
end

targetErrors = 200;
maxBits = 20e6;

% ------------------------------------------------------------
% 3. Output file and resume state
% ------------------------------------------------------------

outFolder = fullfile( ...
    projectRoot, 'results');

if ~isfolder(outFolder)
    mkdir(outFolder);
end

outFile = fullfile(outFolder, 'no_compensation_final_results.mat');

if isfile(outFile)

    fprintf('Existing output file found. Resuming.\n');
    fprintf('%s\n\n', outFile);

    Sexisting = load(outFile, 'results');
    results = Sexisting.results;

else

    fprintf('No existing output file. Starting fresh.\n\n');

    results = struct([]);
end

completedKeys = local_completed_keys(results);

% ------------------------------------------------------------
% 4. Run only the missing points, saving after each one
% ------------------------------------------------------------

numAlreadyDone = numel(completedKeys);
numRun = 0;

fprintf('Points already completed: %d / 12\n\n', numAlreadyDone);

for idx = 1:numel(workList)

    modulation = workList(idx).modulation;
    NR = workList(idx).NR;

    key = local_make_key(modulation, NR);

    if ismember(key, completedKeys)
        fprintf('[skip] %-7s NR=%-4d (already completed)\n', ...
            modulation, NR);
        continue;
    end

    fprintf('[run]  %-7s NR=%-4d (TargetErrors=%d, MaxBits=%.0e) ... ', ...
        modulation, NR, targetErrors, maxBits);

    config = build_official_config( ...
        'no_compensation', modulation, NaN, 'not_applicable', NR, ...
        'ApplyPrecoder', false, ...
        'TargetErrors', targetErrors, ...
        'MaxBits', maxBits);

    result = run_no_compensation_point(config);

    fprintf('BER=%.3e (Ecomb=%d/%d bits, %d frames, hitMaxBits=%d)\n', ...
        result.BER, result.numErrors, result.numBits, ...
        result.runtimeMetadata.numRealizations, ...
        result.runtimeMetadata.hitMaxBits);

    % ----------------------------------------------------
    % Save immediately: append this point and write to disk
    % before moving to the next one.
    % ----------------------------------------------------

    if isempty(results)
        results = result;
    else
        results(end+1) = result; %#ok<AGROW>
    end

    save(outFile, 'results');

    completedKeys = local_completed_keys(results);
    numRun = numRun + 1;
end

% ------------------------------------------------------------
% 5. Final summary
% ------------------------------------------------------------

fprintf('\n============================================================\n');
fprintf('FINAL B3 NO-COMPENSATION SUMMARY\n');
fprintf('============================================================\n');
fprintf('Points run this session : %d\n', numRun);
fprintf('Points completed total  : %d / 12\n', numel(results));
fprintf('Output file             : %s\n', outFile);
fprintf('============================================================\n\n');

if numel(results) == 12
    fprintf('All 12 B3 points are complete.\n\n');
else
    fprintf('%d point(s) still missing. Re-run this script to continue.\n\n', ...
        12 - numel(results));
end


% ============================================================
% Local helpers
% ============================================================

function key = local_make_key(modulation, NR)

key = sprintf('%s|%d', modulation, NR);

end


function keys = local_completed_keys(results)

if isempty(results)
    keys = {};
    return;
end

keys = cell(1, numel(results));

for i = 1:numel(results)
    keys{i} = local_make_key(results(i).modulation, results(i).NR);
end

end
