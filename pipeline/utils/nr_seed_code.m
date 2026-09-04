function code = nr_seed_code(NR)
% ============================================================
% nr_seed_code.m
%
% Fixed, explicit per-N_R seed code used to build reproducible
% Monte Carlo seeds for the official proposal engine
% (run_proposal_point.m).
%
% IMPORTANT: codes are assigned by FIXED LOOKUP, not by sorted
% position within the current N_R grid. The four originally
% characterized receive-array sizes
%
%   NR = 64, 144, 256, 400
%
% keep the exact same codes (1, 2, 3, 4) they had when the
% N_R grid only contained those four values. This preserves
% bit-exact reproducibility of every result already validated
% at those points.
%
% NR = 100 and NR = 576 were added later to complete the final
% comparison grid of six square receive arrays
% (finalComparisonNR, see build_official_config.m) and are
% assigned new codes (5, 6) appended at the end, never inserted
% between the existing ones.
%
% If additional N_R values are added in the future, append new
% codes here in the same way. Never renumber existing codes.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

switch NR

    case 64
        code = 1;

    case 144
        code = 2;

    case 256
        code = 3;

    case 400
        code = 4;

    case 100
        code = 5;

    case 576
        code = 6;

    otherwise
        error('nr_seed_code:UnsupportedNR', ...
            ['NR=%d has no assigned seed code. Add one explicitly ' ...
             '(append, never renumber existing codes).'], NR);
end

end
