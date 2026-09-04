function plot_main_ber_comparison(mainResults, outputDir)
% ============================================================
% plot_main_ber_comparison.m
%
% Final BER comparison between the four main TFG scenarios:
%
%   1. Single satellite
%   2. Cooperative baseline - compensated
%   3. Cooperative baseline - no TX compensation
%   4. Proposed heterogeneous-grid - boosted
%
% One figure is generated per modulation.
%
% IMPORTANT:
% - BER is always represented on a logarithmic y-axis.
% - Zero-error Monte Carlo runs are NOT plotted as BER points.
% - A dashed horizontal line indicates the conservative
%   one-sided 95% upper-bound level when zero-error runs exist.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

modulations = {'QPSK', '16-QAM'};

scenarioNames = { ...
    'single_satellite', ...
    'baseline_compensated', ...
    'no_compensation', ...
    'proposal'};

scenarioLabels = { ...
    'Single satellite', ...
    'Cooperative baseline - compensated', ...
    'Cooperative baseline - no TX compensation', ...
    'Proposed heterogeneous-grid - boosted'};

lineStyles = { ...
    '-o', ...
    '-s', ...
    '-d', ...
    '-^'};

% ------------------------------------------------------------
% Generate one figure per modulation
% ------------------------------------------------------------

for modIdx = 1:numel(modulations)

    modulation = modulations{modIdx};

    fig = figure( ...
        'Visible', 'on', ...
        'Color', 'w', ...
        'Position', [100 100 900 650]);

    ax = axes(fig);

    hold(ax, 'on');
    grid(ax, 'on');
    box(ax, 'on');

    allMeasuredValues = [];
    allZeroUpperBounds = [];

    for scenarioIdx = 1:numel(scenarioNames)

        scenario = scenarioNames{scenarioIdx};

        mask = ...
            strcmp({mainResults.scenario}, scenario) & ...
            strcmp({mainResults.modulation}, modulation);

        rows = mainResults(mask);

        if isempty(rows)
            error('plot_main_ber_comparison:MissingScenario', ...
                'No results for %s / %s.', ...
                scenario, modulation);
        end

        [~, order] = sort([rows.NR]);
        rows = rows(order);

        NRdB = ...
            10 * log10([rows.NR]);

        [berMeasured, zeroUpperBounds] = ...
            local_prepare_ber(rows);

        semilogy( ...
            ax, ...
            NRdB, ...
            berMeasured, ...
            lineStyles{scenarioIdx}, ...
            'LineWidth', 1.6, ...
            'MarkerSize', 7, ...
            'DisplayName', scenarioLabels{scenarioIdx});

        allMeasuredValues = [ ...
            allMeasuredValues, ...
            berMeasured(isfinite(berMeasured))]; %#ok<AGROW>

        allZeroUpperBounds = [ ...
            allZeroUpperBounds, ...
            zeroUpperBounds(isfinite(zeroUpperBounds))]; %#ok<AGROW>
    end

    % --------------------------------------------------------
    % Zero-error reference line
    % --------------------------------------------------------

    if ~isempty(allZeroUpperBounds)

        zeroBoundLevel = ...
            max(allZeroUpperBounds);

        yline( ...
            ax, ...
            zeroBoundLevel, ...
            '--', ...
            'Zero-error 95% upper bound', ...
            'LineWidth', 1.2, ...
            'FontSize', 16, ...
            'LabelHorizontalAlignment', 'right', ...
            'LabelVerticalAlignment', 'top', ...
            'HandleVisibility', 'off');
    end

    % --------------------------------------------------------
    % Explicit logarithmic BER axis
    % --------------------------------------------------------

    ax.YScale = 'log';
    ax.YMinorGrid = 'on';
    ax.FontSize = 18;

    valuesForLimits = ...
        allMeasuredValues;

    if ~isempty(allZeroUpperBounds)
        valuesForLimits = [ ...
            valuesForLimits, ...
            max(allZeroUpperBounds)];
    end

    local_set_log_limits(ax, valuesForLimits);

    xlabel(ax, ...
        'Receiver array size, 10log_{10}(N_R) [dB]');

    ylabel(ax, ...
        'Uncoded combined BER');

    title(ax, ...
        sprintf('Main BER comparison - %s', modulation));

    legend(ax, ...
        'Location', 'southwest', ...
        'FontSize', 16);

    % --------------------------------------------------------
    % Export
    % --------------------------------------------------------

    if strcmp(modulation, 'QPSK')
        baseName = 'ber_main_qpsk';
    else
        baseName = 'ber_main_16qam';
    end

    save_official_figure( ...
        fig, outputDir, baseName);

    % Figure intentionally remains open in MATLAB.
end

end


% ============================================================
% Local helpers
% ============================================================

function [berMeasured, zeroUpperBounds] = local_prepare_ber(rows)

numRows = numel(rows);

berMeasured = NaN(1, numRows);
zeroUpperBounds = NaN(1, numRows);

for idx = 1:numRows

    row = rows(idx);

    if row.numErrors == 0

        if ~isfinite(row.upper95) || row.upper95 <= 0
            error('plot_main_ber_comparison:InvalidUpperBound', ...
                'Zero-error point has no valid upper95.');
        end

        % Do not create a fictitious positive BER point.
        berMeasured(idx) = NaN;
        zeroUpperBounds(idx) = row.upper95;

    else

        if ~isfinite(row.BER) || row.BER <= 0
            error('plot_main_ber_comparison:InvalidBER', ...
                'Observed-error point has invalid BER.');
        end

        berMeasured(idx) = row.BER;
    end
end

end


function local_set_log_limits(ax, values)

values = values( ...
    isfinite(values) & ...
    values > 0);

if isempty(values)
    error('plot_main_ber_comparison:NoPositiveValues', ...
        'No positive BER or upper-bound values available.');
end

yMin = ...
    10 ^ floor(log10(min(values)));

yMax = ...
    10 ^ ceil(log10(max(values) * 1.2));

yMax = min(1, yMax);

if yMax <= yMin
    yMax = min(1, 10 * yMin);
end

ylim(ax, [yMin, yMax]);

end