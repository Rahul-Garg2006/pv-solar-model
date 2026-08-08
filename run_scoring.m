%% run_scoring.m
% LAYER 2 -- SCORING. Run this AFTER run_knockout.m has produced
% sites_after_knockout.csv. This script scores and ranks the surviving
% sites using your weighted, literature-anchored formulas.
%
% Run it by typing:  run_scoring

clear; clc;

fprintf('=== SCORING LAYER ===\n\n');

%% Load surviving sites
sites = readtable('sites_after_knockout.csv');
n = height(sites);
fprintf('Loaded %d surviving sites from sites_after_knockout.csv.\n\n', n);

if n == 0
    error('No surviving sites to score -- check sites_after_knockout.csv.');
end

%% Weights from your Table 3.8 (rank-based weights)
weights = struct( ...
    'GHI',          26.5, ...
    'Slope',        17.0, ...
    'DistGrid_km',  17.0, ...
    'Aspect',       10.6, ...
    'LULC_code',    10.0, ...
    'AmbientTemp',   7.7, ...
    'DistRoad_km',   5.5, ...
    'DistWater_km',  3.9, ...
    'WindSpeed',     3.0, ...
    'AOD',           2.0 ...
);

%% Score
[scores, breakdown] = compute_score(sites, weights);
sites.score = scores;

%% Rank and save
ranked = sortrows(sites, 'score', 'descend');
writetable(ranked, 'ranked_sites.csv');

% Also save the per-parameter breakdown, sorted to match
breakdown.score = scores;
breakdownRanked = sortrows(breakdown, 'score', 'descend');
writetable(breakdownRanked, 'score_breakdown.csv');

fprintf('Ranked sites (best to worst):\n');
for i = 1:height(ranked)
    fprintf('  %d. %s -- score %.1f\n', i, ranked.site_name{i}, ranked.score(i));
end

fprintf('\nSaved ranked_sites.csv (full data + final score, ranked).\n');
fprintf('Saved score_breakdown.csv (each site''s 0-100 score per parameter,\n');
fprintf('  useful for seeing exactly what drove each site''s overall score).\n');
