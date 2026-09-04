function pDD = apply_precoder_blocks(xDD, precoderBlocks, lEff)
% ============================================================
% apply_precoder_blocks.m
%
% Apply the Doppler precoder blocks B^q and pre-compensate the
% residual integer-delay permutation at the transmitter.
%
% The blocks B^q are built according to the row-wise precoder
% formulation used in P7. They compensate the Doppler effect
% within each delay row.
%
% In the original P7 formulation, after precoding the symbols
% are still affected by the cyclic row permutation caused by
% lEff. This permutation is later handled at the receiver
% through the Pi^l term.
%
% In this project, the inverse row permutation is instead moved
% to the transmitter:
%
%   temp[q,:] = B^q * xDD[q,:]
%   pDD       = circshift(temp, -lEff, 1)
%
% Therefore, B^q compensates the Doppler effect and the final
% circshift pre-compensates the integer delay. This allows the
% satellite branch to be already delay-aligned before the two
% links are combined.
%
% Inputs:
% - xDD            : M x L delay-Doppler input grid
% - precoderBlocks : M precoder blocks B^q of size L x L
% - lEff           : residual integer delay, 0 <= lEff < M
%
% Output:
% - pDD : M x L precoded grid, ready for OTFS modulation
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate inputs
% ------------------------------------------------------------
if ~isnumeric(xDD) || ~ismatrix(xDD) || isempty(xDD) || ...
        any(~isfinite(xDD(:)))
    error('apply_precoder_blocks:InvalidGrid', ...
        'xDD must be a non-empty finite numeric matrix.');
end

[M, L] = size(xDD);

if ~iscell(precoderBlocks) || numel(precoderBlocks) ~= M
    error('apply_precoder_blocks:InvalidBlocks', ...
        ['precoderBlocks must contain M entries, ' ...
         'one for each delay row.']);
end

for q0 = 0:M-1
    Bq = precoderBlocks{q0 + 1};

    if ~isnumeric(Bq) || ...
            ~isequal(size(Bq), [L L]) || ...
            any(~isfinite(Bq(:)))
        error('apply_precoder_blocks:InvalidBlock', ...
            ['precoderBlocks{%d} must be a finite ' ...
             'L x L numeric matrix.'], q0 + 1);
    end
end

if ~isnumeric(lEff) || ~isscalar(lEff) || ...
        ~isreal(lEff) || ~isfinite(lEff) || ...
        lEff ~= round(lEff) || lEff < 0 || lEff >= M
    error('apply_precoder_blocks:InvalidDelay', ...
        'lEff must be an integer satisfying 0 <= lEff < M.');
end

% ------------------------------------------------------------
% 2. Apply the Doppler precoder block of each delay row
% ------------------------------------------------------------
temp = zeros(M, L);

for q0 = 0:M-1
    Bq = precoderBlocks{q0 + 1};

    temp(q0 + 1, :) = ...
        (Bq * xDD(q0 + 1, :).').';
end

% ------------------------------------------------------------
% 3. Pre-compensate the residual delay-row permutation
% ------------------------------------------------------------
pDD = circshift(temp, -lEff, 1);

end