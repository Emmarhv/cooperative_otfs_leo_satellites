function sBlock = t2_sat2_modulate_block(xDDBlock, M, N2, Lcp, guardLength)
% ============================================================
% t2_sat2_modulate_block.m
%
% T2: synthesize one Sat2 cooperative block.
%
% Current proposal:
%   N1 = 16, N2 = 64 -> K2 = 1 Sat2 frame per block.
%
% Physical block:
%   CP|F|guard
%
% The trailing guard contains zeros. It makes Sat2's physical
% block period equal to the common cooperative-block period.
% It does NOT compensate delta_sync or align received signals.
%
% T2 only describes Sat2. It does not know Sat1 framing,
% delta_sync, or the receiver.
%
% Inputs:
% - xDDBlock    : (M*N2)x1 DD symbols
% - M, N2       : Sat2 OTFS grid dimensions
% - Lcp         : reduced CP length
% - guardLength : trailing silent samples
%
% Output:
% - sBlock : M*N2+Lcp+guardLength time-domain samples
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

frameLength = M * N2;

if ~isvector(xDDBlock) || numel(xDDBlock) ~= frameLength
    error('t2_sat2_modulate_block:InvalidInput', ...
        'xDDBlock must have M*N2 = %d entries, got %d.', ...
        frameLength, numel(xDDBlock));
end

if ~isscalar(guardLength) || guardLength < 0 || ...
        guardLength ~= round(guardLength)
    error('t2_sat2_modulate_block:InvalidGuard', ...
        'guardLength must be a non-negative integer scalar.');
end

xDDBlock = xDDBlock(:);

% Sat2 has one M x N2 DD frame.
xDDFrame = reshape(xDDBlock, M, N2);

% OTFS modulation with one RCP.
txFrame = otfs_modulate(xDDFrame, Lcp);

% Complete physical block: active frame followed by silence.
sBlock = [
    txFrame(:)
    complex(zeros(guardLength, 1))
];

end