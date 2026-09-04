function dHat = combine_snr_weighted(d1, d2, gamma1, gamma2)
% ============================================================
% combine_snr_weighted.m
%
% Combine two equalized estimates of the same cooperative
% symbols using link-SNR weights:
%
%   dHat = (gamma1*d1 + gamma2*d2) / (gamma1 + gamma2)
%
% The weights follow inverse-noise-variance weighting for the
% reduced noise-only model, assuming negligible same-resource
% cross-branch noise covariance.
%
% The combiner does NOT model or cancel the structured
% cross-grid interference remaining after branch equalization.
% Therefore, it is not claimed to be optimal for the complete
% dual-satellite receiver.
%
% Inputs:
% - d1, d2         : equalized symbol estimates, same size
% - gamma1, gamma2 : non-negative finite link SNRs
%                    (linear scale)
%
% Output:
% - dHat : combined symbol estimates, same size as d1 and d2
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Input checks.
% ------------------------------------------------------------

if ~isequal(size(d1), size(d2))
    error('combine_snr_weighted:SizeMismatch', ...
        'd1 and d2 must have the same size.');
end

if ~isscalar(gamma1) || ~isreal(gamma1) || ...
        ~isfinite(gamma1) || gamma1 < 0
    error('combine_snr_weighted:InvalidGamma1', ...
        'gamma1 must be a finite non-negative real scalar.');
end

if ~isscalar(gamma2) || ~isreal(gamma2) || ...
        ~isfinite(gamma2) || gamma2 < 0
    error('combine_snr_weighted:InvalidGamma2', ...
        'gamma2 must be a finite non-negative real scalar.');
end

gammaSum = gamma1 + gamma2;

if gammaSum <= 0
    error('combine_snr_weighted:ZeroTotalGamma', ...
        'At least one link SNR must be positive.');
end

% ------------------------------------------------------------
% 2. SNR-weighted combination.
% ------------------------------------------------------------

weight1 = gamma1 / gammaSum;
weight2 = gamma2 / gammaSum;

dHat = weight1 .* d1 + weight2 .* d2;

end