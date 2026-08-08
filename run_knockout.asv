%% run_knockout.m
% LAYER 1 -- KNOCKOUT. Run this AFTER acquire_data.m has built up
% sites_full_data.csv with all your sites. This script applies 5 hard
% pass/fail thresholds and saves the surviving sites to
% sites_after_knockout.csv.
%
% Run it by typing:  run_knockout

clear; clc;

fprintf('=== KNOCKOUT LAYER ===\n\n');

%% Load the full dataset
sites = readtable('sites_full_data.csv');
n = height(sites);
fprintf('Loaded %d sites from sites_full_data.csv.\n\n', n);

%% Define thresholds -- see README/report for citations behind each value
%
% GHI            : reject if < 4.8 kWh/m2/day
%   Source: Table S2, "Exclusion criteria, thresholds, and buffer
%   distances for solar energy siting", arXiv:2410.01684
%
% Slope          : reject if > 15 degrees
%   Project-defined (matches land-availability calc); broadly consistent
%   with literature using >10 deg as a common exclusion threshold.
%
% DistGrid_km    : reject if > 10 km
%   Project-defined. Grid/substation connection is higher cost-per-km
%   infrastructure than road access, so a tighter distance tolerance
%   is used.
%
% DistRoad_km    : reject if > 20 km
%   Project-defined. Road access is lower cost-per-km than grid
%   connection, so a looser distance tolerance is used.
%
%
% LULC_code      : reject if forest, water, wetland, mangrove, or built-up
%   Source: Table S2 (arXiv:2410.01684) -- wetlands/open water = "no go";
%   also arXiv:2504.12508 -- utility-scale PV avoided on forest, water,
%   wetland, and impervious/built-up land.
%   ESA WorldCover codes: 10=tree cover, 50=built-up, 80=water,
%   90=wetland, 95=mangrove

thresholds = struct( ...
    'GHI',         [4.8, Inf], ...
    'Slope',       [-Inf, 15], ...
    'DistGrid_km', [-Inf, 10], ...
    'DistRoad_km', [-Inf, 20] ...
);

lulcRejectCodes = [10, 50, 80, 90, 95]; % tree cover, built-up, water, wetland, mangrove


%% Apply knockout
[passed, failReason] = apply_knockout(sites, thresholds, lulcRejectCodes);

sites.fail_reason = failReason;
survivors = sites(passed, :);
rejected = sites(~passed, :);

fprintf('Results:\n');
fprintf('  %d of %d sites PASSED.\n', sum(passed), n);
fprintf('  %d of %d sites REJECTED.\n\n', sum(~passed), n);

if ~isempty(rejected)
    fprintf('Rejected sites and reasons:\n');
    for i = 1:height(rejected)
        fprintf('  %s: %s\n', rejected.site_name{i}, rejected.fail_reason{i});
    end
    fprintf('\n');
end

%% Save results
writetable(survivors, 'sites_after_knockout.csv');
writetable(sites, 'sites_knockout_full.csv'); % includes both pass/fail + reasons

fprintf('Saved sites_after_knockout.csv (%d surviving sites, ready for scoring layer).\n', height(survivors));
fprintf('Saved sites_knockout_full.csv (all sites with pass/fail status, for review).\n');
