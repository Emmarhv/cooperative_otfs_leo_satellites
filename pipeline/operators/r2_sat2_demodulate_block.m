function xDDBlock = r2_sat2_demodulate_block(sBlock, M, N2, Lcp)
% ============================================================
% r2_sat2_demodulate_block.m
%
% R2: process one cooperative block using Sat2 framing.
%
% RX2 knows only Sat2's own frame boundary. It reads its active
% M*N2+Lcp samples, removes Sat2's expected RCP, and
% demodulates the M x N2 OTFS frame.
%
% Trailing samples belong to the cooperative-block guard
% interval and are outside RX2's DD observation window.
%
% RX2 does NOT know or remove Sat1's internal CP structure.
% Any Sat1 waveform inside RX2's active window is processed as
% part of the received signal. This defines the cross-grid
% operator C_{2<-1} when R2 is applied to T1.
%
% Inputs:
% - sBlock : cooperative-block time-domain samples
% - M, N2  : Sat2 OTFS grid dimensions
% - Lcp    : Sat2 reduced CP length
%
% Output:
% - xDDBlock : (M*N2)x1 DD samples
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

activeLength = M * N2 + Lcp;

if ~isvector(sBlock) || numel(sBlock) < activeLength
    error('r2_sat2_demodulate_block:InvalidInput', ...
        'sBlock must contain at least %d samples, got %d.', ...
        activeLength, numel(sBlock));
end

sBlock = sBlock(:);

% RX2 reads only Sat2's own active frame window.
rxFrame = sBlock(1:activeLength);

% Remove Sat2's expected RCP and demodulate.
xDDFrame = otfs_demodulate(rxFrame, M, N2, Lcp);

xDDBlock = xDDFrame(:);

end