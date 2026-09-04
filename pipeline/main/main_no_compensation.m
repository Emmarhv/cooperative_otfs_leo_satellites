function results = main_no_compensation(requests)
% ============================================================
% main_no_compensation.m
%
% Official entry point for the B3 ablation: same-grid baseline
% physics without satellite-2 TX compensation
% (applyPrecoder=false, the physically meaningful default).
%
% Runs one physical BER Monte Carlo point per requested
% (modulation, NR) combination, using the validated official
% chain:
%
%   build_official_config('no_compensation', ...)
%       -> run_no_compensation_point
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
% This entry point always uses applyPrecoder=false (the actual
% ablation). The applyPrecoder=true validation mode is only
% used inside official/validation/, never here.
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
        error('main_no_compensation:ProjectRootNotFound', ...
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
fprintf('OFFICIAL B3 ABLATION - main_no_compensation\n');
fprintf('============================================================\n\n');

for reqIdx = 1:numRequests

    req = requests(reqIdx);

    fprintf('[%d/%d] %s NR=%d (no TX compensation) ... ', ...
        reqIdx, numRequests, req.modulation, req.NR);

    config = build_official_config( ...
        'no_compensation', req.modulation, NaN, 'not_applicable', ...
        req.NR, 'ApplyPrecoder', false);

    result = run_no_compensation_point(config);

    resultsCell{reqIdx} = result;

    fprintf('BER=%.3e (Ecomb=%d/%d bits, %d frames, hitMaxBits=%d)\n', ...
        result.BER, result.numErrors, result.numBits, ...
        result.runtimeMetadata.numRealizations, ...
        result.runtimeMetadata.hitMaxBits);
end

results = [resultsCell{:}];

fprintf('\n============================================================\n');
fprintf('main_no_compensation finished: %d operating point(s).\n', numRequests);
fprintf('============================================================\n\n');

end
