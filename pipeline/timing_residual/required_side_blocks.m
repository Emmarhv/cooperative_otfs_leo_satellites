function nSide = required_side_blocks(deltaList, blockLen)
% ============================================================
% required_side_blocks.m
%
% Computes the minimum number of common blocks required on
% each side of the central block for a set of timing offsets.
%
% At least one side block is always kept to represent a
% continuous transmission around the observed central block.
%
% Inputs:
% - deltaList : integer timing offsets [samples]
% - blockLen  : common-block length [samples]
%
% Output:
% - nSide     : required number of blocks on each side
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate inputs.
% ------------------------------------------------------------

if ~isnumeric(deltaList) || ~isreal(deltaList) || isempty(deltaList) || ...
        any(~isfinite(deltaList(:))) || any(deltaList(:) ~= fix(deltaList(:)))
    error('required_side_blocks:InvalidDeltaList', ...
        'deltaList must contain finite integer sample offsets.');
end

if ~isnumeric(blockLen) || ~isreal(blockLen) || ~isscalar(blockLen) || ...
        ~isfinite(blockLen) || blockLen <= 0 || blockLen ~= fix(blockLen)
    error('required_side_blocks:InvalidBlockLength', ...
        'blockLen must be a positive integer number of samples.');
end

% ------------------------------------------------------------
% 2. Compute the required timing runway.
% ------------------------------------------------------------

maxAbsDelta = max(abs(deltaList(:)));

nSide = max(1, ceil(maxAbsDelta / blockLen));

end