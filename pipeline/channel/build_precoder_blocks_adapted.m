function [precoderBlocks, numActiveCoeffs, cvec] = build_precoder_blocks_adapted( ...
    M, L, ieff, keff, kappaeff, truncationOrder)
% ============================================================
% build_precoder_blocks_adapted.m
%
% Build one L x L transmit-precoder block B^q for each output
% delay row q of a single-user, single-path residual OTFS link.
%
% The Doppler coefficients c^l follow eq. (9) of:
% "Cooperative Dual LEO Satellite Transmission in Multi-User
% OTFS Systems".
%
% The base matrix is formed as in eqs. (10)-(12):
%
%   Cmat = [(c^0)^H, ..., (c^(L-1))^H]
%
% where column m corresponds to output Doppler index m, and each
% row corresponds to an input Doppler index r. Since the channel
% term reads input Doppler position
%
%   r = (m-l) mod L,
%
% the coefficient multiplying input position r is
%
%   c^l,  with l = (m-r) mod L.
%
% For q >= ieff, the implementation coincides with the published
% no-wrap expression.
%
% For q < ieff, the project-adapted channel model uses the wrap
% phase
%
%   exp(-j*2*pi*r/L),
%
% with r the input Doppler index. In the precoder its conjugate
% therefore multiplies the rows of Cmat.
%
% The common Doppler phase for output delay row q is
%
%   exp(j*2*pi*Omega*(q-ieff)/(M*L)),
%
% with Omega = keff + kappaeff.
%
% Inputs:
% - M, L        : number of delay and Doppler bins
% - ieff        : integer residual delay, 0 <= ieff < M
% - keff        : integer residual Doppler
% - kappaeff    : fractional residual Doppler
% - truncationOrder : optional non-negative integer P. When
%                    provided, only the Doppler coefficients c^l
%                    with l in the window {keff-P,...,keff+P}
%                    (mod L) are kept; every other c^l is set to
%                    zero. This reduces the number of active
%                    Doppler taps to Ls = 2*P+1 <= L, matching the
%                    reduced-coefficient precoder described in the
%                    reference formulation. Omit or pass [] to keep
%                    all L coefficients (default, current
%                    validated behavior).
%
% Output:
% - precoderBlocks  : M x 1 cell array
%                     precoderBlocks{q+1} contains the L x L
%                     precoder B^q for output delay row q
% - numActiveCoeffs : number of non-zero Doppler coefficients
%                     actually used (Ls). Equals L when no
%                     truncation is applied.
% - cvec            : 1 x L row vector with the Doppler
%                     coefficients c^l actually used (after
%                     truncation, if any -- zeroed entries
%                     outside the kept window). Exposed so
%                     that metrics/compute_truncation_sinr.m
%                     can reuse the exact same coefficients
%                     without recomputing them.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate parameters
% ------------------------------------------------------------
validate_precoder_parameters(M, L, ieff, keff, kappaeff);

% Complete residual Doppler in grid-bin units.
Omega = keff + kappaeff;

% ------------------------------------------------------------
% 2. Doppler coefficients c^l, eq. (9)
% ------------------------------------------------------------
% cvec(l+1) stores c^l, for l = 0,...,L-1.
cvec = zeros(1, L);

for l0 = 0:L-1
    xArg = Omega - l0;

    numerator = 1 - exp(1j * 2*pi * xArg);
    denominator = L * ...
        (1 - exp(1j * 2*pi * xArg / L));

    if abs(denominator) < 1e-12
        % Removable singularity: c^l tends to 1.
        cvec(l0 + 1) = 1;
    else
        cvec(l0 + 1) = numerator / denominator;
    end
end

% ------------------------------------------------------------
% 2b. Optional truncation to a reduced coefficient window
% ------------------------------------------------------------
% Keeps only the coefficients c^l with l in the window
% formulation: 2*P+1 = Ls <= L active taps.
if nargin >= 6 && ~isempty(truncationOrder)
    validate_truncation_order(truncationOrder, L);

    windowIndices0 = mod( ...
        (keff - truncationOrder):(keff + truncationOrder), L);

    keepMask = false(1, L);
    keepMask(windowIndices0 + 1) = true;

    cvec(~keepMask) = 0;
    numActiveCoeffs = sum(keepMask);
else
    numActiveCoeffs = L;
end

