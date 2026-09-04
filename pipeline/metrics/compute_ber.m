function [numErrors, numBitsCompared] = compute_ber(txBits, rxBits)
% ============================================================
% compute_ber.m
%
% Bit Error Rate (BER) computation block.
%
% Purpose:
% - Compare transmitted and received bit streams
% - Count bit errors for Monte Carlo BER estimation
%
% Input:
% - txBits : transmitted binary vector
% - rxBits : received (estimated) binary vector
%
% Output:
% - numErrors        : number of bit errors detected
% - numBitsCompared  : total number of bits compared
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% Ensure column vectors
txBits = txBits(:);
rxBits = rxBits(:);

% Validate equal length
if numel(txBits) ~= numel(rxBits)
    error('compute_ber:lengthMismatch', ...
        'txBits (%d) and rxBits (%d) must have the same length.', ...
        numel(txBits), numel(rxBits));
end

% Count bit errors
numErrors = sum(txBits ~= rxBits);

% Total number of bits compared
numBitsCompared = numel(txBits);

end
