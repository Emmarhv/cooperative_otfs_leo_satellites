function results = main_baseline(requests)
% ============================================================
% main_baseline.m
%
% Official entry point for the same-grid published baseline
% (M=1024, N=32, P=3 truncated precoder).
%
% Runs one physical BER Monte Carlo point per requested
% (modulation, NR) combination, using the validated official
% chain:
%
%   build_official_config('baseline', ...) -> run_baseline_point
%
% Input:
% - requests : struct array with fields
%     .modulation  ('QPSK' or '16-QAM')
%     .NR
%   If omitted, a small nominal spot-check set is used:
%     QPSK and 16-QAM, each at NR=256.
%
% Output:
% - results : struct array of unified result structs, one per
%             request, see build_result_struct.m
%
% Each point uses build_official_config's own deterministic,
% isolated per-point seed (NOT the continuous-RNG sweep of the
% frozen main_baseline_no_geom.m script). See
% build_official_config.m for the reproducibility-policy note.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Project setup
% ------------------------------------------------------------

mainFolder = fileparts(mfilename('fullpath'));
projectRoot = mainFolder;

while ~isfolder(fullfile(projectRoot, 'pipeline'))

    parentFolder = fileparts(projectRoot);

    if strcmp(parentFolder, projectRoot)
        error('main_baseline:ProjectRootNotFound', ...
            'Could not locate the project root.');
    end

    projectRoot = parentFolder;
end

addpath(genpath(projectRoot));

% ------------------------------------------------------------
% 2. Default request set
% ------------------------------------------------------------

if nargin < 1 || isempty(requests)

    requests = struct( ...
        'modulation', {'QPSK', '16-QAM'}, ...
        'NR', {256, 256});
end

% ------------------------------------------------------------
% 3. Run every requested operating point
% ------------------------------------------------------------

numRequests = numel(requests);
resultsCell = cell(1, numRequests);

fprintf('============================================================\n');
fprintf('OFFICIAL BASELINE PIPELINE - main_baseline\n');
fprintf('============================================================\n\n');

for reqIdx = 1:numRequests

    req = requests(reqIdx);

    fprintf('[%d/%d] %s NR=%d ... ', ...
        reqIdx, numRequests, req.modulation, req.NR);

    config = build_official_config( ...
        'baseline', req.modulation, NaN, 'not_applicable', req.NR);

    result = run_baseline_point(config);

    resultsCell{reqIdx} = result;

    fprintf('BER=%.3e (Ecomb=%d/%d bits, %d frames, hitMaxBits=%d)\n', ...
        result.BER, result.numErrors, result.numBits, ...
        result.runtimeMetadata.numRealizations, ...
        result.runtimeMetadata.hitMaxBits);
end

results = [resultsCell{:}];

fprintf('\n============================================================\n');
fprintf('main_baseline finished: %d operating point(s).\n', numRequests);
fprintf('============================================================\n\n');

end
