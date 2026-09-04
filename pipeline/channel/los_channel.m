function rx = los_channel(tx, M, N, l, k, kappa, h)
% ============================================================
% los_channel.m
%
% Single-path LoS channel over one useful OTFS block.
%
% Channel model:
%
%   rx[n] = h ...
%         * exp(j*2*pi*(k+kappa)*(n-l)/(M*N)) ...
%         * tx[(n-l) mod (M*N)]
%
% Processing:
%   circular integer delay
%   -> integer/fractional Doppler
%   -> complex LoS gain
%
% The circular delay represents the CP-protected equivalent
% block model. Explicit propagation delay, CP transmission and
% timing acquisition are not modeled inside this function.
%
% This physical channel convention follows:
% "Coordinated Multi-Satellite Transmission for OTFS-Based
% 6G LEO Satellite Communication Systems", eqs. (8)-(10).
%
% Inputs:
% - tx      : useful time-domain OTFS block, row or column
% - M       : number of delay bins
% - N       : number of Doppler bins
% - l       : integer delay tap, 0 <= l < M
% - k       : integer Doppler tap
% - kappa   : fractional Doppler, -0.5 < kappa <= 0.5
% - h       : complex LoS channel gain
%
% Output:
% - rx      : received block, with the same orientation as tx
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate input signal
% ------------------------------------------------------------
if ~isnumeric(tx) || ~isvector(tx) || isempty(tx)
    error('los_channel:InvalidInput', ...
        'tx must be a non-empty numeric vector.');
end

if any(~isfinite(tx(:)))
    error('los_channel:NonFiniteInput', ...
        'tx must contain only finite values.');
end

% ------------------------------------------------------------
% 2. Validate channel parameters
% ------------------------------------------------------------
if ~isscalar(M) || ~isnumeric(M) || M <= 0 || M ~= round(M)
    error('los_channel:InvalidDelayDimension', ...
        'M must be a positive integer scalar.');
end

if ~isscalar(N) || ~isnumeric(N) || N <= 0 || N ~= round(N)
    error('los_channel:InvalidDopplerDimension', ...
        'N must be a positive integer scalar.');
end

if ~isscalar(l) || ~isnumeric(l) || ...
        l < 0 || l >= M || l ~= round(l)
    error('los_channel:InvalidDelayTap', ...
        'l must be an integer satisfying 0 <= l < M.');
end

if ~isscalar(k) || ~isnumeric(k) || ...
        ~isfinite(k) || k ~= round(k)
    error('los_channel:InvalidDopplerTap', ...
        'k must be a finite integer scalar.');
end

if ~isscalar(kappa) || ~isnumeric(kappa) || ...
        ~isreal(kappa) || ~isfinite(kappa) || ...
        kappa <= -0.5 || kappa > 0.5
    error('los_channel:InvalidFractionalDoppler', ...
        'kappa must satisfy -0.5 < kappa <= 0.5.');
end

if ~isscalar(h) || ~isnumeric(h) || ~isfinite(h)
    error('los_channel:InvalidChannelGain', ...
        'h must be a finite numeric scalar.');
end

% ------------------------------------------------------------
% 3. Prepare the useful OTFS block
% ------------------------------------------------------------
frameLength = M * N;

isRowVector = isrow(tx);
txColumn = tx(:);

if numel(txColumn) ~= frameLength
    error('los_channel:InvalidLength', ...
        'tx must contain exactly M*N useful samples.');
end

% ------------------------------------------------------------
% 4. Apply circular delay
% ------------------------------------------------------------
% Positive l delays the block by l samples.
delayedSignal = circshift(txColumn, l);

% ------------------------------------------------------------
% 5. Apply Doppler phase rotation
% ------------------------------------------------------------
sampleIndex = (0:frameLength-1).';

dopplerPhase = exp(1j * 2*pi * (k + kappa) ...
    .* (sampleIndex - l) / frameLength);

% ------------------------------------------------------------
% 6. Apply complex LoS gain
% ------------------------------------------------------------
rx = h .* dopplerPhase .* delayedSignal;

% Preserve the original signal orientation.
if isRowVector
    rx = rx.';
end

end