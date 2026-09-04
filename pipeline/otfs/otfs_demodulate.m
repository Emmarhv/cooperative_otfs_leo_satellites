function [xDDHat, YTF] = otfs_demodulate(r, M, N, cpLength)
% ============================================================
% otfs_demodulate.m
%
% OTFS demodulator, inverse of otfs_modulate.m. Removes the
% single reduced cyclic prefix (RCP), applies the Wigner
% transform (rectangular pulse) and the SFFT to recover the
% delay-Doppler domain symbols.
%
% Grid convention:
% - YTF(m,n): rows = frequency, columns = time
% - yDD(k,l): rows = delay, columns = Doppler
% - Both grids have size M x N
%
% Processing chain:
%   r
%     -> remove RCP
%   rxNoCp
%     -> reshape
%   rxGrid
%     -> Wigner transform
%   YTF
%     -> SFFT
%   yDD
%
% Inputs:
% - r         : received time-domain signal, (M*N + cpLength) x 1
% - M         : number of delay bins (rows of the DD grid)
% - N         : number of Doppler bins (columns of the DD grid)
% - cpLength  : length of the RCP that was prepended at the
%               transmitter. Use 0 if no CP was used.
%
% Outputs:
% - xDDHat : M x N matrix, estimated delay-Doppler domain symbols
% - YTF    : M x N matrix, time-frequency domain grid (for
%            inspection/debugging purposes)
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate received signal
% ------------------------------------------------------------
if ~isnumeric(r) || ~isvector(r) || isempty(r)
    error('otfs_demodulate:invalidInput', ...
        'r must be a non-empty numeric vector.');
end

if any(~isfinite(r))
    error('otfs_demodulate:nonFiniteInput', ...
        'r must contain only finite values.');
end

% Accept row or column vectors, but use a column internally.
r = r(:);

% ------------------------------------------------------------
% 2. Validate grid dimensions
% ------------------------------------------------------------
if ~isscalar(M) || ~isnumeric(M) || ...
        M <= 0 || mod(M, 1) ~= 0 || ...
        ~isscalar(N) || ~isnumeric(N) || ...
        N <= 0 || mod(N, 1) ~= 0
    error('otfs_demodulate:invalidGridSize', ...
        'M and N must be positive integer scalars.');
end

% ------------------------------------------------------------
% 3. Validate cyclic-prefix length
% ------------------------------------------------------------
if ~isscalar(cpLength) || ~isnumeric(cpLength) || ...
        cpLength < 0 || mod(cpLength, 1) ~= 0
    error('otfs_demodulate:invalidCpLength', ...
        'cpLength must be a non-negative integer scalar.');
end

if cpLength > M*N
    error('otfs_demodulate:cpTooLong', ...
        'cpLength (%d) cannot exceed M*N (%d).', ...
        cpLength, M*N);
end

% ------------------------------------------------------------
% 4. Validate received-frame length
% ------------------------------------------------------------
expectedLength = M*N + cpLength;

if numel(r) ~= expectedLength
    error('otfs_demodulate:lengthMismatch', ...
        ['Received signal length (%d) does not match the ' ...
         'expected length M*N+cpLength (%d).'], ...
        numel(r), expectedLength);
end

% ------------------------------------------------------------
% 5. Remove the reduced cyclic prefix
% ------------------------------------------------------------
if cpLength > 0
    rxNoCp = r(cpLength+1:end);
else
    rxNoCp = r;
end

% ------------------------------------------------------------
% 6. Recover the delay-time sample grid
% ------------------------------------------------------------
% This is the inverse of u = uGrid(:).
rxGrid = reshape(rxNoCp, M, N);

% ------------------------------------------------------------
% 7. Wigner transform
% ------------------------------------------------------------
% With rectangular receive pulses, the discrete Wigner
% transform is an M-point unitary DFT over each time slot.
YTF = fft(rxGrid, M, 1) / sqrt(M);

% ------------------------------------------------------------
% 8. Time-frequency to delay-Doppler
% ------------------------------------------------------------
% SFFT
xDDHat = sfft(YTF);

end
