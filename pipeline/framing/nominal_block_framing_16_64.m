function physical = nominal_block_framing_16_64(cfg)
% ============================================================
% nominal_block_framing_16_64.m
%
% Physical block-length bookkeeping for the nominal cooperative
% framing.
%
% Option A uses a periodic cooperative block:
% - Sat1 transmits K1 short OTFS frames, each with one RCP.
% - Sat2 transmits K2 long OTFS frames, each with one RCP.
% - If the Sat2 active waveform is shorter, the remaining
%   samples are filled with zeros so both branches have the same
%   cooperative block duration.
%
% This function calls the existing supertrama_grid_config.m and
% converts the resulting block-length difference into the
% explicit Sat2 guard used by the nominal Option A architecture.
%
% It does not synthesize or demodulate waveforms. T1/T2/R1/R2
% remain responsible for waveform generation and processing.
%
% Input:
% - cfg : struct from nominal_proposal_config_16_64.m
%
% Output:
% - physical : framing information returned by
%              supertrama_grid_config.m, plus:
%              guardLength = driftPerBlock
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate configuration
% ------------------------------------------------------------

requiredFields = {'M', 'N1', 'N2', 'Lcp', 'modOrder'};

for i = 1:numel(requiredFields)
    if ~isfield(cfg, requiredFields{i})
        error('nominal_block_framing_16_64:MissingConfigField', ...
            'cfg is missing field "%s".', requiredFields{i});
    end
end

% ------------------------------------------------------------
% 2. Compute physical block lengths
% ------------------------------------------------------------

gridCfg = supertrama_grid_config( ...
    cfg.M, cfg.N1, cfg.N2, cfg.modOrder, cfg.Lcp);

physical = gridCfg.physical;

% ------------------------------------------------------------
% 3. Option A guard
% ------------------------------------------------------------
%
% supertrama_grid_config reports the nominal block-length
% difference as driftPerBlock. In Option A, Sat2 remains silent
% for exactly this number of samples so that both cooperative
% blocks have equal duration.

if physical.driftPerBlock < 0
    error('nominal_block_framing_16_64:NegativeGuard', ...
        ['Option A expects the Sat2 active block not to exceed ' ...
         'the Sat1 cooperative block.']);
end

physical.guardLength = physical.driftPerBlock;

end