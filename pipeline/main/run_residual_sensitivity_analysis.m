% ============================================================
% run_residual_sensitivity_analysis.m
%
% Final, one-click and resumable sensitivity analysis for the
% heterogeneous-grid proposal (N1~=N2).
%
% The experiment isolates three physical effects:
%
%   1) residual timing mismatch;
%   2) residual Doppler mismatch;
%   3) unequal satellite slant ranges through the link budget.
%
% This is NOT an orbital-geometry reconstruction. Satellite
% trajectories are not generated. The analysis varies directly
% the equivalent parameters already used by the validated
% physical communication model.
%
% Frozen proposal design:
%
%   QPSK   -> k=7, boosted
%   16-QAM -> k=4, boosted
%
% No mapper is recomputed or optimized during the sweeps.
%
% Sweep 1: residual timing [samples]
%
%   delta = [-3069 -1023 -504 0 504 1023 3069]
%
% Sweep 2: residual Doppler [Hz]
%
%   nuRelHz = [-26460 -13230 -6615 0 6615 13230 26460]
%
% Sweep 3: slant-range imbalance [km]
%
%   Delta_r = r2-r1 = [0 35 69.89 105 140] km
%
%   r1 = 588.08 km is fixed.
%
% Published nominal operating point:
%
%   delta       = 504 samples
%   nuRelHz     = -13.23 kHz
%   r1          = 588.08 km
%   r2          = 657.97 km
%   r2-r1       = 69.89 km
%
% This nominal physical point belongs to all three sweeps:
%
%   logical plotting points = (7+7+5)*2*6 = 228
%   unique Monte Carlo runs = (7+7+5-2)*2*6 = 204
%
% The nominal result is simulated once and reused for the two
% other logical occurrences having exactly the same physical
% configuration.
%
% Production budget:
%
%   TargetErrors = 200
%   MaxBits      = 20e6
%   N_R          = [64 100 144 256 400 576]
%
% Checkpointing:
%
%   Every completed logical point is saved immediately.
%   Re-running the script resumes from the next missing point.
%
% Output:
%
%   results/sensitivity_analysis/
%       residual_sensitivity_results.mat
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

clear;
clc;

fprintf('============================================================\n');
fprintf('RESIDUAL TIMING / DOPPLER / SLANT-RANGE SENSITIVITY\n');
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
        error('run_residual_sensitivity_analysis:ProjectRootNotFound', ...
            'Could not locate the project root.');
    end

    projectRoot = parentFolder;
end

fprintf('Project root:\n%s\n\n', projectRoot);

addpath(genpath(projectRoot));

% ------------------------------------------------------------
% 2. Frozen study definition
% ------------------------------------------------------------

finalComparisonNR = [64 100 144 256 400 576];

nominalDelta = 504;
nominalNuRelHz = -13.23e3;

nominalRangeSat1 = 588.08e3;
nominalRangeSat2 = 657.97e3;

deltaSweepValues = ...
    [-3069 -1023 -504 0 504 1023 3069];

nuSweepValues = ...
    [-26460 -13230 -6615 0 6615 13230 26460];

rangeSweepDeltaKm = ...
    [0 35 69.89 105 140];

modulations = struct('name', {}, 'k', {});

modulations(1).name = 'QPSK';
modulations(1).k = 7;

modulations(2).name = '16-QAM';
modulations(2).k = 4;

powerPolicy = 'boosted';

targetErrors = 200;
maxBits = 20e6;

expectedLogicalPoints = 228;
expectedUniquePhysicalPoints = 204;

% ------------------------------------------------------------
% 3. Study metadata
% ------------------------------------------------------------

studyMeta = struct();

studyMeta.version = ...
    'v2_symmetric_nu_3sweep_deduplicated_nominal';

studyMeta.description = ...
    ['Residual timing, residual Doppler and slant-range ' ...
     'sensitivity analysis for the frozen proposal.'];

studyMeta.finalComparisonNR = finalComparisonNR;

studyMeta.nominalDelta = nominalDelta;
studyMeta.nominalNuRelHz = nominalNuRelHz;

studyMeta.nominalRangeSat1 = nominalRangeSat1;
studyMeta.nominalRangeSat2 = nominalRangeSat2;

studyMeta.deltaSweepValues = deltaSweepValues;
studyMeta.nuSweepValues = nuSweepValues;
studyMeta.rangeSweepDeltaKm = rangeSweepDeltaKm;

studyMeta.modulations = modulations;
studyMeta.powerPolicy = powerPolicy;

studyMeta.targetErrors = targetErrors;
studyMeta.maxBits = maxBits;

studyMeta.expectedLogicalPoints = expectedLogicalPoints;
studyMeta.expectedUniquePhysicalPoints = ...
    expectedUniquePhysicalPoints;

