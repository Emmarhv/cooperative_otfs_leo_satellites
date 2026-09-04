function result = linear_shift_combine(s1Stream, s2Stream, delta)
% ============================================================
% linear_shift_combine.m
%
% Applies a linear timing offset to Sat2 and combines both
% time-domain streams:
%
%   y[n] = s1[n] + s2[n - delta]
%
% Convention:
%   delta > 0  -> Sat2 arrives later than Sat1.
%   delta < 0  -> Sat2 arrives earlier than Sat1.
%
% Only samples supported by both generated input streams are
% considered valid. No circular wrap-around is used.
%
% Samples outside validRange are marked as NaN and must not
% be processed. The caller must verify that every requested
% receiver window lies completely inside validRange.
%
% Inputs:
% - s1Stream : Sat1 time-domain stream
% - s2Stream : Sat2 time-domain stream
% - delta    : integer timing offset [samples]
%
% Output:
% - result.y          : combined time-domain stream
% - result.validRange : [firstValidSample, lastValidSample]
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Validate inputs.
% ------------------------------------------------------------

s1Stream = s1Stream(:);
s2Stream = s2Stream(:);

if isempty(s1Stream) || isempty(s2Stream)
    error('linear_shift_combine:EmptyStream', ...
        'Input streams must not be empty.');
end

if numel(s1Stream) ~= numel(s2Stream)
    error('linear_shift_combine:LengthMismatch', ...
        's1Stream and s2Stream must have the same length.');
end

if ~isnumeric(delta) || ~isreal(delta) || ~isscalar(delta) || ...
        ~isfinite(delta) || delta ~= fix(delta)
    error('linear_shift_combine:InvalidDelta', ...
        'delta must be a finite integer number of samples.');
end

delta = double(delta);
L = numel(s1Stream);

% ------------------------------------------------------------
% 2. Determine the valid overlap after shifting Sat2.
% ------------------------------------------------------------

% y[n] requires both:
%   1 <= n         <= L
%   1 <= n-delta   <= L
nStart = max(1, 1 + delta);
nEnd   = min(L, L + delta);

if nEnd < nStart
    error('linear_shift_combine:NoOverlap', ...
        'delta=%d leaves no valid overlap for streams of length %d.', ...
        delta, L);
end

% ------------------------------------------------------------
% 3. Apply the linear shift and combine.
% ------------------------------------------------------------

validIdx = (nStart:nEnd).';
s2Idx = validIdx - delta;

% NaN outside validRange makes accidental use of samples
% without generated runway immediately visible.
y = complex(nan(L, 1), nan(L, 1));

y(validIdx) = s1Stream(validIdx) + s2Stream(s2Idx);

% ------------------------------------------------------------
% 4. Return output and valid range.
% ------------------------------------------------------------

result = struct();
result.y = y;
result.validRange = [nStart, nEnd];

end