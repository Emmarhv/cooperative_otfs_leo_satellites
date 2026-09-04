function plot_load_ber_by_k( ...
    boostedResults, unboostedResults, outputDir)
% ============================================================
% plot_load_ber_by_k.m
%
% Official BER load-tradeoff reporting.
%
% Generates:
%
%   QPSK boosted
%   QPSK unboosted
%   16-QAM boosted
%   16-QAM unboosted
%
% Each curve corresponds to one tested load k.
%
% Only OBSERVED positive BER values are connected.
% Zero-error runs are excluded from the curve and represented
% only through a dashed 95% upper-bound reference line.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

modulations = {'QPSK', '16-QAM'};
powerPolicies = {'boosted', 'unboosted'};

officialNR = [64 144 256 400];

for modIdx = 1:numel(modulations)

    modulation = modulations{modIdx};

    if strcmp(modulation, 'QPSK')
        kList = [7 8 9 10];
    else
        kList = [4 5 6 7 8];
    end

    for polIdx = 1:numel(powerPolicies)

        powerPolicy = powerPolicies{polIdx};

        if strcmp(powerPolicy, 'boosted')
            results = boostedResults;
        else
            results = unboostedResults;
        end

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

        NRdB = ...
            10 * log10(officialNR);

        for kIdx = 1:numel(kList)

            k = kList(kIdx);

            berMeasured = ...
                NaN(1, numel(officialNR));

            zeroUpperBounds = ...
                NaN(1, numel(officialNR));

            for nrIdx = 1:numel(officialNR)

                NR = officialNR(nrIdx);

                row = local_get_row( ...
                    results, modulation, k, NR);

                if abs(row.BERcomb - ...
                        row.Ecomb / row.Nbits) > 1e-12
                    error('plot_load_ber_by_k:BERMismatch', ...
                        'Stored BER does not match Ecomb/Nbits.');
                end

                if row.Ecomb == 0

                    zeroUpperBounds(nrIdx) = ...
                        local_get_upper_bound(row);

                else

                    berMeasured(nrIdx) = ...
                        row.BERcomb;
                end
            end

            semilogy( ...
                ax, ...
                NRdB, ...
                berMeasured, ...
                '-o', ...
                'LineWidth', 1.5, ...
                'MarkerSize', 6, ...
                'DisplayName', ...
                sprintf('\\lambda = %d', k));

            allMeasuredValues = [ ...
                allMeasuredValues, ...
                berMeasured(isfinite(berMeasured))]; %#ok<AGROW>

            allZeroUpperBounds = [ ...
                allZeroUpperBounds, ...
                zeroUpperBounds(isfinite(zeroUpperBounds))]; %#ok<AGROW>
        end

        % ----------------------------------------------------
        % Zero-error upper-bound reference
        % ----------------------------------------------------

        if ~isempty(allZeroUpperBounds)

            zeroBoundLevel = ...
                max(allZeroUpperBounds);

            yline( ...
                ax, ...
                zeroBoundLevel, ...
                '--', ...
                'Zero-error 95% upper bound', ...
                'LineWidth', 1.2, ...
                'FontSize', 20, ...
                'LabelHorizontalAlignment', 'right', ...
                'LabelVerticalAlignment', 'top', ...
                'HandleVisibility', 'off');
        end

        % ----------------------------------------------------
        % Logarithmic BER axis
        % ----------------------------------------------------

        ax.YScale = 'log';
        ax.YMinorGrid = 'on';
        ax.FontSize = 24;

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
                'Proposal load trade-off - %s, %s', ...
                modulation, powerPolicy));

        legend(ax, ...
            'Location', 'southwest', ...
            'FontSize', 20);

        % ----------------------------------------------------
        % Export
        % ----------------------------------------------------

        if strcmp(modulation, 'QPSK')
            modName = 'qpsk';
        else
            modName = '16qam';
        end

        baseName = sprintf( ...
            'ber_load_%s_%s', ...
            modName, powerPolicy);

        save_official_figure( ...
            fig, outputDir, baseName);

        % Figure intentionally remains open in MATLAB.
    end
end

end


% ============================================================
% Local helpers
% ============================================================

function row = local_get_row( ...
    results, modulation, k, NR)

modMask = ...
    local_modulation_mask( ...
        results, modulation);

mask = ...
    modMask & ...
    [results.k] == k & ...
    [results.NR] == NR;

if nnz(mask) ~= 1
    error('plot_load_ber_by_k:JoinMismatch', ...
        ['Expected exactly one result for ' ...
         '%s k=%d N_R=%d, found %d.'], ...
        modulation, k, NR, nnz(mask));
end

row = results(mask);

end


function upperBound = local_get_upper_bound(row)

if isfield(row, 'upper95BERcomb') && ...
        isfinite(row.upper95BERcomb) && ...
        row.upper95BERcomb > 0

    upperBound = ...
        row.upper95BERcomb;

else

    upperBound = ...
        1 - 0.05^(1 / row.Nbits);
end

end


function local_set_log_limits(ax, values)

values = values(isfinite(values) & values > 0);

if isempty(values)
    error('plot_load_ber_by_k:NoPositiveValues', ...
        'No positive values available for logarithmic axis.');
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


function mask = local_modulation_mask(results, requested)

mask = false(size(results));

requested = ...
    local_normalize_modulation(requested);

for idx = 1:numel(results)

    stored = ...
        local_normalize_modulation( ...
            results(idx).modulation);

    mask(idx) = ...
        strcmp(stored, requested);
end

end


function normalized = local_normalize_modulation(value)

value = ...
    upper(regexprep( ...
        char(value), ...
        '[^A-Z0-9]', ...
        ''));

if strcmp(value, 'QPSK')

    normalized = 'QPSK';

elseif strcmp(value, '16QAM') || ...
        strcmp(value, 'QAM16')

    normalized = '16QAM';

else

    error('plot_load_ber_by_k:UnknownModulation', ...
        'Unknown modulation label: %s.', value);
end

end