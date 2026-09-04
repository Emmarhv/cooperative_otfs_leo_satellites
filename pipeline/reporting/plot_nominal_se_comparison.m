function plot_nominal_se_comparison(mainResults, outputDir)
% ============================================================
% plot_nominal_se_comparison.m
%
% Compare the nominal payload spectral efficiency of the four
% main system configurations.
%
% The metric is payload bits / physical transmission time /
% bandwidth. It is therefore a NOMINAL payload SE and does
% not include BER or packet-success effects.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

scenarioNames = { ...
    'single_satellite', ...
    'baseline_compensated', ...
    'no_compensation', ...
    'proposal'};

scenarioLabels = { ...
    'Single satellite', ...
    'Baseline compensated', ...
    'No TX compensation', ...
    'Proposed N_1 ~= N_2'};

modulations = {'QPSK', '16-QAM'};

seMatrix = zeros( ...
    numel(scenarioNames), ...
    numel(modulations));

% ------------------------------------------------------------
% Extract one constant SE value per scenario/modulation
% ------------------------------------------------------------

for scenarioIdx = 1:numel(scenarioNames)

    for modIdx = 1:numel(modulations)

        mask = ...
            strcmp( ...
                {mainResults.scenario}, ...
                scenarioNames{scenarioIdx}) & ...
            strcmp( ...
                {mainResults.modulation}, ...
                modulations{modIdx});

        rows = mainResults(mask);

        if isempty(rows)
            error('plot_nominal_se_comparison:MissingResults', ...
                'Missing %s / %s results.', ...
                scenarioNames{scenarioIdx}, ...
                modulations{modIdx});
        end

        seValues = ...
            [rows.payloadSE];

        if max(seValues) - min(seValues) > 1e-12
            error('plot_nominal_se_comparison:SEDependsOnNR', ...
                ['Nominal payload SE unexpectedly changes ' ...
                 'with N_R for %s / %s.'], ...
                scenarioNames{scenarioIdx}, ...
                modulations{modIdx});
        end

        seMatrix(scenarioIdx, modIdx) = ...
            seValues(1);
    end
end

% ------------------------------------------------------------
% Plot
% ------------------------------------------------------------

fig = figure( ...
    'Visible', 'on', ...
    'Color', 'w', ...
    'Position', [100 100 950 620]);

ax = axes(fig);

bar(ax, seMatrix, 'grouped');

grid(ax, 'on');
box(ax, 'on');

ax.XTick = 1:numel(scenarioLabels);
ax.XTickLabel = scenarioLabels;
ax.XTickLabelRotation = 12;
ax.FontSize = 18;

ylabel(ax, ...
    'Nominal payload spectral efficiency [bit/s/Hz]');

title(ax, ...
    'Nominal payload spectral efficiency');

legend(ax, ...
    modulations, ...
    'Location', 'northwest');

save_official_figure( ...
    fig, outputDir, 'payload_se_main');


end