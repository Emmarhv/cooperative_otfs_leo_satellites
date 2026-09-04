function [s, XTF] = otfs_modulate(xDD, cpLength)
% ============================================================
% otfs_modulate.m
%
% OTFS modulator with rectangular pulse shaping and a single
% reduced cyclic prefix (RCP) per frame, following 
% Caus et al., eqs. (13)-(15), and the RCP-OTFS scheme of
% Raviteja et al. [5] referenced therein.
% NOTE: In Caus et al. eq. (15), the first index of x[i,q] is
% Doppler and the second is delay. This implementation uses the
% opposite convention. Mathematically equivalent.
%
% Grid convention:
% - xDD(k,l): rows = delay, columns = Doppler
% - XTF(m,n): rows = frequency, columns = time
% - Both grids have size M x N
%
% Processing chain:
%   xDD
%     -> ISFFT
%   XTF
%     -> Heisenberg transform with rectangular pulses
%   uGrid
%     -> column-wise serialization
%   u
%     -> reduced cyclic prefix
%   s
%
% Inputs:
% - xDD      : M x N matrix of delay-Doppler domain symbols
%              (rows = delay index, columns = Doppler index)
% - cpLength : length of the single reduced cyclic prefix (RCP)
%              prepended to the whole frame. Use 0 for no CP
%              (e.g. Phase 2 AWGN-only BER validation).
%
% Outputs:
% - s   : time-domain transmit signal, (M*N + cpLength) x 1
% - XTF : time-frequency domain grid (M x N)
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate delay-Doppler grid
% ------------------------------------------------------------
if ~isnumeric(xDD) || ~ismatrix(xDD) || ...
        isvector(xDD) || isempty(xDD)
    error('otfs_modulate:invalidInput', ...
        'xDD must be a non-empty numeric M x N matrix.');
end

if any(~isfinite(xDD(:)))
    error('otfs_modulate:nonFiniteInput', ...
        'xDD must contain only finite values.');
end

[M, N] = size(xDD);

% ------------------------------------------------------------
% 2. Validate cyclic-prefix length
% ------------------------------------------------------------
if ~isscalar(cpLength) || ~isnumeric(cpLength) || ...
        cpLength < 0 || mod(cpLength, 1) ~= 0
    error('otfs_modulate:invalidCpLength', ...
        'cpLength must be a non-negative integer scalar.');
end

if cpLength > M*N
    error('otfs_modulate:cpTooLong', ...
        'cpLength (%d) cannot exceed M*N (%d).', ...
        cpLength, M*N);
end

% ------------------------------------------------------------
% 3. Delay-Doppler to time-frequency
% ------------------------------------------------------------
XTF = isfft(xDD);

% ------------------------------------------------------------
% 4. Heisenberg transform
% ------------------------------------------------------------
% For rectangular transmit pulses, the discrete Heisenberg
% transform is an unitary IDFT of size M
% applied per column (per time-slot), i.e. one OFDM modulation per
% column of XTF.
uGrid = sqrt(M) * ifft(XTF, M, 1);

% ------------------------------------------------------------
% 5. Serialize the complete OTFS frame
% ------------------------------------------------------------
% MATLAB serializes matrices column by column.
% Therefore, each time-slot column contributes M consecutive
% time-domain samples.
u = uGrid(:);

% ------------------------------------------------------------
% 6. Add one reduced cyclic prefix
% ------------------------------------------------------------
% Caus et al. eq. 13
if cpLength > 0
    s = [u(end-cpLength+1:end); u];
else
    s = u;
end

end
