function code = candidate_seed_code(modulation, k)
% ============================================================
% candidate_seed_code.m
%
% Stable per-candidate seed code used to build reproducible
% Monte Carlo seeds for the N1~=N2 cooperative proposal.
%
% This is a direct, intentional mirror of the
% local_candidate_seed_code() local function defined inside
% the frozen/validated engine
% (historical) load_tradeoff/experiments/run_load_tradeoff_ber.m.
%
% It is duplicated here (not extracted into a shared file)
% because that engine is a closed, already-validated script and
% is not modified as part of building the official/ pipeline.
% Both copies are cross-checked against each other in
% official/validation/
%
% If this mapping is ever changed, it must be changed
% identically in both places or Monte Carlo results will stop
% being reproducible across the two engines.
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

if strcmp(modulation, 'QPSK')

    if k == 7
        code = 1;

    elseif k == 8
        code = 2;

    elseif k >= 9 && k <= 16
        code = 7 + (k - 8);

    else
        error('candidate_seed_code:InvalidQpskK', ...
            'Unsupported QPSK load k=%d.', k);
    end

    return;
end

if strcmp(modulation, '16-QAM')

    if k >= 4 && k <= 8
        code = k - 1;

    elseif k >= 9 && k <= 16
        code = 15 + (k - 8);

    else
        error('candidate_seed_code:InvalidQamK', ...
            'Unsupported 16-QAM load k=%d.', k);
    end

    return;
end

error('candidate_seed_code:UnknownModulation', ...
    'Unknown modulation "%s".', modulation);

end
