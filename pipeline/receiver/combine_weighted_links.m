function zClean = combine_weighted_links( ...
    r1, r2, gamma1, gamma2)
% ============================================================
% combine_weighted_links.m
%
% Apply the frozen two-link weighted combination
%
%   zClean = gamma1*r1 + gamma2*r2
%
% in the time domain, before noise addition and OTFS
% demodulation.
%
% gamma1 and gamma2 represent the effective link gains
% obtained from the link budget.
%
% IMPORTANT:
% This function performs no timing, Doppler or phase
% compensation. It only applies the two scalar link weights
% and adds the branch signals.
%
% Therefore:
%
% - In the compensated baseline, satellite 2 has already been
%   aligned by the TX compensation mechanism before this
%   function is called.
%
% - In the no-compensation B3 ablation, satellite 2 is
%   deliberately not aligned. Its residual distortion is
%   preserved and this function applies exactly the same
%   receiver weighting as in the baseline.
%
% Keeping the same combiner in both cases isolates the effect
% of removing satellite-2 TX compensation.
%
% Noise is not added here. In the reduced baseline model, one
% normalized complex-noise realization is added after this
% clean combination using
%
%   gammaOut = gamma1 + gamma2.
%
% Inputs:
% - r1, r2         : clean received branch signals, same size
% - gamma1, gamma2 : effective link SNRs in linear scale
%
% Output:
% - zClean : weighted clean signal before noise
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate inputs
% ------------------------------------------------------------

if ~isnumeric(r1) || ...
        ~isnumeric(r2) || ...
        isempty(r1) || ...
        isempty(r2)

    error('combine_weighted_links:InvalidSignal', ...
        'r1 and r2 must be non-empty numeric arrays.');
end

if ~isequal(size(r1), size(r2))

    error('combine_weighted_links:SizeMismatch', ...
        'r1 and r2 must have the same size.');
end

if any(~isfinite(r1(:))) || ...
        any(~isfinite(r2(:)))

    error('combine_weighted_links:NonFiniteSignal', ...
        'r1 and r2 must contain only finite values.');
end

if ~isnumeric(gamma1) || ...
        ~isscalar(gamma1) || ...
        ~isreal(gamma1) || ...
        ~isfinite(gamma1) || ...
        gamma1 < 0 || ...
        ~isnumeric(gamma2) || ...
        ~isscalar(gamma2) || ...
        ~isreal(gamma2) || ...
        ~isfinite(gamma2) || ...
        gamma2 < 0

    error('combine_weighted_links:InvalidGamma', ...
        ['gamma1 and gamma2 must be non-negative ' ...
         'finite real scalars.']);
end

% ------------------------------------------------------------
% 2. Weighted clean combination
% ------------------------------------------------------------

zClean = ...
    gamma1 .* r1 + ...
    gamma2 .* r2;

end