function plot_proposal_power_comparison( ...
    proposalPowerResults, outputDir)
% ============================================================
% plot_proposal_power_comparison.m
%
% Compare the two official power policies of the nominal
% heterogeneous-grid proposal:
%
%   boosted
%   unboosted
%
% One figure is generated for QPSK and one for 16-QAM.
%
% Zero-error runs are excluded from the measured BER curves.
% Their 95% upper-bound level is shown using a dashed
% horizontal reference line.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

modulations = {'QPSK', '16-QAM'};

powerPolicies = { ...
    'boosted', ...
    'unboosted'};

policyLabels = { ...
    'Boosted', ...
    'Unboosted'};

lineStyles = { ...
    '-o', ...
    '--s'};

for modIdx = 1:numel(modulations)

    modulation = modulations{modIdx};

    modRows = ...
        proposalPowerResults( ...
            strcmp( ...
                {proposalPowerResults.modulation}, ...
                modulation));

    if isempty(modRows)
        error('plot_proposal_power_comparison:MissingModulation', ...
            'No results found for %s.', modulation);
    end

    kValues = unique([modRows.k]);

    if numel(kValues) ~= 1
        error('plot_proposal_power_comparison:UnexpectedK', ...
            'Expected one nominal k for %s.', modulation);
    end

    nominalK = kValues(1);

    fig = figure( ...
        'Visible', 'on', ...
        'Color', 'w', ...
        'Position', [100 100 850 620]);

    ax = axes(fig);

    hold(ax, 'on');
    grid(ax, 'on');
    box(ax, 'on');

    allMeasuredValues = [];
    allZeroUpperBounds = [];

    for polIdx = 1:numel(powerPolicies)

        policy = powerPolicies{polIdx};

        mask = ...
            strcmp({proposalPowerResults.modulation}, modulation) & ...
            strcmp({proposalPowerResults.powerPolicy}, policy);

        rows = proposalPowerResults(mask);

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
            lineStyles{polIdx}, ...
            'LineWidth', 1.7, ...
            'MarkerSize', 7, ...
            'DisplayName', policyLabels{polIdx});

        allMeasuredValues = [ ...
            allMeasuredValues, ...
            berMeasured(isfinite(berMeasured))]; %#ok<AGROW>

        allZeroUpperBounds = [ ...
            allZeroUpperBounds, ...
            zeroUpperBounds(isfinite(zeroUpperBounds))]; %#ok<AGROW>
    end

    % --------------------------------------------------------
    % Zero-error reference
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
    % Axes
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
        sprintf( ...
            'Proposal power policy - %s, k=%d', ...
            modulation, nominalK));

    legend(ax, ...
        'Location', 'southwest');

    % --------------------------------------------------------
    % Export
    % --------------------------------------------------------

    if strcmp(modulation, 'QPSK')
        baseName = 'ber_power_qpsk';
    else
        baseName = 'ber_power_16qam';
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

berMeasured = NaN(1, numel(rows));
zeroUpperBounds = NaN(1, numel(rows));

for idx = 1:numel(rows)

    if rows(idx).numErrors == 0

        if ~isfinite(rows(idx).upper95) || ...
                rows(idx).upper95 <= 0
            error('plot_proposal_power_comparison:InvalidUpperBound', ...
                'Zero-error run has no valid upper95.');
        end

        zeroUpperBounds(idx) = ...
            rows(idx).upper95;

    else

        if ~isfinite(rows(idx).BER) || ...
                rows(idx).BER <= 0
            error('plot_proposal_power_comparison:InvalidBER', ...
                'Observed-error run has invalid BER.');
        end

        berMeasured(idx) = ...
            rows(idx).BER;
    end
end

end


function local_set_log_limits(ax, values)

values = values(isfinite(values) & values > 0);

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