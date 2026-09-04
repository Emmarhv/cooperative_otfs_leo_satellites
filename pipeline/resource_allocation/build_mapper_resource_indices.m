function [sat1Idx, sat2Idx, rowOfSlot] = ...
    build_mapper_resource_indices(mapper, M, N1, delayRows)
% ============================================================
% build_mapper_resource_indices.m
%
% Build the DD resource indices of a cooperative mapper for one
% or several delay rows.
%
% The mapper fixes the frame/Doppler allocation. The requested
% delay rows are then applied at the target delay dimension M.
%
% This supports the validated structural scale-up from the
% M=16 mapper design to the final M=1024 proposal. Therefore
% mapper.M is intentionally not required to equal M.
%
% Flattening:
%
%   Sat1:
%     frame*M*N1 + doppler*M + delay + 1
%
%   Sat2:
%           doppler*M + delay + 1
%
% Sat2 has one OTFS frame per common block in the current
% N1=16, N2=64 architecture, so mapper.sat2Frames must be zero.
%
% Mapper coordinates are 0-based. Returned MATLAB indices are
% 1-based.
%
% Inputs:
% - mapper    : cooperative mapper
% - M         : target delay dimension
% - N1        : Sat1 Doppler dimension
% - delayRows : scalar/vector of 0-based delay rows
%
% Outputs:
% - sat1Idx   : active Sat1 DD indices
% - sat2Idx   : corresponding Sat2 DD indices
% - rowOfSlot : delay row associated with each resource pair
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate mapper and dimensions
% ------------------------------------------------------------

requiredFields = { ...
    'k', 'N1', 'N2', ...
    'sat1Frames', 'sat1Bins', ...
    'sat2Frames', 'sat2Bins'};

for fieldIdx = 1:numel(requiredFields)

    fieldName = requiredFields{fieldIdx};

    if ~isfield(mapper, fieldName)
        error('build_mapper_resource_indices:InvalidMapper', ...
            'mapper is missing field "%s".', fieldName);
    end
end

if ~isscalar(M) || ~isfinite(M) || ...
        M <= 0 || M ~= round(M)
    error('build_mapper_resource_indices:InvalidM', ...
        'M must be a positive integer scalar.');
end

if ~isscalar(N1) || ~isfinite(N1) || ...
        N1 <= 0 || N1 ~= round(N1)
    error('build_mapper_resource_indices:InvalidN1', ...
        'N1 must be a positive integer scalar.');
end

if N1 ~= mapper.N1
    error('build_mapper_resource_indices:N1Mismatch', ...
        'N1 does not match mapper.N1.');
end

k = mapper.k;

if ~isscalar(k) || ~isfinite(k) || ...
        k <= 0 || k ~= round(k)
    error('build_mapper_resource_indices:InvalidK', ...
        'mapper.k must be a positive integer.');
end

expectedSize = [k, 2];

if ~isequal(size(mapper.sat1Frames), expectedSize) || ...
        ~isequal(size(mapper.sat1Bins), expectedSize) || ...
        ~isequal(size(mapper.sat2Frames), expectedSize) || ...
        ~isequal(size(mapper.sat2Bins), expectedSize)
    error('build_mapper_resource_indices:MapperSizeMismatch', ...
        'Mapper frame/bin arrays must have size k x 2.');
end

% ------------------------------------------------------------
% 2. Validate delay rows
% ------------------------------------------------------------

delayRows = delayRows(:).';

if isempty(delayRows)
    error('build_mapper_resource_indices:EmptyDelayRows', ...
        'At least one delay row must be provided.');
end

if any(~isfinite(delayRows)) || ...
        any(delayRows < 0) || ...
        any(delayRows >= M) || ...
        any(delayRows ~= round(delayRows))
    error('build_mapper_resource_indices:InvalidDelayRows', ...
        'Delay rows must be integers in [0,M-1].');
end

