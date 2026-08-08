function score = lulc_suitability_score(lulcCodes)
% LULC_SUITABILITY_SCORE  Fixed lookup table mapping ESA WorldCover land
%   cover codes to a 0-100 solar PV suitability score.
%
%   lulcCodes : column vector of ESA WorldCover class codes
%
%   Returns a column vector of suitability scores, same size as input.
%   Unrecognized or missing codes return NaN (handled as neutral 50 by
%   the caller).
%
%   Rationale: bare/sparse vegetation (wasteland) is most preferred,
%   consistent with India's policy emphasis on using wasteland for solar
%   siting and general GIS-MCDA siting literature. Forest, water,
%   wetland, mangrove, and built-up are knockout categories (score 0
%   here too, for consistency, though they should already be filtered
%   out by the knockout layer before reaching this function).

    lookup = containers.Map('KeyType', 'double', 'ValueType', 'double');
    lookup(10)  = 0;   % Tree cover -- knockout category
    lookup(20)  = 60;  % Shrubland
    lookup(30)  = 70;  % Grassland
    lookup(40)  = 30;  % Cropland -- land-use conflict with agriculture
    lookup(50)  = 0;   % Built-up -- knockout category
    lookup(60)  = 100; % Bare / sparse vegetation -- ideal
    lookup(70)  = 0;   % Snow and ice -- not buildable
    lookup(80)  = 0;   % Permanent water bodies -- knockout category
    lookup(90)  = 0;   % Herbaceous wetland -- knockout category
    lookup(95)  = 0;   % Mangroves -- knockout category
    lookup(100) = 50;  % Moss and lichen -- rare in India, treated as neutral

    n = numel(lulcCodes);
    score = nan(n,1);
    for i = 1:n
        c = lulcCodes(i);
        if ~isnan(c) && isKey(lookup, double(c))
            score(i) = lookup(double(c));
        end
    end
end
