function snrLinear = compute_link_snr( ...
    numRxElements, slantRange, linkParams)
% ============================================================
% compute_link_snr.m
%
% Compute the effective received SNR of one satellite link
% from the physical link budget:
%
%   gamma = EIRP * N_R * G_R
%           ----------------
%           L_fs * B * k_B * T_sys
%
% where:
% - EIRP  : equivalent isotropic radiated power
% - N_R   : receive-array gain represented by the number of
%           receive antenna elements
% - G_R   : receive-element gain
% - L_fs  : free-space path loss
% - B     : system bandwidth
% - k_B   : Boltzmann constant
% - T_sys : receiver system temperature
%
% The result gamma is a dimensionless link SNR in linear scale.
% It is not Eb/N0 or Es/N0, and no modulation-dependent
% conversion is performed in this function.
%
% The receive array is represented only through the equivalent
% scalar gain N_R. Steering vectors and beamforming weights are
% not modeled explicitly.
%
% Inputs:
% - numRxElements : number of receive antenna elements
% - slantRange    : satellite-user slant range, in metres
% - linkParams    : structure containing the physical
%                   link-budget parameters
%
% Output:
% - snrLinear : effective received link SNR, linear scale
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate inputs
% ------------------------------------------------------------
if ~isnumeric(numRxElements) || ~isscalar(numRxElements) || ...
        ~isreal(numRxElements) || ~isfinite(numRxElements) || ...
        numRxElements <= 0 || numRxElements ~= round(numRxElements)
    error('compute_link_snr:InvalidArraySize', ...
        'numRxElements must be a positive integer scalar.');
end

if ~isnumeric(slantRange) || ~isscalar(slantRange) || ...
        ~isreal(slantRange) || ~isfinite(slantRange) || ...
        slantRange <= 0
    error('compute_link_snr:InvalidRange', ...
        'slantRange must be a finite positive real scalar.');
end

if ~isstruct(linkParams)
    error('compute_link_snr:InvalidLinkParameters', ...
        'linkParams must be a structure.');
end

requiredFields = { ...
    'eirpDbm', ...
    'rxElementGainDb', ...
    'speedOfLight', ...
    'carrierFrequency', ...
    'boltzmann', ...
    'systemTemperature', ...
    'bandwidth'};

for fieldIndex = 1:numel(requiredFields)
    fieldName = requiredFields{fieldIndex};

    if ~isfield(linkParams, fieldName)
        error('compute_link_snr:MissingParameter', ...
            'linkParams.%s is required.', fieldName);
    end
end

% ------------------------------------------------------------
% 2. Convert link-budget quantities to linear scale
% ------------------------------------------------------------

% EIRP: dBm -> W.
eirpW = 10^((linkParams.eirpDbm - 30) / 10);

% Receive-element gain: dB -> linear.
rxElementGain = ...
    10^(linkParams.rxElementGainDb / 10);

% ------------------------------------------------------------
% 3. Compute free-space path loss
% ------------------------------------------------------------
wavelength = ...
    linkParams.speedOfLight / ...
    linkParams.carrierFrequency;

freeSpaceLoss = ...
    (4 * pi * slantRange / wavelength)^2;

% ------------------------------------------------------------
% 4. Compute thermal noise power
% ------------------------------------------------------------
noisePower = ...
    linkParams.boltzmann * ...
    linkParams.systemTemperature * ...
    linkParams.bandwidth;

% ------------------------------------------------------------
% 5. Compute effective link SNR
% ------------------------------------------------------------
snrLinear = ...
    eirpW * numRxElements * rxElementGain / ...
    (freeSpaceLoss * noisePower);

end