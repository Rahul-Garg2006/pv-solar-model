function [scores, breakdown] = compute_score(sites, weights)
% COMPUTE_SCORE  Layer 2 -- weighted suitability score using
% literature-anchored "deviation from ideal" formulas, a fixed LULC
% lookup table, and min-max scoring for wind speed (the one genuinely
% monotonic-with-no-ceiling parameter).
%
%   sites   : table, surviving sites only (post-knockout)
%   weights : struct, field name = parameter name, value = weight
%             (weights don't need to sum to 1 -- they get normalized)
%
%   Returns:
%   scores    : column vector of final weighted scores, 0-100, one per site
%   breakdown : table of each site's individual 0-100 score per parameter,
%               useful for checking/reporting which factors drove a
%               site's overall score

    n = height(sites);

    % --- Individual parameter scores, each clamped to [0, 100] ---

    % GHI: ceiling-anchored at 6.0 kWh/m2/day (Gujarat's best, citable as
    % India's practical ceiling). Higher is better, no penalty for
    % exceeding the ceiling (clamped at 100).
    ghiScore = clamp((sites.GHI / 6.0) * 100);

    % Slope: ideal = 0 deg (flattest), worst = 15 deg (knockout boundary)
    slopeScore = clamp(100 * (1 - sites.Slope / 15));

    % Distance to Grid: ideal = 0 km, worst = 10 km (knockout boundary)
    gridScore = clamp(100 * (1 - sites.DistGrid_km / 10));

    % Aspect: ideal = 180 deg (due south), worst = 0/360 (due north)
    aspectScore = clamp(100 * (1 - abs(sites.Aspect - 180) / 180));

    % LULC: fixed lookup table (not a deviation formula -- categories
    % aren't on a numeric scale). See lulc_suitability_score.m
    lulcScore = lulc_suitability_score(sites.LULC_code);

    % Ambient Temperature: ideal = 25 degC (STC optimal), scored on
    % deviation in either direction
    tempScore = clamp(100 * (1 - abs(sites.AmbientTemp - 25) / 25));

    % Distance to Road: ideal = 0 km, worst = 20 km (knockout boundary)
    roadScore = clamp(100 * (1 - sites.DistRoad_km / 20));

    % Water availability (distance to water body): ideal = 0 km, worst =
    % 20 km (project-defined ceiling -- no literature ceiling exists,
    % since water is routinely trucked in over long distances in India)
    waterScore = clamp(100 * (1 - sites.DistWater_km / 30));

    % Wind Speed: ceiling-anchored at 10 m/s (~36 km/h), based on
    % Ramakkalmedu, Kerala -- India's windiest location, with a
    % constant wind speed of ~35 km/h (~9.72 m/s) year-round. Higher is
    % better (cooling/cleaning effect per literature), clamped at 100
    % since no real Indian site is expected to exceed this ceiling.
    windScore = clamp((sites.WindSpeed / 10) * 100);

    % AOD: ceiling-anchored at 1.0 (NASA Earth Observatory's "very hazy"
    % classification). Lower is better.
    aodScore = clamp(100 * (1 - sites.AOD / 1.0));

    % --- Combine into weighted score ---
    paramScores = struct( ...
        'GHI', ghiScore, 'Slope', slopeScore, 'DistGrid_km', gridScore, ...
        'Aspect', aspectScore, 'LULC_code', lulcScore, ...
        'AmbientTemp', tempScore, 'DistRoad_km', roadScore, ...
        'DistWater_km', waterScore, 'WindSpeed', windScore, 'AOD', aodScore ...
    );

    paramNames = fieldnames(weights);
    normScores = zeros(n, numel(paramNames));
    w = zeros(1, numel(paramNames));

    for k = 1:numel(paramNames)
        p = paramNames{k};
        w(k) = weights.(p);
        if isfield(paramScores, p)
            s = paramScores.(p);
            s(isnan(s)) = 50; % neutral fallback for missing data
            normScores(:,k) = s;
        else
            warning('No scoring formula defined for "%s" -- using neutral 50.', p);
            normScores(:,k) = 50;
        end
    end

    w = w / sum(w); % normalize weights to sum to 1
    scores = normScores * w';

    % Build breakdown table for inspection/reporting
    breakdown = array2table(normScores, 'VariableNames', paramNames);
    breakdown.site_name = sites.site_name;
    breakdown = breakdown(:, [end, 1:end-1]); % site_name first
end

function y = clamp(x)
% Keep every value within [0, 100], handling NaN safely
    y = x;
    y(isnan(y)) = NaN; % preserve NaN, handled by caller
    y(~isnan(y) & y > 100) = 100;
    y(~isnan(y) & y < 0) = 0;
end