% Confirm that the published range difference belongs to the
% selected slant-range sweep.
nominalRangeDifferenceKm = ...
    (nominalRangeSat2 - nominalRangeSat1) / 1e3;

if ~any(abs( ...
        rangeSweepDeltaKm - nominalRangeDifferenceKm) < 1e-9)

    error('run_residual_sensitivity_analysis:MissingNominalRangePoint', ...
        'The range sweep must contain the nominal 69.89 km point.');
end

% ------------------------------------------------------------
% 4. Assemble the 228 logical plotting points
% ------------------------------------------------------------

workList = struct( ...
    'sweepType', {}, ...
    'sweepValue', {}, ...
    'modulation', {}, ...
    'k', {}, ...
    'NR', {}, ...
    'delta', {}, ...
    'nuRelHz', {}, ...
    'rangeSat1', {}, ...
    'rangeSat2', {});

idx = 0;

for modIdx = 1:numel(modulations)

    modulation = modulations(modIdx).name;
    k = modulations(modIdx).k;

    for nrIdx = 1:numel(finalComparisonNR)

        NR = finalComparisonNR(nrIdx);

        % ----------------------------------------------------
        % Sweep 1: residual timing
        % ----------------------------------------------------

        for sIdx = 1:numel(deltaSweepValues)

            idx = idx + 1;

            workList(idx).sweepType = 'delta';
            workList(idx).sweepValue = deltaSweepValues(sIdx);

            workList(idx).modulation = modulation;
            workList(idx).k = k;
            workList(idx).NR = NR;

            workList(idx).delta = deltaSweepValues(sIdx);
            workList(idx).nuRelHz = nominalNuRelHz;

            workList(idx).rangeSat1 = nominalRangeSat1;
            workList(idx).rangeSat2 = nominalRangeSat2;
        end

        % ----------------------------------------------------
        % Sweep 2: residual Doppler
        % ----------------------------------------------------

        for sIdx = 1:numel(nuSweepValues)

            idx = idx + 1;

            workList(idx).sweepType = 'nu';
            workList(idx).sweepValue = nuSweepValues(sIdx);

            workList(idx).modulation = modulation;
            workList(idx).k = k;
            workList(idx).NR = NR;

            workList(idx).delta = nominalDelta;
            workList(idx).nuRelHz = nuSweepValues(sIdx);

            workList(idx).rangeSat1 = nominalRangeSat1;
            workList(idx).rangeSat2 = nominalRangeSat2;
        end

        % ----------------------------------------------------
        % Sweep 3: slant-range imbalance
        % ----------------------------------------------------

        for sIdx = 1:numel(rangeSweepDeltaKm)

            idx = idx + 1;

            rangeSat2 = ...
                nominalRangeSat1 + ...
                rangeSweepDeltaKm(sIdx) * 1e3;

            workList(idx).sweepType = 'range';
            workList(idx).sweepValue = ...
                rangeSweepDeltaKm(sIdx);

            workList(idx).modulation = modulation;
            workList(idx).k = k;
            workList(idx).NR = NR;

            workList(idx).delta = nominalDelta;
            workList(idx).nuRelHz = nominalNuRelHz;

            workList(idx).rangeSat1 = nominalRangeSat1;
            workList(idx).rangeSat2 = rangeSat2;
        end
    end
end

if numel(workList) ~= expectedLogicalPoints
    error('run_residual_sensitivity_analysis:UnexpectedWorkListSize', ...
        'Expected %d logical points, got %d.', ...
        expectedLogicalPoints, numel(workList));
end

% ------------------------------------------------------------
% 5. Verify number of unique physical simulations
% ------------------------------------------------------------

physicalWorkKeys = cell(1, numel(workList));

for i = 1:numel(workList)

    w = workList(i);

    physicalWorkKeys{i} = local_make_physical_key( ...
        w.delta, ...
        w.nuRelHz, ...
        w.rangeSat1, ...
        w.rangeSat2, ...
        w.modulation, ...
        w.k, ...
        w.NR, ...
        powerPolicy);
end

numUniquePhysicalWorkPoints = ...
    numel(unique(physicalWorkKeys));

if numUniquePhysicalWorkPoints ~= expectedUniquePhysicalPoints
    error('run_residual_sensitivity_analysis:UnexpectedPhysicalCount', ...
        ['Expected %d unique physical Monte Carlo points, ' ...
         'got %d.'], ...
        expectedUniquePhysicalPoints, ...
        numUniquePhysicalWorkPoints);
end

fprintf('Logical plotting points : %d\n', expectedLogicalPoints);
fprintf('Unique Monte Carlo runs : %d\n\n', ...
    expectedUniquePhysicalPoints);

