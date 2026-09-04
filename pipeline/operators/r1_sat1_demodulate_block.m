function xDDBlock = r1_sat1_demodulate_block(sBlock, M, N1, Lcp)
% ============================================================
% r1_sat1_demodulate_block.m
%
% R1: process one cooperative block using Sat1 framing.
%
% Current proposal:
%   N1 = 16, N2 = 64 -> K1 = 4 Sat1 frames per block.
%
% RX1 knows only Sat1's own frame boundaries. It splits the
% received block into K1 windows, removes the RCP expected by
% Sat1 in each window, and demodulates each M x N1 frame.
%
% RX1 does NOT know or remove Sat2's CP or guard structure.
% Any Sat2 waveform present is processed through the same
% Sat1-defined windows. This defines the cross-grid operator
% C_{1<-2} when R1 is applied to T2.
%
% Inputs:
% - sBlock : K1*(M*N1+Lcp) received time samples
% - M, N1  : Sat1 OTFS grid dimensions
% - Lcp    : Sat1 reduced CP length
%
% Output:
% - xDDBlock : (K1*M*N1)x1 DD samples, frame-major
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

K1 = 4;

frameLength = M * N1;
frameLengthRcp = frameLength + Lcp;
blockLength = K1 * frameLengthRcp;

if ~isvector(sBlock) || numel(sBlock) ~= blockLength
    error('r1_sat1_demodulate_block:InvalidInput', ...
        'sBlock must have K1*(M*N1+Lcp) = %d entries, got %d.', ...
        blockLength, numel(sBlock));
end

sBlock = sBlock(:);

% Preallocate all recovered Sat1 DD frames.
xDDBlock = complex(zeros(K1 * frameLength, 1));

for f = 1:K1

    % RX1 opens the window defined by Sat1's own framing.
    inIdx = (f - 1) * frameLengthRcp + (1:frameLengthRcp);
    rxFrame = sBlock(inIdx);

    % Remove Sat1's expected RCP and demodulate.
    xDDFrame = otfs_demodulate(rxFrame, M, N1, Lcp);

    % Store frame-major, delay-fastest.
    outIdx = (f - 1) * frameLength + (1:frameLength);
    xDDBlock(outIdx) = xDDFrame(:);
end

end