function plot_residual_sensitivity( ...
    inputFile, outputDir)
% ============================================================
% plot_residual_sensitivity.m
%
% Official reporting for the three one-dimensional sensitivity
% studies of the heterogeneous-grid proposal:
%
%   1) residual timing;
%   2) residual Doppler;
%   3) slant-range imbalance.
%
% Generates:
%
%   QPSK timing sensitivity
%   QPSK Doppler sensitivity
%   QPSK range sensitivity
%
%   16-QAM timing sensitivity
%   16-QAM Doppler sensitivity
%   16-QAM range sensitivity
%
% Horizontal axis:
%
%   10log10(N_R) [dB]
%
% Each curve corresponds to one tested residual offset.
%
% Only OBSERVED positive BER values are connected.
% Zero-error runs are excluded from the curves and represented
% only through a dashed 95% upper-bound reference line.
%
% Inputs:
%
%   inputFile
%       residual_sensitivity_results.mat
%
%   outputDir
%       Destination folder for generated figures.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate inputs
% ------------------------------------------------------------

if nargin ~= 2
    error('plot_residual_sensitivity:InvalidInputs', ...
        'inputFile and outputDir are required.');
end

if isstring(inputFile)
    inputFile = char(inputFile);
end

if isstring(outputDir)
    outputDir = char(outputDir);
end

if ~isfile(inputFile)
    error('plot_residual_sensitivity:ResultsNotFound', ...
        'Results file not found:\n%s', inputFile);
end

if ~isfolder(outputDir)
    mkdir(outputDir);
end

% ------------------------------------------------------------
% 2. Load production results
% ------------------------------------------------------------

S = load( ...
    inputFile, ...
    'results', ...
    'studyMeta');

if ~isfield(S, 'results') || isempty(S.results)
    error('plot_residual_sensitivity:EmptyResults', ...
        'The results file contains no valid results.');
end

if ~isfield(S, 'studyMeta')
    error('plot_residual_sensitivity:MissingMetadata', ...
        'The results file does not contain studyMeta.');
end

results = S.results;
studyMeta = S.studyMeta;

if isfield(studyMeta, 'expectedLogicalPoints')

    expectedPoints = ...
        studyMeta.expectedLogicalPoints;

else

    expectedPoints = 228;
end

if numel(results) ~= expectedPoints
    error('plot_residual_sensitivity:IncompleteResults', ...
        ['Expected %d logical sensitivity points, ' ...
         'but found %d.'], ...
        expectedPoints, ...
        numel(results));
end

% ------------------------------------------------------------
% 3. Receiver-array grid
% ------------------------------------------------------------

if isfield(studyMeta, 'finalComparisonNR')

    NRList = ...
        studyMeta.finalComparisonNR;

else

    NRList = ...
        [64 100 144 256 400 576];
end

expectedNR = ...
    [64 100 144 256 400 576];

if ~isequal(NRList, expectedNR)
    error('plot_residual_sensitivity:UnexpectedNRGrid', ...
        'Unexpected N_R grid: %s.', ...
        mat2str(NRList));
end

NRdB = ...
    10 * log10(NRList);

% ------------------------------------------------------------
% 4. Study definitions
% ------------------------------------------------------------

modulations = ...
    {'QPSK', '16-QAM'};

sweeps = struct( ...
    'type', {}, ...
    'values', {}, ...
    'nominalValue', {}, ...
    'titleText', {}, ...
    'fileTag', {});

% Residual timing.
sweeps(1).type = 'delta';

if isfield(studyMeta, 'deltaSweepValues')
    sweeps(1).values = ...
        studyMeta.deltaSweepValues;
else
    sweeps(1).values = ...
        [-3069 -1023 -504 0 504 1023 3069];
end

if isfield(studyMeta, 'nominalDelta')
    sweeps(1).nominalValue = ...
        studyMeta.nominalDelta;
else
    sweeps(1).nominalValue = 504;
end

sweeps(1).titleText = ...
    'Residual timing sensitivity';

sweeps(1).fileTag = ...
    'timing';

% Residual Doppler.
sweeps(2).type = 'nu';

if isfield(studyMeta, 'nuSweepValues')
    sweeps(2).values = ...
        studyMeta.nuSweepValues;
else
    sweeps(2).values = ...
        [-26460 -13230 -6615 0 6615 13230 26460];
end

if isfield(studyMeta, 'nominalNuRelHz')
    sweeps(2).nominalValue = ...
        studyMeta.nominalNuRelHz;
else
    sweeps(2).nominalValue = ...
        -13.23e3;
end

sweeps(2).titleText = ...
    'Residual Doppler sensitivity';