% ------------------------------------------------------------
% 6. Output folder and resume state
% ------------------------------------------------------------

outFolder = fullfile( ...
    projectRoot, ...
    'results', ...
    'sensitivity_analysis');

if ~isfolder(outFolder)
    mkdir(outFolder);
end

outFile = fullfile( ...
    outFolder, ...
    'residual_sensitivity_results.mat');

if isfile(outFile)

    fprintf('Existing output file found. Resuming.\n');
    fprintf('%s\n\n', outFile);

    Sexisting = load(outFile, 'results', 'studyMeta');

    if ~isfield(Sexisting, 'studyMeta')
        error('run_residual_sensitivity_analysis:MissingMetadata', ...
            ['Existing result file has no studyMeta field. ' ...
             'Do not mix it with the current study.']);
    end

    if ~isequaln(Sexisting.studyMeta, studyMeta)
        error('run_residual_sensitivity_analysis:MetadataMismatch', ...
            ['Existing result file belongs to a different ' ...
             'sensitivity-study definition.']);
    end

    results = Sexisting.results;

else

    fprintf('No existing output file. Starting fresh.\n\n');

    results = struct([]);

end

completedLogicalKeys = ...
    local_completed_logical_keys(results);

% ------------------------------------------------------------
% 7. Run missing logical points
% ------------------------------------------------------------

numAlreadyDone = numel(completedLogicalKeys);

numRun = 0;
numReused = 0;

fprintf('Logical points already completed: %d / %d\n\n', ...
    numAlreadyDone, expectedLogicalPoints);

for idx = 1:numel(workList)

    w = workList(idx);

    logicalKey = local_make_logical_key( ...
        w.sweepType, ...
        w.sweepValue, ...
        w.modulation, ...
        w.NR);

    if ismember(logicalKey, completedLogicalKeys)

        fprintf( ...
            ['[skip]  %-6s %-10g %-7s NR=%-4d ' ...
             '(already completed)\n'], ...
            w.sweepType, ...
            w.sweepValue, ...
            w.modulation, ...
            w.NR);

        continue;
    end

    physicalKey = local_make_physical_key( ...
        w.delta, ...
        w.nuRelHz, ...
        w.rangeSat1, ...
        w.rangeSat2, ...
        w.modulation, ...
        w.k, ...
        w.NR, ...
        powerPolicy);

    % --------------------------------------------------------
    % Reuse an already-computed result if this logical point
    % has exactly the same physical configuration.
    % --------------------------------------------------------

    sourceIdx = ...
        local_find_physical_result(results, physicalKey);

    if sourceIdx > 0

        sourceResult = results(sourceIdx);

        result = sourceResult;

        result.sweepType = w.sweepType;
        result.sweepValue = w.sweepValue;

        result.logicalKey = logicalKey;
        result.physicalKey = physicalKey;

        result.isReusedPhysicalPoint = true;

        result.reusedFromSweepType = ...
            sourceResult.sweepType;

        result.reusedFromSweepValue = ...
            sourceResult.sweepValue;

        fprintf( ...
            ['[reuse] %-6s %-10g %-7s NR=%-4d ' ...
             '<- same physical point from %s %.10g\n'], ...
            w.sweepType, ...
            w.sweepValue, ...
            w.modulation, ...
            w.NR, ...
            sourceResult.sweepType, ...
            sourceResult.sweepValue);

        if isempty(results)
            results = result;
        else
            results(end+1) = result; 
        end

        save(outFile, 'results', 'studyMeta');

        completedLogicalKeys = ...
            local_completed_logical_keys(results);

        numReused = numReused + 1;

        continue;
    end

    % --------------------------------------------------------
    % New physical Monte Carlo point
    % --------------------------------------------------------

    fprintf( ...
        ['[run]   %-6s %-10g %-7s NR=%-4d ' ...
         '(TargetErrors=%d, MaxBits=%.0e) ... '], ...
        w.sweepType, ...
        w.sweepValue, ...
        w.modulation, ...
        w.NR, ...
        targetErrors, ...
        maxBits);

    % Every physical parameter is passed explicitly.
    config = build_official_config( ...
        'proposal', ...
        w.modulation, ...
        w.k, ...
        powerPolicy, ...
        w.NR, ...
        'Delta', w.delta, ...
        'NuRelHz', w.nuRelHz, ...
        'RangeSat1', w.rangeSat1, ...
        'RangeSat2', w.rangeSat2, ...
        'TargetErrors', targetErrors, ...
        'MaxBits', maxBits);

    result = run_proposal_point(config);

    % --------------------------------------------------------
    % Sensitivity-study metadata
    % --------------------------------------------------------

    result.sweepType = w.sweepType;
    result.sweepValue = w.sweepValue;

    result.delta = config.delta;
    result.nuRelHz = config.nuRelHz;

    result.rangeSat1 = config.slantRange(1);
    result.rangeSat2 = config.slantRange(2);

    result.logicalKey = logicalKey;
    result.physicalKey = physicalKey;

    result.isReusedPhysicalPoint = false;
    result.reusedFromSweepType = '';
    result.reusedFromSweepValue = NaN;

    fprintf( ...
        ['BER=%.3e ' ...
         '(Ecomb=%d/%d bits, %d frames, hitMaxBits=%d)\n'], ...
        result.BER, ...
        result.numErrors, ...
        result.numBits, ...
        result.runtimeMetadata.numRealizations, ...
        result.runtimeMetadata.hitMaxBits);

    % --------------------------------------------------------
    % Save immediately after every completed logical point
    % --------------------------------------------------------

    if isempty(results)
        results = result;
    else
        results(end+1) = result;
    end

    save(outFile, 'results', 'studyMeta');

    completedLogicalKeys = ...
        local_completed_logical_keys(results);

    numRun = numRun + 1;
