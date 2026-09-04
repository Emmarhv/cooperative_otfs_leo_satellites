function berUpper = compute_zero_error_upper_bound(numBits, confidenceLevel)
% ============================================================
% compute_zero_error_upper_bound.m
%
% One-sided upper confidence bound on a bit error rate when
% ZERO errors were observed in numBits independent bit
% decisions. Exact Clopper-Pearson bound for zero successes:
%
%   berUpper = 1 - (1-confidenceLevel)^(1/numBits)
%
% This is NOT an estimate of BER (which is undefined/0 with no
% observed errors) -- it is the largest true BER that would
% still have a (1-confidenceLevel) probability or higher of
% producing zero observed errors in numBits trials. Standard
% practice for reporting "no errors observed" Monte Carlo points
% without claiming BER=0.
%
% Inputs:
% - numBits         : number of independent bit trials with
%                     zero observed errors (positive integer)
% - confidenceLevel  : e.g. 0.95 for a 95% upper bound
%
% Output:
% - berUpper : upper confidence bound on BER (linear scale)
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

if ~isscalar(numBits) || ~isreal(numBits) || numBits <= 0 || numBits ~= round(numBits)
    error('compute_zero_error_upper_bound:InvalidNumBits', ...
        'numBits must be a positive integer scalar.');
end

if ~isscalar(confidenceLevel) || ~isreal(confidenceLevel) || ...
        confidenceLevel <= 0 || confidenceLevel >= 1
    error('compute_zero_error_upper_bound:InvalidConfidence', ...
        'confidenceLevel must be a real scalar in (0,1).');
end

alpha = 1 - confidenceLevel;
berUpper = 1 - alpha^(1/numBits);

end