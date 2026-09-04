% ============================================================
% run_timing_doppler_2d_sensitivity.m
%
% Final 2-D residual timing-Doppler sensitivity analysis for
% the heterogeneous-grid proposal (N1~=N2).
%
% Purpose:
%   Complement the three one-dimensional sensitivity sweeps
%   with a joint timing-Doppler study.
%
% This verifies the behaviour when both residual
% synchronization errors vary simultaneously.
%
% This is NOT an orbital-geometry reconstruction.
%
% Frozen proposal:
%
%   QPSK   -> k=7, boosted
%   16-QAM -> k=4, boosted
%
% Fixed receive-array size:
%
%   N_R = 256
%
% Fixed slant ranges:
%
%   Sat1 = 588.08 km
%   Sat2 = 657.97 km
%
% Timing grid [samples]:
%
%   delta = [-1023 -504 0 504 1023]
%
% Doppler grid [Hz]:
%
%   nuRelHz = [-26460 -13230 0 13230 26460]
%
% Total:
%
%   5 timing x 5 Doppler x 2 modulations = 50 points
%
% Published nominal operating point:
%
%   delta   = 504 samples
%   nuRelHz = -13.23 kHz
%
% Monte Carlo budget:
%
%   TargetErrors = 200
%   MaxBits      = 20e6
%
% Checkpointing:
%
%   Every completed point is saved immediately.
%   Re-running resumes automatically.
%
% Output:
%
%   results/sensitivity_analysis/
%       timing_doppler_2d_sensitivity_results.mat
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

clear;
clc;

fprintf('============================================================\n');
fprintf('JOINT TIMING-DOPPLER 2-D SENSITIVITY ANALYSIS\n');
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
        error('run_timing_doppler_2d_sensitivity:ProjectRootNotFound', ...
            'Could not locate the project root.');
    end

    projectRoot = parentFolder;
end

fprintf('Project root:\n%s\n\n', projectRoot);

addpath(genpath(projectRoot));

% ------------------------------------------------------------
% 2. Frozen study definition
% ------------------------------------------------------------

NR = 256;

deltaValues = ...
    [-1023 -504 0 504 1023];

nuRelHzValues = ...
    [-26460 -13230 0 13230 26460];

rangeSat1 = 588.08e3;
rangeSat2 = 657.97e3;

modulations = struct('name', {}, 'k', {});

modulations(1).name = 'QPSK';
modulations(1).k = 7;

modulations(2).name = '16-QAM';
modulations(2).k = 4;

powerPolicy = 'boosted';

targetErrors = 200;
maxBits = 20e6;

expectedPoints = ...
    numel(deltaValues) * ...
    numel(nuRelHzValues) * ...
    numel(modulations);

if expectedPoints ~= 50
    error('run_timing_doppler_2d_sensitivity:UnexpectedPointCount', ...
        'Expected exactly 50 operating points.');
end

% ------------------------------------------------------------
% 3. Study metadata
% ------------------------------------------------------------

studyMeta = struct();

studyMeta.version = ...
    'v1_joint_timing_doppler_2d';

studyMeta.description = ...
    ['Joint residual timing-Doppler sensitivity analysis ' ...
     'for the frozen heterogeneous-grid proposal.'];

studyMeta.NR = NR;

studyMeta.deltaValues = deltaValues;
studyMeta.nuRelHzValues = nuRelHzValues;

studyMeta.rangeSat1 = rangeSat1;
studyMeta.rangeSat2 = rangeSat2;

studyMeta.modulations = modulations;

studyMeta.powerPolicy = powerPolicy;

studyMeta.targetErrors = targetErrors;
studyMeta.maxBits = maxBits;

studyMeta.expectedPoints = expectedPoints;

% ------------------------------------------------------------
% 4. Assemble fixed 50-point work list
% ------------------------------------------------------------

workList = struct( ...
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

    for deltaIdx = 1:numel(deltaValues)

        delta = deltaValues(deltaIdx);

        for nuIdx = 1:numel(nuRelHzValues)

            nuRelHz = nuRelHzValues(nuIdx);

            idx = idx + 1;

            workList(idx).modulation = modulation;
            workList(idx).k = k;

            workList(idx).NR = NR;

            workList(idx).delta = delta;
            workList(idx).nuRelHz = nuRelHz;

            workList(idx).rangeSat1 = rangeSat1;
            workList(idx).rangeSat2 = rangeSat2;
        end
    end
end

if numel(workList) ~= expectedPoints
    error('run_timing_doppler_2d_sensitivity:UnexpectedWorkListSize', ...
        'Expected %d points, got %d.', ...
        expectedPoints, numel(workList));
end

% ------------------------------------------------------------
% 5. Verify that all operating points are unique
% ------------------------------------------------------------

workKeys = cell(1, numel(workList));

for i = 1:numel(workList)

    workKeys{i} = local_make_key( ...
        workList(i).delta, ...
        workList(i).nuRelHz, ...
        workList(i).modulation, ...
        workList(i).NR);
end

if numel(unique(workKeys)) ~= expectedPoints
    error('run_timing_doppler_2d_sensitivity:DuplicateWorkPoints', ...
        'The 2-D work list contains duplicated operating points.');
end

fprintf('Timing values  : %s samples\n', mat2str(deltaValues));
fprintf('Doppler values : %s Hz\n', mat2str(nuRelHzValues));
fprintf('Modulations    : QPSK k=7, 16-QAM k=4\n');
fprintf('N_R            : %d\n', NR);
fprintf('Total points   : %d\n\n', expectedPoints);

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
    'timing_doppler_2d_sensitivity_results.mat');