end

% ------------------------------------------------------------
% 8. Final consistency checks and summary
% ------------------------------------------------------------

completedLogicalKeys = ...
    local_completed_logical_keys(results);

completedPhysicalKeys = ...
    local_completed_physical_keys(results);

numLogicalCompleted = ...
    numel(unique(completedLogicalKeys));

numPhysicalCompleted = ...
    numel(unique(completedPhysicalKeys));

fprintf('\n============================================================\n');
fprintf('RESIDUAL SENSITIVITY ANALYSIS SUMMARY\n');
fprintf('============================================================\n');

fprintf('Monte Carlo runs this session : %d\n', numRun);
fprintf('Nominal points reused         : %d\n', numReused);

fprintf('Logical points completed      : %d / %d\n', ...
    numLogicalCompleted, ...
    expectedLogicalPoints);

fprintf('Unique physical points        : %d / %d\n', ...
    numPhysicalCompleted, ...
    expectedUniquePhysicalPoints);

fprintf('Output file                   : %s\n', outFile);

fprintf('============================================================\n\n');

if numLogicalCompleted == expectedLogicalPoints && ...
        numPhysicalCompleted == expectedUniquePhysicalPoints

    fprintf( ...
        ['All %d logical sensitivity points are complete ' ...
         'from %d unique Monte Carlo simulations.\n\n'], ...
        expectedLogicalPoints, ...
        expectedUniquePhysicalPoints);

else

    fprintf( ...
        '%d logical point(s) still missing. Re-run to continue.\n\n', ...
        expectedLogicalPoints - numLogicalCompleted);
end


% ============================================================
% Local helpers
% ============================================================

function key = local_make_logical_key( ...
    sweepType, sweepValue, modulation, NR)

key = sprintf( ...
    '%s|%.12g|%s|%d', ...
    sweepType, ...
    sweepValue, ...
    modulation, ...
    NR);

end


function key = local_make_physical_key( ...
    delta, nuRelHz, rangeSat1, rangeSat2, ...
    modulation, k, NR, powerPolicy)

key = sprintf( ...
    ['delta=%.15g|nu=%.15g|r1=%.15g|r2=%.15g|' ...
     'mod=%s|k=%d|NR=%d|power=%s'], ...
    delta, ...
    nuRelHz, ...
    rangeSat1, ...
    rangeSat2, ...
    modulation, ...
    k, ...
    NR, ...
    powerPolicy);

end


function keys = local_completed_logical_keys(results)

if isempty(results)
    keys = {};
    return;
end

keys = cell(1, numel(results));

for i = 1:numel(results)

    if isfield(results, 'logicalKey')
        keys{i} = results(i).logicalKey;
    else
        keys{i} = local_make_logical_key( ...
            results(i).sweepType, ...
            results(i).sweepValue, ...
            results(i).modulation, ...
            results(i).NR);
    end
end

end


function keys = local_completed_physical_keys(results)

if isempty(results)
    keys = {};
    return;
end

keys = cell(1, numel(results));

for i = 1:numel(results)

    if ~isfield(results, 'physicalKey')
        error( ...
            'run_residual_sensitivity_analysis:MissingPhysicalKey', ...
            'A result entry is missing physicalKey.');
    end

    keys{i} = results(i).physicalKey;
end

end


function idx = local_find_physical_result(results, physicalKey)

idx = 0;

if isempty(results)
    return;
end

if ~isfield(results, 'physicalKey')
    return;
end

for i = 1:numel(results)

    if strcmp(results(i).physicalKey, physicalKey)
        idx = i;
        return;
    end
end

end