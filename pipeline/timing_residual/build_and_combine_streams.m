function result = build_and_combine_streams( ...
    dSat1Blocks, dSat2Blocks, cfg, delta)
% ============================================================
% build_and_combine_streams.m
%
% Build continuous Sat1/Sat2 streams from consecutive common
% blocks, apply the relative timing offset to Sat2 and return
% the combined waveform and central-block RX windows.
%
% Convention:
%   delta > 0 : Sat2 arrives later than Sat1
%   delta < 0 : Sat2 arrives earlier than Sat1
%
% RX1 remains aligned with Sat1. RX2 follows the shifted Sat2
% central block.
%
% Inputs:
% - dSat1Blocks : Sat1 DD payloads per common block
% - dSat2Blocks : Sat2 DD payloads per common block
% - cfg         : proposal configuration
% - delta       : integer timing offset [samples]
%
% Output:
% - result.y
% - result.s1Stream
% - result.s2Stream
% - result.rx1Window
% - result.rx2Window
% - result.commonBlockLength
% - result.validRange
% - result.centerBlockIndex
% - result.numBlocks
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate inputs
% ------------------------------------------------------------

if ~iscell(dSat1Blocks) || ~iscell(dSat2Blocks)
    error('build_and_combine_streams:InvalidInput', ...
        'dSat1Blocks and dSat2Blocks must be cell arrays.');
end

numBlocks = numel(dSat1Blocks);

if numBlocks ~= numel(dSat2Blocks)
    error('build_and_combine_streams:BlockCountMismatch', ...
        'Sat1 and Sat2 must contain the same number of blocks.');
end

if numBlocks < 3 || mod(numBlocks, 2) == 0
    error('build_and_combine_streams:InvalidBlockCount', ...
        ['The stream must contain an odd number of blocks ' ...
         'with at least one block on each side.']);
end

if ~isnumeric(delta) || ~isreal(delta) || ...
        ~isscalar(delta) || ~isfinite(delta) || ...
        delta ~= round(delta)
    error('build_and_combine_streams:InvalidDelta', ...
        'delta must be a finite integer number of samples.');
end

% ------------------------------------------------------------
% 2. Common-block framing
% ------------------------------------------------------------

physical = nominal_block_framing_16_64(cfg);

blockLen = physical.blockLengthSat1;

if physical.blockLengthSat2 + physical.guardLength ~= blockLen
    error('build_and_combine_streams:FramingMismatch', ...
        ['Sat2 active block plus trailing guard must match ' ...
         'the Sat1 common-block length.']);
end

centerBlock = (numBlocks + 1) / 2;
numSideBlocks = (numBlocks - 1) / 2;

requiredSideBlocks = ...
    max(1, ceil(abs(delta) / blockLen));

if numSideBlocks < requiredSideBlocks
    error('build_and_combine_streams:InsufficientRunway', ...
        ['delta=%d requires at least %d side block(s), ' ...
         'but only %d were provided.'], ...
        delta, requiredSideBlocks, numSideBlocks);
end

% ------------------------------------------------------------
% 3. Build continuous Sat1 stream
% ------------------------------------------------------------

streamLength = numBlocks * blockLen;

s1Stream = complex(zeros(streamLength, 1));

for blockIdx = 1:numBlocks

    sBlock = t1_sat1_modulate_block( ...
        dSat1Blocks{blockIdx}, ...
        cfg.M, cfg.N1, cfg.Lcp);

    if numel(sBlock) ~= blockLen
        error('build_and_combine_streams:Sat1BlockLength', ...
            ['Unexpected Sat1 block length at common ' ...
             'block %d.'], blockIdx);
    end

    sampleIdx = ...
        (blockIdx - 1) * blockLen + (1:blockLen);

    s1Stream(sampleIdx) = sBlock;
end

% ------------------------------------------------------------
% 4. Build continuous Sat2 stream
% ------------------------------------------------------------

s2Stream = complex(zeros(streamLength, 1));

for blockIdx = 1:numBlocks

    sBlock = t2_sat2_modulate_block( ...
        dSat2Blocks{blockIdx}, ...
        cfg.M, cfg.N2, cfg.Lcp, ...
        physical.guardLength);

    if numel(sBlock) ~= blockLen
        error('build_and_combine_streams:Sat2BlockLength', ...
            ['Unexpected Sat2 block length at common ' ...
             'block %d.'], blockIdx);
    end

    sampleIdx = ...
        (blockIdx - 1) * blockLen + (1:blockLen);

    s2Stream(sampleIdx) = sBlock;
end

% ------------------------------------------------------------
% 5. Apply relative timing and combine
% ------------------------------------------------------------

combined = linear_shift_combine( ...
    s1Stream, s2Stream, delta);

% ------------------------------------------------------------
% 6. Select central RX windows
% ------------------------------------------------------------

centerStart = ...
    (centerBlock - 1) * blockLen + 1;

centerEnd = ...
    centerStart + blockLen - 1;

% RX1 remains synchronized to Sat1.
rx1Window = ...
    (centerStart:centerEnd).';

% RX2 follows the shifted Sat2 central block.
rx2Window = ...
    rx1Window + delta;

validStart = combined.validRange(1);
validEnd = combined.validRange(2);

if rx1Window(1) < validStart || ...
        rx1Window(end) > validEnd
    error('build_and_combine_streams:Rx1Runway', ...
        ['RX1 window falls outside the valid stream range ' ...
         'for delta=%d.'], delta);
end

if rx2Window(1) < validStart || ...
        rx2Window(end) > validEnd
    error('build_and_combine_streams:Rx2Runway', ...
        ['RX2 window falls outside the valid stream range ' ...
         'for delta=%d.'], delta);
end

% ------------------------------------------------------------
% 7. Return
% ------------------------------------------------------------

result = struct();

result.y = combined.y;

result.s1Stream = s1Stream;
result.s2Stream = s2Stream;

result.rx1Window = rx1Window;
result.rx2Window = rx2Window;

result.commonBlockLength = blockLen;
result.validRange = combined.validRange;

result.centerBlockIndex = centerBlock;
result.numBlocks = numBlocks;

end