if isfile(outFile)

    fprintf('Existing output file found. Resuming.\n');
    fprintf('%s\n\n', outFile);

    Sexisting = load(outFile, 'results', 'studyMeta');

    if ~isfield(Sexisting, 'studyMeta')
        error('run_timing_doppler_2d_sensitivity:MissingMetadata', ...
            ['Existing result file does not contain studyMeta. ' ...
             'Do not mix it with the current study.']);
    end

    if ~isequaln(Sexisting.studyMeta, studyMeta)
        error('run_timing_doppler_2d_sensitivity:MetadataMismatch', ...
            ['Existing result file belongs to a different ' ...
             '2-D sensitivity-study definition.']);
    end

    results = Sexisting.results;

else

    fprintf('No existing output file. Starting fresh.\n\n');

    results = struct([]);

end

completedKeys = local_completed_keys(results);

% ------------------------------------------------------------
% 7. Run missing points
% ------------------------------------------------------------

numRun = 0;

fprintf('Points already completed: %d / %d\n\n', ...
    numel(completedKeys), expectedPoints);

for idx = 1:numel(workList)

    w = workList(idx);

    key = local_make_key( ...
        w.delta, ...
        w.nuRelHz, ...
        w.modulation, ...
        w.NR);

    if ismember(key, completedKeys)

        fprintf( ...
            '[skip] %-7s NR=%-4d delta=%-5d nu=%-8.0f Hz\n', ...
            w.modulation, ...
            w.NR, ...
            w.delta, ...
            w.nuRelHz);

        continue;
    end

    fprintf( ...
        '[run]  %-7s NR=%-4d delta=%-5d nu=%-8.0f Hz ... ', ...
        w.modulation, ...
        w.NR, ...
        w.delta, ...
        w.nuRelHz);

    % Every relevant physical parameter is passed explicitly.
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
    % Attach study-specific metadata
    % --------------------------------------------------------

    result.studyType = 'timing_doppler_2d';

    result.delta = config.delta;
    result.nuRelHz = config.nuRelHz;

    result.rangeSat1 = config.slantRange(1);
    result.rangeSat2 = config.slantRange(2);

    result.studyKey = key;

    fprintf( ...
        ['BER=%.3e ' ...
         '(Ecomb=%d/%d bits, %d frames, hitMaxBits=%d)\n'], ...
        result.BER, ...
        result.numErrors, ...
        result.numBits, ...
        result.runtimeMetadata.numRealizations, ...
        result.runtimeMetadata.hitMaxBits);

    % --------------------------------------------------------
    % Save immediately after every completed point
    % --------------------------------------------------------

    if isempty(results)
        results = result;
    else
        results(end+1) = result; %#ok<AGROW>
    end

    save(outFile, 'results', 'studyMeta');

    completedKeys = local_completed_keys(results);

    numRun = numRun + 1;
end

% ------------------------------------------------------------
% 8. Final summary
% ------------------------------------------------------------

completedKeys = local_completed_keys(results);

numCompleted = numel(unique(completedKeys));

fprintf('\n============================================================\n');
fprintf('JOINT TIMING-DOPPLER 2-D SUMMARY\n');
fprintf('============================================================\n');

fprintf('Points run this session : %d\n', numRun);

fprintf('Points completed total  : %d / %d\n', ...
    numCompleted, expectedPoints);

fprintf('Output file             : %s\n', outFile);

fprintf('============================================================\n\n');

if numCompleted == expectedPoints

    fprintf('All %d timing-Doppler points are complete.\n\n', ...
        expectedPoints);

else

    fprintf('%d point(s) still missing. Re-run to continue.\n\n', ...
        expectedPoints - numCompleted);
end


% ============================================================
% Local helpers
% ============================================================

function key = local_make_key( ...
    delta, nuRelHz, modulation, NR)

key = sprintf( ...
    'delta=%d|nu=%.12g|mod=%s|NR=%d', ...
    delta, ...
    nuRelHz, ...
    modulation, ...
    NR);

end


function keys = local_completed_keys(results)

if isempty(results)
    keys = {};
    return;
end

keys = cell(1, numel(results));

for i = 1:numel(results)

    if isfield(results, 'studyKey')
        keys{i} = results(i).studyKey;
    else
        keys{i} = local_make_key( ...
            results(i).delta, ...
            results(i).nuRelHz, ...
            results(i).modulation, ...
            results(i).NR);
    end
end

end