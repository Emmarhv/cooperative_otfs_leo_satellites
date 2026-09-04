function code = baseline_modulation_seed_code(modulation)
% ============================================================
% baseline_modulation_seed_code.m
%
% Fixed per-modulation seed code used to build reproducible
% deterministic seeds for the official baseline engine
% (run_baseline_point.m). Analogous in spirit to
% candidate_seed_code.m/nr_seed_code.m for the proposal, but
% trivial since the baseline has no heterogeneous-grid load
% parameter k.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

switch modulation

    case 'QPSK'
        code = 1;

    case '16-QAM'
        code = 2;

    otherwise
        error('baseline_modulation_seed_code:UnknownModulation', ...
            'Unknown modulation "%s".', modulation);
end

end
