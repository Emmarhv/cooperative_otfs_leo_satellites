function cfg = nominal_proposal_config_1024_16_64()
% ============================================================
% nominal_proposal_config_1024_16_64.m
%
% Official nominal configuration of the N1~=N2 cooperative
% proposal after validation of the M=16 -> M=1024 scale-up.
%
% Lcp=M-1 is the current reference-case choice. It must not be
% interpreted as a universal RCP requirement.
%
% Independent parameters:
% - M
% - N1, N2
% - deltaF
% - Lcp
% - modOrder
% - activeRows
%
% Derived parameters:
% - Ncommon
% - K1, K2
% - sampleTime
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

cfg = struct();

% ------------------------------------------------------------
% 1. Independent parameters
% ------------------------------------------------------------

cfg.M = 1024;

cfg.N1 = 16;
cfg.N2 = 64;

cfg.deltaF = 240e3;

% Reference-case RCP length.
cfg.Lcp = cfg.M - 1;

% QPSK.
cfg.modOrder = 4;

% All delay rows are active in the nominal design.
cfg.activeRows = 0:(cfg.M - 1);

% ------------------------------------------------------------
% 2. Derived parameters
% ------------------------------------------------------------

cfg.Ncommon = lcm(cfg.N1, cfg.N2);

cfg.K1 = cfg.Ncommon / cfg.N1;
cfg.K2 = cfg.Ncommon / cfg.N2;

if cfg.K1 ~= round(cfg.K1) || ...
        cfg.K2 ~= round(cfg.K2)

    error('nominal_proposal_config_1024_16_64:NonIntegerK', ...
        'K1 and K2 must be integers.');
end

% Critical-sampling OTFS time-domain sample period.
cfg.sampleTime = 1 / (cfg.M * cfg.deltaF);

end