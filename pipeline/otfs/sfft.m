function xDD = sfft(XTF)
% ============================================================
% sfft.m
%
% Symplectic Finite Fourier Transform (SFFT).
% Inverse of isfft.m: maps time-frequency domain symbols back
% to the delay-Doppler domain.
%
% Grid convention:
% - Input  XTF(m,n) : m = 0..M-1 frequency index (ROWS)
%                     n = 0..N-1 time-slot index (COLUMNS)
% - Output xDD(k,l) : k = 0..M-1 delay index   (ROWS)
%                     l = 0..N-1 Doppler index (COLUMNS)
%
% Reference: Caus et al. (2022), Eq. (15).
% x[k,l] = (1/sqrt(M*N)) * sum_n sum_m X[m,n] * exp(-j*2*pi*n*l/N) * exp(+j*2*pi*m*k/M)
%
% Implemented as two separable unitary 1-D transforms:
%   1) DFT of size N along the time-slot axis (columns) - time -> Doppler
%   2) IDFT of size M along the frequency axis (rows) - frequency -> delay
%
% Input:
% - XTF : M x N matrix of time-frequency domain symbols
%
% Output:
% - xDD : M x N matrix of delay-Doppler domain symbols
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate input
% ------------------------------------------------------------
if ~isnumeric(XTF) || ~ismatrix(XTF) || isvector(XTF) || isempty(XTF)
    error('sfft:invalidInput', ...
        'XTF must be a non-empty numeric M x N matrix.');
end

[M, N] = size(XTF);

% ------------------------------------------------------------
% 2. Time-to-Doppler transform
% ------------------------------------------------------------
% Unitary DFT of size N along the time-slot axis (dim 2, columns)
%
% MATLAB fft uses the kernel:
%   exp(-j*2*pi*n*l/N)
%
% Division by sqrt(N) makes the transform unitary.
frequencyDopplerGrid = fft(XTF, N, 2) / sqrt(N);

% ------------------------------------------------------------
% 3. Frequency-to-delay transform
% ------------------------------------------------------------
% Unitary IDFT of size M along the frequency axis (dim 1, rows)
%
% MATLAB ifft uses the kernel:
%   exp(+j*2*pi*m*k/M)
%
% Multiplication by sqrt(M) changes MATLAB's 1/M factor into
% the unitary normalization factor 1/sqrt(M).
xDD = sqrt(M) * ifft(frequencyDopplerGrid, M, 1);

end
