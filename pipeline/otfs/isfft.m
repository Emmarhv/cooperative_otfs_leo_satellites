function XTF = isfft(xDD)
% ============================================================
% isfft.m
%
% Inverse Symplectic Finite Fourier Transform (ISFFT).
% Maps delay-Doppler domain symbols to the time-frequency domain.
%
% Grid convention:
% - Input  xDD(k,l) : k = 0..M-1 delay index   (ROWS)
%                     l = 0..N-1 Doppler index (COLUMNS)
% - Output XTF(m,n) : m = 0..M-1 frequency index (ROWS)
%                     n = 0..N-1 time-slot index (COLUMNS)
%
% Reference: Caus et al. (2022), Eq. (15).
% X[m,n] = (1/sqrt(M*N)) * sum_l sum_k x[k,l] * exp(-j*2*pi*m*k/M) * exp(+j*2*pi*n*l/N)
%
% Implemented as two separable unitary 1-D transforms:
%   1) DFT of size M along the delay axis (rows) - delay -> frequency
%   2) IDFT of size N along the Doppler axis (columns) - Doppler -> time
%
% Input:
% - xDD : M x N matrix of delay-Doppler domain symbols
%
% Output:
% - XTF : M x N matrix of time-frequency domain symbols
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate input
% ------------------------------------------------------------
if ~isnumeric(xDD) || ~ismatrix(xDD) || isvector(xDD) || isempty(xDD)
    error('isfft:invalidInput', ...
        'xDD must be a non-empty numeric M x N matrix.');
end

[M, N] = size(xDD);

% ------------------------------------------------------------
% 2. Delay-to-frequency transform
% ------------------------------------------------------------
% Unitary DFT of size M along the delay axis (dim 1, rows)
%
% MATLAB fft uses the kernel:
%   exp(-j*2*pi*m*k/M)
%
% fft does not include a normalization factor, so division by
% sqrt(M) makes the transform unitary.
frequencyDopplerGrid = fft(xDD, M, 1) / sqrt(M);

% ------------------------------------------------------------
% 3. Doppler-to-time transform
% ------------------------------------------------------------
% Unitary IDFT of size N along the Doppler axis (dim 2, columns)
%
% MATLAB ifft uses the kernel:
%   exp(+j*2*pi*n*l/N)
%
% MATLAB ifft includes a factor 1/N. Multiplication by sqrt(N)
% changes this factor to 1/sqrt(N), making the transform unitary.
XTF = sqrt(N) * ifft(frequencyDopplerGrid, N, 2);

end
