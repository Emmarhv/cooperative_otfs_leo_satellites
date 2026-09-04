function bits = demodulate_symbols(symbols, params)
% ============================================================
% demodulate_symbols.m
%
% Demodulate square M-QAM symbols using Gray mapping and
% unit-average-power normalization.
%
% Inputs:
% - symbols : received complex QAM symbols
% - params  : struct containing modOrder and bitsPerSymbol
%
% Output:
% - bits : estimated binary column vector
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
    error('demodulate_symbols:InvalidParams', ...
        'params must contain modOrder and bitsPerSymbol.');
end

M = params.modOrder;
bitsPerSymbol = params.bitsPerSymbol;

if ~isscalar(M) || ~isreal(M) || ~isfinite(M) || M <= 0 || ...
        mod(log2(M), 1) ~= 0 || mod(sqrt(M), 1) ~= 0
    error('demodulate_symbols:InvalidModOrder', ...
        'modOrder must be a square power of two.');
end

if ~isscalar(bitsPerSymbol) || ...
        bitsPerSymbol ~= log2(M)
    error('demodulate_symbols:InconsistentParameters', ...
        'bitsPerSymbol must equal log2(modOrder).');
end

% ------------------------------------------------------------
% 2. Validate received symbols
% ------------------------------------------------------------

if ~isnumeric(symbols) || isempty(symbols)
    error('demodulate_symbols:InvalidInput', ...
        'symbols must be a non-empty numeric array.');
end

symbols = symbols(:);

if any(~isfinite(symbols))
    error('demodulate_symbols:NonFiniteInput', ...
        'symbols must contain only finite values.');
end

% ------------------------------------------------------------
% 3. QAM demodulation
% ------------------------------------------------------------

symbolIndices = qamdemod(symbols, M, 'gray', ...
    'UnitAveragePower', true);

bits = int2bit(symbolIndices, bitsPerSymbol);
bits = bits(:);

end