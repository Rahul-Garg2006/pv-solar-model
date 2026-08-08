%% acquire_data.m
% DATA ACQUISITION ONLY -- run this first, by itself, before touching
% knockout or scoring. This script's only job is to take your
% sites_input.csv and fill in all available parameters, saving the
% result as sites_full_data.csv.
%
% WORKFLOW NOTE: this is set up for ONE SITE AT A TIME. Put a single
% site's name/lat/lon in sites_input.csv, download the DEM and LULC
% tiles that cover THAT site (see get_worldcover_url.m for LULC), run
% this script, then copy that site's row out of sites_full_data.csv
% into your master results table before moving to the next site.
%
% Run it by typing:  acquire_data
%
% BEFORE RUNNING (for the current site):
%   1. sites_input.csv has that site's row (columns: site_name, lat, lon)
%   2. data/dem.tif covers that site (download from opentopography.org)
%   3. data/lulc.tif covers that site (use get_worldcover_url.m, see README)
%   4. You need an internet connection (NASA POWER + OpenStreetMap calls)

clear; clc;

fprintf('=== DATA ACQUISITION ===\n\n');

%% Load site list
fprintf('Loading site list...\n');
sites = readtable('sites_input.csv');
n = height(sites);
fprintf('  %d sites loaded.\n\n', n);

%% NASA POWER: GHI, AOD, Ambient Temperature, Wind Speed
fprintf('Fetching NASA POWER data (GHI, AOD, Temperature, Wind Speed)...\n');

% Parameter codes verified directly against the NASA POWER API:
%   ALLSKY_SFC_SW_DWN = GHI, kWh/m2/day
%   AOD_55            = Aerosol Optical Depth at 550nm, dimensionless
%   T2M               = Air temperature at 2m, deg C
%   WS10M             = Wind speed at 10m, m/s
nasaParams = {'ALLSKY_SFC_SW_DWN', 'AOD_55', 'T2M', 'WS10M'};

sites.GHI = nan(n,1);
sites.AOD = nan(n,1);
sites.AmbientTemp = nan(n,1);
sites.WindSpeed = nan(n,1);

for i = 1:n
    fprintf('  (%d/%d) %s ... ', i, n, sites.site_name{i});
    d = get_nasa_data(sites.lat(i), sites.lon(i), nasaParams);
    sites.GHI(i)         = d.ALLSKY_SFC_SW_DWN;
    sites.AOD(i)         = d.AOD_55;
    sites.AmbientTemp(i) = d.T2M;
    sites.WindSpeed(i)   = d.WS10M;
    fprintf('done.\n');
end
fprintf('NASA POWER data complete.\n\n');

%% DEM: Slope & Aspect
fprintf('Computing Slope & Aspect from DEM...\n');

sites.Slope = nan(n,1);
sites.Aspect = nan(n,1);

demPath = fullfile('data', 'dem.tif');
if isfile(demPath)
    [Z, R] = readgeoraster(demPath);
    [slopeGrid, aspectGrid] = compute_slope_aspect(Z, R);

    for i = 1:n
        sites.Slope(i)  = sample_raster(sites.lat(i), sites.lon(i), slopeGrid, R);
        sites.Aspect(i) = sample_raster(sites.lat(i), sites.lon(i), aspectGrid, R);
    end
    fprintf('  Slope & Aspect filled in for all sites within DEM coverage.\n\n');
else
    warning(['data/dem.tif not found. Slope and Aspect will stay NaN.\n' ...
        'Download SRTM GL1 (30m) from opentopography.org and save it as data/dem.tif\n']);
end

%% LULC: Land Use / Land Cover classification code
fprintf('Looking up LULC classification...\n');

sites.LULC_code = nan(n,1);

lulcPath = fullfile('data', 'lulc.tif');
if isfile(lulcPath)
    [Zlulc, Rlulc] = readgeoraster(lulcPath);
    for i = 1:n
        sites.LULC_code(i) = sample_raster(sites.lat(i), sites.lon(i), Zlulc, Rlulc);
    end
    fprintf('  LULC codes filled in for all sites within raster coverage.\n');
    fprintf('  NOTE: these are raw class numbers -- check your LULC legend/metadata\n');
    fprintf('  file from Bhuvan to know what each number means.\n\n');
else
    warning(['data/lulc.tif not found. LULC_code will stay NaN.\n' ...
        'Download from ESA WorldCover and save as data/lulc.tif\n']);
end

%% OpenStreetMap: Distance to road, grid/substation, water body
fprintf('Fetching OSM distances (roads, substations, water bodies)...\n');
fprintf('  This calls the Overpass API once per site per feature type, with\n');
fprintf('  a short pause between calls to avoid the server''s rate limit --\n');
fprintf('  it will take a little while for many sites. Please be patient.\n\n');

sites.DistRoad_km = nan(n,1);
sites.DistGrid_km = nan(n,1);
sites.DistWater_km = nan(n,1);

% Keep this modest -- 30-50km is enough for proximity checks, and large
% radii (100km+) are much more likely to time out or get rate-limited.
searchRadiusKm = 50;
pauseBetweenCalls = 3; % seconds, between each Overpass request

