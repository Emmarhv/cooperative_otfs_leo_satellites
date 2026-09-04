function payloads = generate_common_block_payloads( ...
    numBlocks, sat1IdxAllRows, sat2IdxAllRows, ...
    blockSizeSat1, blockSizeSat2, qamParams)

% ============================================================
% generate_common_block_payloads.m
%
% Generate independent common-block modulation payloads for
% cooperative transmission.
%
% Payloads are independent between common blocks. Within each
% block, Sat1 and Sat2 transmit the SAME symbol vector on their
% corresponding mapped DD resources.
%
% This function only creates DD-domain payloads. It does not
% perform OTFS modulation, timing shifts or waveform generation.
%
% The modulation format is defined by qamParams and handled by
% modulate_symbols.m.
%
% Inputs:
% - numBlocks       : number of common blocks
% - sat1IdxAllRows  : active Sat1 DD resource indices
% - sat2IdxAllRows  : corresponding active Sat2 DD indices
% - blockSizeSat1   : Sat1 DD vector length
% - blockSizeSat2   : Sat2 DD vector length
% - qamParams       : modulation configuration
%
% Output:
% - payloads.txBits
% - payloads.txSymbolsPerBlock
% - payloads.dSat1Blocks
% - payloads.dSat2Blocks
% - payloads.numActiveSymbols
% - payloads.numBitsPerBlock
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Input validation.
% ------------------------------------------------------------

if ~isscalar(numBlocks) || ~isfinite(numBlocks) || ...
        numBlocks < 1 || numBlocks ~= round(numBlocks)
    error('generate_common_block_payloads:InvalidNumBlocks', ...
        'numBlocks must be a positive integer scalar.');
end

if ~isscalar(blockSizeSat1) || ~isfinite(blockSizeSat1) || ...
        blockSizeSat1 < 1 || blockSizeSat1 ~= round(blockSizeSat1)
    error('generate_common_block_payloads:InvalidSat1BlockSize', ...
        'blockSizeSat1 must be a positive integer scalar.');
end

if ~isscalar(blockSizeSat2) || ~isfinite(blockSizeSat2) || ...
        blockSizeSat2 < 1 || blockSizeSat2 ~= round(blockSizeSat2)
    error('generate_common_block_payloads:InvalidSat2BlockSize', ...
        'blockSizeSat2 must be a positive integer scalar.');
end

sat1IdxAllRows = sat1IdxAllRows(:);
sat2IdxAllRows = sat2IdxAllRows(:);

numActiveSymbols = numel(sat1IdxAllRows);

if numActiveSymbols == 0
    error('generate_common_block_payloads:EmptyResourceSet', ...
        'The active resource set must not be empty.');
end

if numel(sat2IdxAllRows) ~= numActiveSymbols
    error('generate_common_block_payloads:IndexCountMismatch', ...
        'Sat1 and Sat2 resource sets must have the same length.');
end

if any(~isfinite(sat1IdxAllRows)) || ...
        any(sat1IdxAllRows ~= round(sat1IdxAllRows)) || ...
        any(sat1IdxAllRows < 1) || ...
        any(sat1IdxAllRows > blockSizeSat1)
    error('generate_common_block_payloads:InvalidSat1Indices', ...
        'sat1IdxAllRows contains invalid resource indices.');
end

if any(~isfinite(sat2IdxAllRows)) || ...
        any(sat2IdxAllRows ~= round(sat2IdxAllRows)) || ...
        any(sat2IdxAllRows < 1) || ...
        any(sat2IdxAllRows > blockSizeSat2)
    error('generate_common_block_payloads:InvalidSat2Indices', ...
        'sat2IdxAllRows contains invalid resource indices.');
end

if numel(unique(sat1IdxAllRows)) ~= numActiveSymbols || ...
        numel(unique(sat2IdxAllRows)) ~= numActiveSymbols
    error('generate_common_block_payloads:DuplicateIndices', ...
        'Active resource sets must not contain duplicate indices.');
end

requiredFields = {'modOrder', 'bitsPerSymbol'};

for fieldIdx = 1:numel(requiredFields)
    if ~isfield(qamParams, requiredFields{fieldIdx})
        error('generate_common_block_payloads:MissingQamParameter', ...
            'qamParams is missing field "%s".', ...
            requiredFields{fieldIdx});
    end
end

if qamParams.bitsPerSymbol ~= log2(qamParams.modOrder)
    error('generate_common_block_payloads:InvalidBitsPerSymbol', ...
        'bitsPerSymbol must equal log2(modOrder).');
end

numBitsPerBlock = ...
    numActiveSymbols * qamParams.bitsPerSymbol;

% ------------------------------------------------------------
% 2. Generate independent common-block payloads.
% ------------------------------------------------------------

txBits = cell(1, numBlocks);
txSymbolsPerBlock = cell(1, numBlocks);

dSat1Blocks = cell(1, numBlocks);
dSat2Blocks = cell(1, numBlocks);

for blockIdx = 1:numBlocks

    % Independent information between common blocks.
    txBits{blockIdx} = ...
        randi([0 1], numBitsPerBlock, 1);

    txSymbolsPerBlock{blockIdx} = ...
        modulate_symbols(txBits{blockIdx}, qamParams);

    if numel(txSymbolsPerBlock{blockIdx}) ~= numActiveSymbols
        error('generate_common_block_payloads:ModulationSize', ...
            'Unexpected number of modulated symbols.');
    end

    % Full DD vectors for each satellite.
    dSat1Blocks{blockIdx} = ...
        complex(zeros(blockSizeSat1, 1));

    dSat2Blocks{blockIdx} = ...
        complex(zeros(blockSizeSat2, 1));

    % Same cooperative symbols on corresponding resources.
    dSat1Blocks{blockIdx}(sat1IdxAllRows) = ...
        txSymbolsPerBlock{blockIdx};

    dSat2Blocks{blockIdx}(sat2IdxAllRows) = ...
        txSymbolsPerBlock{blockIdx};
end

% ------------------------------------------------------------
% 3. Output.
% ------------------------------------------------------------

payloads = struct();

payloads.txBits = txBits;
payloads.txSymbolsPerBlock = txSymbolsPerBlock;

payloads.dSat1Blocks = dSat1Blocks;
payloads.dSat2Blocks = dSat2Blocks;

payloads.numActiveSymbols = numActiveSymbols;
payloads.numBitsPerBlock = numBitsPerBlock;
payloads.numBlocks = numBlocks;

end