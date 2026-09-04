function cfg = supertrama_grid_config(M, N1, N2, modOrder, cpLength)
% ============================================================
% supertrama_grid_config.m
%
% Build a common analysis interval for two OTFS frame sequences
% with different Doppler dimensions N1 and N2.
%
% Each satellite keeps its own OTFS grid:
%
%   Satellite 1: M x N1
%   Satellite 2: M x N2
%
% Doppler-domain bookkeeping (Ncommon, K1, K2) is independent of
% cpLength: it only counts how many complete frames of each
% satellite fit inside the smallest common interval, in terms of
% Doppler-grid blocks, not physical sample length.
%
%   Ncommon = lcm(N1, N2)
%
%   K1 = Ncommon / N1
%   K2 = Ncommon / N2
%
% cfg.frameLength1/2 and cfg.totalLength are USEFUL-sample
% quantities (cpLength ignored by construction, cfg.frameLength1
% = M*N1) so that:
%
%   K1*M*N1 = K2*M*N2 = M*Ncommon
%
% They remain valid regardless of cpLength and are used by the
% cpLength=0 structural laboratory (Exp16-29).
%
% Ncommon is only an analysis/bookkeeping quantity. It is NOT
% a third OTFS grid and it is NOT a physical transmitted
% superframe. Each satellite still transmits its own sequence
% of independent OTFS frames.
%
% When cpLength > 0, each OTFS frame carries its own reduced
% cyclic prefix (RCP), one per frame (architecture decision,
% Raviteja et al., see also config/simulation_parameters.m,
% referenceCpLength convention). Because Sat1 groups K1 short
% frames per common block and Sat2 groups K2 long frames per
% common block, and each frame pays its own RCP cost, the two
% satellites' physical block lengths over one common-window
% repetition are in general DIFFERENT once cpLength > 0:
%
%   blockLengthSat1 = K1*(M*N1+cpLength)
%   blockLengthSat2 = K2*(M*N2+cpLength)
%
% These are reported in cfg.physical below and are NOT equal
% unless cpLength = 0. This physical mismatch (and the resulting
% drift between the two streams' block boundaries across
% repetitions) is a real architectural consequence of RCP, not
% a bug — see cfg.physical.driftPerBlock.
%
% Inputs:
% - M         : common delay dimension
% - N1        : Doppler dimension of satellite 1
% - N2        : Doppler dimension of satellite 2
% - modOrder  : QAM modulation order
% - cpLength  : reduced CP length per frame, >= 0. Use 0 for the
%               cpLength=0 structural laboratory (Exp16-29).
%               Use cpLength > 0 for the real RCP physical
%               architecture (Phase 7, RCP block).
%
% Output:
% - cfg : common analysis configuration
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate grid dimensions
% ------------------------------------------------------------

if ~isscalar(M) || M <= 0 || M ~= round(M)
    error('supertrama_grid_config:InvalidM', ...
        'M must be a positive integer scalar.');
end

if ~isscalar(N1) || N1 <= 0 || N1 ~= round(N1) || ...
        ~isscalar(N2) || N2 <= 0 || N2 ~= round(N2)
    error('supertrama_grid_config:InvalidN', ...
        'N1 and N2 must be positive integer scalars.');
end

% ------------------------------------------------------------
% 2. Validate modulation
% ------------------------------------------------------------

if ~isscalar(modOrder) || modOrder < 2 || ...
        modOrder ~= round(modOrder) || ...
        mod(log2(modOrder), 1) ~= 0
    error('supertrama_grid_config:InvalidModOrder', ...
        'modOrder must be an integer power of two.');
end

% ------------------------------------------------------------
% 3. Validate cyclic prefix
% ------------------------------------------------------------

if ~isscalar(cpLength) || cpLength < 0 || ...
        cpLength ~= round(cpLength)
    error('supertrama_grid_config:InvalidCpLength', ...
        'cpLength must be a non-negative integer scalar.');
end

% NOTE: cpLength = 0 is the cpLength=0 structural laboratory
% (Exp16-29). cpLength > 0 is the real per-frame RCP physical
% architecture (Phase 7, RCP block). Both are supported: the
% Doppler-domain bookkeeping below (Ncommon, K1, K2) does not
% depend on cpLength, and cfg.physical reports the RCP-aware
% physical block lengths separately.

% ------------------------------------------------------------
% 4. Common analysis interval (Doppler-domain bookkeeping)
% ------------------------------------------------------------

cfg.M = M;
cfg.N1 = N1;
cfg.N2 = N2;

% Smallest Doppler-domain span containing complete frames
% from both grid sequences.
cfg.Ncommon = lcm(N1, N2);

% Number of complete frames inside the common interval.
cfg.K1 = cfg.Ncommon / N1;
cfg.K2 = cfg.Ncommon / N2;

cfg.modOrder = modOrder;
cfg.bitsPerSymbol = log2(modOrder);
cfg.cpLength = cpLength;

% Useful (CP-free) time-domain samples in one OTFS frame.
% Independent of cpLength by construction.
cfg.frameLength1 = M * N1;
cfg.frameLength2 = M * N2;

% Useful (CP-free) samples in the common analysis interval.
cfg.totalLength = M * cfg.Ncommon;

% ------------------------------------------------------------
% 5. Internal consistency (useful-sample bookkeeping)
% ------------------------------------------------------------

assert(cfg.K1 * cfg.frameLength1 == cfg.totalLength, ...
    'supertrama_grid_config:LengthMismatch1', ...
    'Satellite 1 does not span the common analysis interval.');

assert(cfg.K2 * cfg.frameLength2 == cfg.totalLength, ...
    'supertrama_grid_config:LengthMismatch2', ...
    'Satellite 2 does not span the common analysis interval.');

% ------------------------------------------------------------
% 6. Physical RCP-aware block lengths
% ------------------------------------------------------------
%
% One physical OTFS frame with a reduced cyclic prefix has
% length M*N+cpLength (RCP prepended per frame, matching
% otfs_modulate.m / otfs_demodulate.m). The "block" below is
% one repetition of the common analysis interval, i.e. K1
% consecutive Sat1 frames vs K2 consecutive Sat2 frames.

cfg.physical = struct();

cfg.physical.Lcp = cpLength;

cfg.physical.frameLengthRcp1 = M * N1 + cpLength;
cfg.physical.frameLengthRcp2 = M * N2 + cpLength;

cfg.physical.blockLengthSat1 = cfg.K1 * cfg.physical.frameLengthRcp1;
cfg.physical.blockLengthSat2 = cfg.K2 * cfg.physical.frameLengthRcp2;

% For N1 ~= N2 and cpLength > 0, the physical block lengths
% are generally different because each satellite carries a
% different number of RCPs over the common Doppler interval. Nonzero for 
% cpLength > 0:% Difference between the physical durations associated with
% one common Doppler-domain bookkeeping interval.
%
% Across repeated streams, this produces a relative displacement
% between the corresponding logical block boundaries. It is not
% automatically equivalent to the static synchronization offset
% deltaSync used in the timing experiments and
% must be tracked explicitly across repeated blocks (it is NOT
% a static synchronization offset like deltaSync).

cfg.physical.driftPerBlock = ...
    cfg.physical.blockLengthSat1 - cfg.physical.blockLengthSat2;

end