for i = 1:n
    fprintf('  (%d/%d) %s ...\n', i, n, sites.site_name{i});
    lat = sites.lat(i); lon = sites.lon(i);

    roads = get_osm_features(lat, lon, searchRadiusKm, 'highway');
    sites.DistRoad_km(i) = nearest_distance(lat, lon, roads);
    fprintf('      Road: %.2f km\n', sites.DistRoad_km(i));
    pause(pauseBetweenCalls);

    substations = get_osm_features(lat, lon, searchRadiusKm, 'power=substation');
    sites.DistGrid_km(i) = nearest_distance(lat, lon, substations);
    fprintf('      Grid/substation: %.2f km\n', sites.DistGrid_km(i));
    pause(pauseBetweenCalls);

    water = get_osm_features(lat, lon, searchRadiusKm, 'natural=water');
    sites.DistWater_km(i) = nearest_distance(lat, lon, water);
    fprintf('      Water body: %.2f km\n', sites.DistWater_km(i));
    pause(pauseBetweenCalls);
end
fprintf('\nOSM distance data complete.\n\n');

%% Land Availability: usable land area near each site.
%% For EXISTING plants with a known real footprint (KnownFootprint_acres
%% filled in), use that real number directly -- the LULC+slope estimate
%% systematically undercounts existing plants, since built solar panels
%% no longer register as "bare/sparse vegetation" in satellite imagery.
%% For POTENTIAL sites (KnownFootprint_acres left blank), fall back to
%% the automatic LULC (bare/sparse vegetation) + slope (<=15 deg) estimate.
fprintf('Computing Land Availability...\n');

sites.LandAvailability_sqkm = nan(n,1);
sites.LandAvailability_acres = nan(n,1);

if ~ismember('KnownFootprint_acres', sites.Properties.VariableNames)
    sites.KnownFootprint_acres = nan(n,1);
end

radiusKm = 5;        % search radius around each site (for estimated sites only)
lulcCode = 60;       % ESA WorldCover: 60 = Bare / sparse vegetation
maxSlopeDeg = 15;    % matches knockout slope threshold -- change here if needed

for i = 1:n
    fprintf('  (%d/%d) %s ... ', i, n, sites.site_name{i});

    if ~isnan(sites.KnownFootprint_acres(i))
        % Existing plant with a real, known footprint -- use it directly.
        sites.LandAvailability_acres(i) = sites.KnownFootprint_acres(i);
        sites.LandAvailability_sqkm(i) = sites.KnownFootprint_acres(i) * 0.00404686;
        fprintf('using known footprint: %.0f acres (%.2f sq km)\n', ...
            sites.LandAvailability_acres(i), sites.LandAvailability_sqkm(i));

    elseif isfile(lulcPath) && isfile(demPath)
        % Potential site, no known footprint -- estimate from LULC+slope.
        [aSqKm, aAcres] = compute_land_availability( ...
            sites.lat(i), sites.lon(i), radiusKm, ...
            Zlulc, Rlulc, slopeGrid, R, lulcCode, maxSlopeDeg);
        sites.LandAvailability_sqkm(i) = aSqKm;
        sites.LandAvailability_acres(i) = aAcres;
        fprintf('estimated from LULC+slope: %.2f sq km (%.0f acres)\n', aSqKm, aAcres);

    else
        fprintf('skipped (no known footprint, and no DEM/LULC files available)\n');
    end
end
fprintf('Land availability complete.\n\n');

%% Power per Land = PlantCapacity_MW / LandAvailability_acres
fprintf('Computing Power per Land...\n');

if ~ismember('PlantCapacity_MW', sites.Properties.VariableNames)
    sites.PlantCapacity_MW = nan(n,1);
    warning(['  "PlantCapacity_MW" column not found in sites_input.csv --\n' ...
        '  add it yourself (existing plants: known capacity; potential\n' ...
        '  sites: your proposed capacity) for PowerPerLand to compute.\n']);
end

sites.PowerPerLand_MWperAcre = sites.PlantCapacity_MW ./ sites.LandAvailability_acres;
% Higher value = more power generated per acre of available land near
% the site -- i.e. more land-efficient.
fprintf('  PowerPerLand_MWperAcre = PlantCapacity_MW / LandAvailability_acres.\n\n');

%% Save result -- APPENDS to a master file so each single-site run
%% accumulates, rather than overwriting previous sites' results.
outFile = 'sites_full_data.csv';

if isfile(outFile)
    existing = readtable(outFile);
    % Avoid duplicate rows if you accidentally re-run the same site
    existing = existing(~ismember(existing.site_name, sites.site_name), :);
    combined = [existing; sites];
else
    combined = sites;
end

writetable(combined, outFile);

fprintf('=== DONE ===\n');
fprintf('Saved %s with %d site(s) total (this run added: %s).\n', ...
    outFile, height(combined), strjoin(sites.site_name, ', '));
disp(combined.Properties.VariableNames');

fprintf('\nCheck this file before moving to knockout. Look especially for:\n');
fprintf('  - Any NaN values (missing data -- find out why before scoring)\n');
fprintf('  - Slope/Aspect/LULC_code = NaN for ALL rows (means DEM/LULC file is missing\n');
fprintf('    or your sites fall outside the downloaded tile''s coverage area)\n');
