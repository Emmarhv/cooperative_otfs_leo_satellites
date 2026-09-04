function noisySignal = add_normalized_complex_noise( ...
    signal, noiseVariance)
% ============================================================
% add_normalized_complex_noise.m
%
% Add proper complex Gaussian noise with total variance:
%
%   E{|w|^2} = noiseVariance.
%
% The real and imaginary components therefore have variance
%
%   noiseVariance / 2.
%
% This helper works directly with a specified noise variance and
% does not perform any Eb/N0 or Es/N0 conversion.
%
% Inputs:
% - signal        : input numeric array
% - noiseVariance : total complex-noise variance
%
% Output:
% - noisySignal   : signal + w
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate inputs
% ------------------------------------------------------------
if ~isnumeric(signal) || isempty(signal)
    error('add_normalized_complex_noise:InvalidSignal', ...
        'signal must be a non-empty numeric array.');
end

if any(~isfinite(signal(:)))
    error('add_normalized_complex_noise:NonFiniteSignal', ...
        'signal must contain only finite values.');
end

if ~isnumeric(noiseVariance) || ~isscalar(noiseVariance) || ...
        ~isreal(noiseVariance) || ~isfinite(noiseVariance) || ...
        noiseVariance < 0
    error('add_normalized_complex_noise:InvalidVariance', ...
        'noiseVariance must be a non-negative finite real scalar.');
end

% ------------------------------------------------------------
% 2. Generate proper complex Gaussian noise
% ------------------------------------------------------------
noise = sqrt(noiseVariance / 2) .* ...
    (randn(size(signal)) + 1j * randn(size(signal)));

% ------------------------------------------------------------
% 3. Add the noise to the input signal
% ------------------------------------------------------------
noisySignal = signal + noise;

end