if numel(unique(delayRows)) ~= numel(delayRows)
    error('build_mapper_resource_indices:DuplicateRows', ...
        'Delay rows must not contain repeated values.');
end

% ------------------------------------------------------------
% 3. Validate mapper coordinates
% ------------------------------------------------------------

if any(~isfinite(mapper.sat1Frames(:))) || ...
        any(mapper.sat1Frames(:) < 0) || ...
        any(mapper.sat1Frames(:) ~= round(mapper.sat1Frames(:)))
    error('build_mapper_resource_indices:InvalidSat1Frame', ...
        'Sat1 frame indices must be non-negative integers.');
end

if any(~isfinite(mapper.sat1Bins(:))) || ...
        any(mapper.sat1Bins(:) < 0) || ...
        any(mapper.sat1Bins(:) >= N1) || ...
        any(mapper.sat1Bins(:) ~= round(mapper.sat1Bins(:)))
    error('build_mapper_resource_indices:InvalidSat1Bin', ...
        'Sat1 Doppler bins must be integers in [0,N1-1].');
end

% Current N1=16, N2=64 framing contains one Sat2 frame.
if any(mapper.sat2Frames(:) ~= 0)
    error('build_mapper_resource_indices:UnexpectedSat2Frame', ...
        ['Current resource indexing assumes one Sat2 frame ' ...
         'per common block. Expected sat2Frames=0.']);
end

if any(~isfinite(mapper.sat2Bins(:))) || ...
        any(mapper.sat2Bins(:) < 0) || ...
        any(mapper.sat2Bins(:) >= mapper.N2) || ...
        any(mapper.sat2Bins(:) ~= round(mapper.sat2Bins(:)))
    error('build_mapper_resource_indices:InvalidSat2Bin', ...
        'Sat2 Doppler bins must be integers in [0,N2-1].');
end

% ------------------------------------------------------------
% 4. Build resource indices
% ------------------------------------------------------------

numRows = numel(delayRows);
slotsPerRow = 2 * k;
numSlotsTotal = numRows * slotsPerRow;

sat1Idx = zeros(1, numSlotsTotal);
sat2Idx = zeros(1, numSlotsTotal);
rowOfSlot = zeros(1, numSlotsTotal);

slotPtr = 0;

for rowIdx = 1:numRows

    delayRow = delayRows(rowIdx);

    sat1Slots = zeros(k, 2);
    sat2Slots = zeros(k, 2);

    for componentIdx = 1:k
        for pairIdx = 1:2

            sat1Frame = ...
                mapper.sat1Frames(componentIdx, pairIdx);

            sat1Doppler = ...
                mapper.sat1Bins(componentIdx, pairIdx);

            sat2Doppler = ...
                mapper.sat2Bins(componentIdx, pairIdx);

            sat1Slots(componentIdx, pairIdx) = ...
                sat1Frame * M * N1 + ...
                sat1Doppler * M + ...
                delayRow + 1;

            sat2Slots(componentIdx, pairIdx) = ...
                sat2Doppler * M + ...
                delayRow + 1;
        end
    end

    outputIdx = slotPtr + (1:slotsPerRow);

    % Keep the two slots of each component consecutive.
    sat1Idx(outputIdx) = ...
        reshape(sat1Slots.', 1, []);

    sat2Idx(outputIdx) = ...
        reshape(sat2Slots.', 1, []);

    rowOfSlot(outputIdx) = ...
        delayRow;

    slotPtr = slotPtr + slotsPerRow;
end

% ------------------------------------------------------------
% 5. Final consistency checks
% ------------------------------------------------------------

if numel(unique(sat1Idx)) ~= numSlotsTotal
    error('build_mapper_resource_indices:DuplicateSat1Indices', ...
        'Generated Sat1 resource indices are not unique.');
end

if numel(unique(sat2Idx)) ~= numSlotsTotal
    error('build_mapper_resource_indices:DuplicateSat2Indices', ...
        'Generated Sat2 resource indices are not unique.');
end

end