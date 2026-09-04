function scaledBlock = scale_active_symbols(block, activeIdx, amplitudeScale)
% ============================================================
% scale_active_symbols.m
%
% Scales the amplitude of the active cooperative resources of a
% single common-block DD vector, leaving inactive (zero)
% resources untouched.
%
% For the frozen mapper, 14 of the 64 common-Doppler-space
% positions per row are active. To make the sparse waveform's
% average transmit power match a fully-loaded reference grid
% (unit average power per common-space resource, same
% convention the baseline uses over its full M x N grid), the
% active symbols must be scaled by:
%
%   amplitudeScale = sqrt(Ncommon / numActivePerRow) = sqrt(64/14)
%
% so that energy per row becomes
% numActivePerRow * amplitudeScale^2 = Ncommon, matching a
% fully-loaded unit-power row. This function only applies the
% scaling; it does not compute the factor (kept explicit at the
% call site so it is never silently guessed).
%
% Inputs:
% - block           : full common-block DD vector
%                     (K1*M*N1 for Sat1, M*N2 for Sat2)
% - activeIdx        : indices of the active cooperative
%                      resources within block
% - amplitudeScale   : real, positive scalar amplitude factor
%
% Output:
% - scaledBlock : same size as block, with
%                 scaledBlock(activeIdx) = block(activeIdx)*amplitudeScale
%                 and all other entries unchanged (zero, by
%                 construction of the frozen-mapper payload).
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

if ~isscalar(amplitudeScale) || ~isreal(amplitudeScale) || ...
        ~isfinite(amplitudeScale) || amplitudeScale <= 0
    error('scale_active_symbols:InvalidScale', ...
        'amplitudeScale must be a finite positive real scalar.');
end

scaledBlock = block;
scaledBlock(activeIdx) = block(activeIdx) * amplitudeScale;

end