sweeps(2).fileTag = ...
    'doppler';

% Slant-range imbalance.
sweeps(3).type = 'range';

if isfield(studyMeta, 'rangeSweepDeltaKm')
    sweeps(3).values = ...
        studyMeta.rangeSweepDeltaKm;
else
    sweeps(3).values = ...
        [0 35 69.89 105 140];
end

if isfield(studyMeta, 'nominalRangeSat1') && ...
        isfield(studyMeta, 'nominalRangeSat2')

    sweeps(3).nominalValue = ...
        (studyMeta.nominalRangeSat2 - ...
         studyMeta.nominalRangeSat1) / 1e3;

else

    sweeps(3).nominalValue = ...
        69.89;
end

sweeps(3).titleText = ...
    'Slant-range imbalance sensitivity';

sweeps(3).fileTag = ...
    'range';

% ------------------------------------------------------------
% 5. Generate figures
% ------------------------------------------------------------

for modIdx = 1:numel(modulations)

    modulation = ...
        modulations{modIdx};

    for sweepIdx = 1:numel(sweeps)

        sweep = ...
            sweeps(sweepIdx);

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

        % ----------------------------------------------------
        % One curve for each tested offset
        % ----------------------------------------------------

        for valueIdx = 1:numel(sweep.values)

            sweepValue = ...
                sweep.values(valueIdx);

            berMeasured = ...
                NaN(1, numel(NRList));

            zeroUpperBounds = ...
                NaN(1, numel(NRList));

            for nrIdx = 1:numel(NRList)

                NR = ...
                    NRList(nrIdx);

                row = local_get_row( ...
                    results, ...
                    modulation, ...
                    sweep.type, ...
                    sweepValue, ...
                    NR);

                [berValue, numErrors, numBits] = ...
                    local_get_ber_fields(row);

                % --------------------------------------------
                % Stored BER consistency
                % --------------------------------------------

                if abs( ...
                        berValue - ...
                        numErrors / numBits) > 1e-12

                    error( ...
                        'plot_residual_sensitivity:BERMismatch', ...
                        ['Stored BER does not match ' ...
                         'numErrors/numBits.']);
                end

                % --------------------------------------------
                % Measured BER / zero-error treatment
                % --------------------------------------------

                if numErrors == 0

                    zeroUpperBounds(nrIdx) = ...
                        local_get_upper_bound(row);

                else

                    berMeasured(nrIdx) = ...
                        berValue;
                end
            end

            curveLabel = ...
                local_curve_label( ...
                    sweep.type, ...
                    sweepValue, ...
                    sweep.nominalValue);

            semilogy( ...
                ax, ...
                NRdB, ...
                berMeasured, ...
                '-o', ...
                'LineWidth', 1.5, ...
                'MarkerSize', 6, ...
                'DisplayName', ...
                curveLabel);

            allMeasuredValues = [ ...
                allMeasuredValues, ...
                berMeasured(isfinite(berMeasured))]; %#ok<AGROW>

            allZeroUpperBounds = [ ...
                allZeroUpperBounds, ...
                zeroUpperBounds( ...
                    isfinite(zeroUpperBounds))]; %#ok<AGROW>
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
                'FontSize', 16, ...
                'LabelHorizontalAlignment', 'right', ...
                'LabelVerticalAlignment', 'top', ...
                'HandleVisibility', 'off');
        end

        % ----------------------------------------------------
        % Logarithmic BER axis
        % ----------------------------------------------------

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

        local_set_log_limits( ...
            ax, ...
            valuesForLimits);

        % ----------------------------------------------------
        % Axes
        % ----------------------------------------------------

        xlabel( ...
            ax, ...
            'Receiver array size, 10log_{10}(N_R) [dB]');

        ylabel( ...
            ax, ...
            'Uncoded combined BER');

        title( ...
            ax, ...
            sprintf( ...
                'Proposal %s - %s', ...
                lower(sweep.titleText), ...
                modulation));

        legend( ...
            ax, ...
            'Location', ...
            'southwest');

        % ----------------------------------------------------
        % Export
        % ----------------------------------------------------

        if strcmp( ...
                local_normalize_modulation(modulation), ...
                'QPSK')

            modName = ...
                'qpsk';

        else

            modName = ...
                '16qam';
        end

        baseName = sprintf( ...
            'ber_sensitivity_%s_%s', ...
            sweep.fileTag, ...
            modName);

        save_official_figure( ...
            fig, ...
            outputDir, ...
            baseName);

        % Figure intentionally remains open in MATLAB.
    end
end

end


% ============================================================
% Local helpers
% ============================================================

function row = local_get_row( ...
    results, modulation, sweepType, sweepValue, NR)

