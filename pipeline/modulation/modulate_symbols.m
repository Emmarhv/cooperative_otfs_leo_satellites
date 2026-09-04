function symbols = modulate_symbols(bits, params)
% ============================================================
% modulate_symbols.m
%
% Map binary data to square M-QAM symbols using Gray mapping
% and unit-average-power normalization.
%
% Supported orders include QPSK/4-QAM, 16-QAM and 64-QAM.
%
% Inputs:
% - bits   : binary input vector
% - params : struct containing modOrder and bitsPerSymbol
%
% Output:
% - symbols : complex QAM symbol column vector
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate modulation parameters
% ------------------------------------------------------------

if ~isstruct(params) || ...
        ~isfield(params, 'modOrder') || ...
        ~isfield(params, 'bitsPerSymbol')
    error('modulate_symbols:InvalidParams', ...
        'params must contain modOrder and bitsPerSymbol.');
end

M = params.modOrder;
bitsPerSymbol = params.bitsPerSymbol;

if ~isscalar(M) || ~isreal(M) || ~isfinite(M) || M <= 0 || ...
        mod(log2(M), 1) ~= 0 || mod(sqrt(M), 1) ~= 0
    error('modulate_symbols:InvalidModOrder', ...
        'modOrder must be a square power of two.');
end

if ~isscalar(bitsPerSymbol) || ...
        bitsPerSymbol ~= log2(M)
    error('modulate_symbols:InconsistentParameters', ...
        'bitsPerSymbol must equal log2(modOrder).');
end

% ------------------------------------------------------------
% 2. Validate input bits
% ------------------------------------------------------------

bits = bits(:);

if isempty(bits)
    error('modulate_symbols:EmptyInput', ...
        'bits must not be empty.');
end

if any(~isfinite(bits)) || any(bits ~= 0 & bits ~= 1)
    error('modulate_symbols:NonBinaryInput', ...
        'bits must contain only zeros and ones.');
end

if mod(numel(bits), bitsPerSymbol) ~= 0
    error('modulate_symbols:InvalidBitCount', ...
        ['The number of bits (%d) must be a multiple of ' ...
         'bitsPerSymbol (%d).'], ...
        numel(bits), bitsPerSymbol);
end

% ------------------------------------------------------------
% 3. QAM modulation
% ------------------------------------------------------------

symbolIndices = bit2int(bits, bitsPerSymbol);

symbols = qammod(symbolIndices, M, 'gray', ...
    'UnitAveragePower', true);

end