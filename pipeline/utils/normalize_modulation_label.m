function modulation = normalize_modulation_label(modulation)
% ============================================================
% normalize_modulation_label.m
%
% Normalize supported modulation labels to the canonical
% labels used by the official pipeline:
%
%   QPSK
%   16-QAM
%
% Accepted 16-QAM aliases:
%
%   16-QAM
%   16QAM
%   QAM16
%
% TFG:       Cooperative Waveform Transmission and Design
%            for LEO Satellites
% Author:    Emma Rodriguez Hervas - UC3M
% Year:      2026
% ============================================================

% ------------------------------------------------------------
% 1. Convert input to character vector
% ------------------------------------------------------------

if isstring(modulation)

    if ~isscalar(modulation)
        error('normalize_modulation_label:InvalidInput', ...
            'Modulation must be a scalar string or character vector.');
    end

    modulation = char(modulation);

elseif ~ischar(modulation)

    error('normalize_modulation_label:InvalidInput', ...
        'Modulation must be a scalar string or character vector.');
end

% ------------------------------------------------------------
% 2. Normalize formatting
% ------------------------------------------------------------

value = upper(strtrim(modulation));
value = regexprep(value, '[\s_-]', '');

% ------------------------------------------------------------
% 3. Return canonical label
% ------------------------------------------------------------

switch value

    case 'QPSK'
        modulation = 'QPSK';

    case {'16QAM', 'QAM16'}
        modulation = '16-QAM';

    otherwise
        error('normalize_modulation_label:UnsupportedModulation', ...
            'Unsupported modulation label: %s.', modulation);
end

end