mask = false(size(results));

requestedModulation = ...
    local_normalize_modulation(modulation);

valueTolerance = ...
    1e-10 * max(1, abs(sweepValue));

for idx = 1:numel(results)

    storedModulation = ...
        local_normalize_modulation( ...
            results(idx).modulation);

    sameModulation = ...
        strcmp( ...
            storedModulation, ...
            requestedModulation);

    sameSweep = ...
        strcmp( ...
            results(idx).sweepType, ...
            sweepType);

    sameValue = ...
        abs( ...
            results(idx).sweepValue - ...
            sweepValue) <= valueTolerance;

    sameNR = ...
        results(idx).NR == NR;

    mask(idx) = ...
        sameModulation && ...
        sameSweep && ...
        sameValue && ...
        sameNR;
end

if nnz(mask) ~= 1
    error('plot_residual_sensitivity:JoinMismatch', ...
        ['Expected exactly one result for %s, %s=%g, ' ...
         'N_R=%d; found %d.'], ...
        modulation, ...
        sweepType, ...
        sweepValue, ...
        NR, ...
        nnz(mask));
end

row = ...
    results(mask);

end


function [berValue, numErrors, numBits] = ...
    local_get_ber_fields(row)

if isfield(row, 'BER')

    berValue = ...
        row.BER;

elseif isfield(row, 'BERcomb')

    berValue = ...
        row.BERcomb;

else

    error('plot_residual_sensitivity:MissingBER', ...
        'Result entry does not contain BER.');
end

if isfield(row, 'numErrors')

    numErrors = ...
        row.numErrors;

elseif isfield(row, 'Ecomb')

    numErrors = ...
        row.Ecomb;

else

    error('plot_residual_sensitivity:MissingErrors', ...
        'Result entry does not contain an error count.');
end

if isfield(row, 'numBits')

    numBits = ...
        row.numBits;

elseif isfield(row, 'Nbits')

    numBits = ...
        row.Nbits;

else

    error('plot_residual_sensitivity:MissingBits', ...
        'Result entry does not contain a bit count.');
end

if ~isfinite(numBits) || numBits <= 0
    error('plot_residual_sensitivity:InvalidBits', ...
        'Number of evaluated bits must be positive.');
end

end


function upperBound = ...
    local_get_upper_bound(row)

if isfield(row, 'upper95BERcomb') && ...
        isfinite(row.upper95BERcomb) && ...
        row.upper95BERcomb > 0

    upperBound = ...
        row.upper95BERcomb;

    return;
end

[~, ~, numBits] = ...
    local_get_ber_fields(row);

upperBound = ...
    1 - 0.05^(1 / numBits);

end


function label = local_curve_label( ...
    sweepType, sweepValue, nominalValue)

switch sweepType

    case 'delta'

        label = sprintf( ...
            '\\delta = %g samples', ...
            sweepValue);

    case 'nu'

        label = sprintf( ...
            '\\nu_{rel} = %.2f kHz', ...
            sweepValue / 1e3);

    case 'range'

        label = sprintf( ...
            '\\Delta r = %g km', ...
            sweepValue);

    otherwise

        error('plot_residual_sensitivity:UnknownSweep', ...
            'Unknown sweep type: %s.', ...
            sweepType);
end

tolerance = ...
    1e-10 * max(1, abs(nominalValue));

if abs(sweepValue - nominalValue) <= tolerance

    label = ...
        [label ' (nominal)'];
end

end


function local_set_log_limits( ...
    ax, values)

values = ...
    values( ...
        isfinite(values) & ...
        values > 0);

if isempty(values)
    error('plot_residual_sensitivity:NoPositiveValues', ...
        ['No positive BER values or upper bounds are ' ...
         'available for the logarithmic axis.']);
end

yMin = ...
    10 ^ floor( ...
        log10(min(values)));

yMax = ...
    10 ^ ceil( ...
        log10(max(values) * 1.2));

yMax = ...
    min(1, yMax);

if yMax <= yMin

    yMax = ...
        min(1, 10 * yMin);
end

ylim( ...
    ax, ...
    [yMin yMax]);

end


function normalized = ...
    local_normalize_modulation(value)

value = ...
    upper(regexprep( ...
        char(value), ...
        '[^A-Z0-9]', ...
        ''));

if strcmp(value, 'QPSK')

    normalized = ...
        'QPSK';

elseif strcmp(value, '16QAM') || ...
        strcmp(value, 'QAM16')

    normalized = ...
        '16QAM';

else

    error('plot_residual_sensitivity:UnknownModulation', ...
        'Unknown modulation label: %s.', ...
        value);
end

end