function sBlock = t1_sat1_modulate_block(xDDBlock, M, N1, Lcp)
% ============================================================
% t1_sat1_modulate_block.m
%
% T1: synthesize one Sat1 cooperative block.
%
% Current proposal:
%   N1 = 16, N2 = 64 -> K1 = 4 Sat1 frames per block.
%
% Physical block:
%   CP|f0  CP|f1  CP|f2  CP|f3
%
% Each OTFS frame has its own reduced cyclic prefix. The input
% is frame-major; each frame is flattened column-major
% (delay-fastest), consistent with reshape(..., M, N1).
%
% T1 only describes Sat1. It does not know Sat2 framing,
% guard samples, delta_sync, or the receiver.
%
% Inputs:
% - xDDBlock : (K1*M*N1)x1 DD symbols
% - M, N1    : Sat1 OTFS grid dimensions
% - Lcp      : reduced CP length per frame
%
% Output:
% - sBlock   : K1*(M*N1+Lcp) time-domain samples
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

K1 = 4;

frameLength = M * N1;
frameLengthRcp = frameLength + Lcp;
numResources = K1 * frameLength;

if ~isvector(xDDBlock) || numel(xDDBlock) ~= numResources
    error('t1_sat1_modulate_block:InvalidInput', ...
        'xDDBlock must have K1*M*N1 = %d entries, got %d.', ...
        numResources, numel(xDDBlock));
end

xDDBlock = xDDBlock(:);

% Preallocate complete Sat1 physical block.
sBlock = complex(zeros(K1 * frameLengthRcp, 1));

for f = 1:K1

    % Extract one DD frame.
    idx = (f - 1) * frameLength + (1:frameLength);
    xDDFrame = reshape(xDDBlock(idx), M, N1);

    % OTFS modulation with one RCP per frame.
    txFrame = otfs_modulate(xDDFrame, Lcp);

    % Insert frame into the cooperative block.
    outIdx = (f - 1) * frameLengthRcp + (1:frameLengthRcp);
    sBlock(outIdx) = txFrame(:);
end

end