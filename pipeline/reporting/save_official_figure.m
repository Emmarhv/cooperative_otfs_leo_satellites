function save_official_figure(fig, outputDir, baseName)
% ============================================================
% save_official_figure.m
%
% Export one official reporting figure in:
%
%   PNG -- 300 dpi, convenient for quick inspection
%   PDF -- vector format, intended for the thesis / Overleaf
%
% This function performs no simulation and modifies no
% numerical result.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate output folder
% ------------------------------------------------------------

if ~isfolder(outputDir)
    mkdir(outputDir);
end

if isempty(baseName)
    error('save_official_figure:EmptyBaseName', ...
        'baseName must not be empty.');
end

% ------------------------------------------------------------
% 2. Export
% ------------------------------------------------------------

pngFile = fullfile(outputDir, [baseName '.png']);
pdfFile = fullfile(outputDir, [baseName '.pdf']);

exportgraphics( ...
    fig, ...
    pngFile, ...
    'Resolution', 300);

exportgraphics( ...
    fig, ...
    pdfFile, ...
    'ContentType', 'vector');

fprintf('Saved figure:\n');
fprintf('  %s\n', pngFile);
fprintf('  %s\n', pdfFile);

end