% ------------------------------------------------------------
% 3. Build Cmat = [(c^0)^H, ..., (c^(L-1))^H]
% ------------------------------------------------------------
% Column m corresponds to output Doppler index m.
% Row r corresponds to input Doppler index r.
%
% From r = (m-l) mod L:
%
%   l = (m-r) mod L.
%
% Therefore:
%
%   Cmat(r,m) = conj(c^((m-r) mod L)).
%
% MATLAB indices are shifted by +1 because they start at 1.
Cmat = zeros(L, L);

for outputDoppler0 = 0:L-1
    for inputDoppler0 = 0:L-1
        coefficientIndex = mod( ...
            outputDoppler0 - inputDoppler0, L);

        Cmat(inputDoppler0 + 1, outputDoppler0 + 1) = ...
            conj(cvec(coefficientIndex + 1));
    end
end

% Conjugate wrap phase associated with each input Doppler index.
% Used only when q < ieff.
inputWrapConj = exp( ...
    1j * 2*pi * (0:L-1).' / L);

% ------------------------------------------------------------
% 4. Build one precoder block B^q per output delay row
% ------------------------------------------------------------
precoderBlocks = cell(M, 1);

for q0 = 0:M-1

    % Common Doppler phase for this output delay row.
    % The adapted convention keeps (q-ieff) signed.
    baseDopplerPhase = exp( ...
        1j * 2*pi * Omega * (q0 - ieff) / (M*L));

    if q0 >= ieff
        % No delay wrap-around.
        % The published and adapted expressions coincide.
        Bq = conj(baseDopplerPhase) * Cmat;

    else
        % Delay wrap-around.
        %
        % The adapted wrap phase depends on the input Doppler
        % index r. After taking the channel adjoint, its conjugate
        % scales the rows of Cmat.
        Bq = diag(inputWrapConj) ...
            * Cmat ...
            * conj(baseDopplerPhase);
    end

    precoderBlocks{q0 + 1} = Bq;
end

end

% ============================================================
function validate_precoder_parameters( ...
    M, L, ieff, keff, kappaeff)

if ~isnumeric(M) || ~isscalar(M) || ~isreal(M) || ...
        ~isfinite(M) || M <= 0 || M ~= round(M)
    error('build_precoder_blocks_adapted:InvalidM', ...
        'M must be a positive finite integer.');
end

if ~isnumeric(L) || ~isscalar(L) || ~isreal(L) || ...
        ~isfinite(L) || L <= 0 || L ~= round(L)
    error('build_precoder_blocks_adapted:InvalidL', ...
        'L must be a positive finite integer.');
end

if ~isnumeric(ieff) || ~isscalar(ieff) || ...
        ~isreal(ieff) || ~isfinite(ieff) || ...
        ieff < 0 || ieff >= M || ieff ~= round(ieff)
    error('build_precoder_blocks_adapted:InvalidDelay', ...
        'ieff must be an integer satisfying 0 <= ieff < M.');
end

if ~isnumeric(keff) || ~isscalar(keff) || ...
        ~isreal(keff) || ~isfinite(keff) || ...
        keff ~= round(keff)
    error('build_precoder_blocks_adapted:InvalidDoppler', ...
        'keff must be a finite integer.');
end

if ~isnumeric(kappaeff) || ~isscalar(kappaeff) || ...
        ~isreal(kappaeff) || ~isfinite(kappaeff) || ...
        kappaeff <= -0.5 || kappaeff > 0.5
    error( ...
        'build_precoder_blocks_adapted:InvalidFractionalDoppler', ...
        'kappaeff must satisfy -0.5 < kappaeff <= 0.5.');
end

end

% ============================================================
function validate_truncation_order(truncationOrder, L)

if ~isnumeric(truncationOrder) || ~isscalar(truncationOrder) || ...
        ~isreal(truncationOrder) || ~isfinite(truncationOrder) || ...
        truncationOrder < 0 || ...
        truncationOrder ~= round(truncationOrder)
    error( ...
        'build_precoder_blocks_adapted:InvalidTruncationOrder', ...
        'truncationOrder must be a non-negative finite integer.');
end

windowSize = 2*truncationOrder + 1;

if windowSize > L
    error( ...
        'build_precoder_blocks_adapted:TruncationOrderTooLarge', ...
        ['truncationOrder produces a window of %d coefficients, ' ...
        'larger than L = %d. Reduce truncationOrder or omit it ' ...
        'to keep all L coefficients.'], windowSize, L);
end

end