function url = get_worldcover_url(lat, lon, year)
% GET_WORLDCOVER_URL  Build the direct AWS download URL for the ESA
%   WorldCover tile covering a given lat/lon point. No login required --
%   this hits the public AWS Open Data bucket directly.
%
%   lat, lon : the site's coordinates
%   year     : 2020 or 2021 (2021 uses the improved v200 algorithm,
%              recommended unless you have a specific reason to use 2020)
%
%   Returns the full URL as a string. Paste it into a browser, or use
%   websave(filename, url) in MATLAB to download it directly.
%
%   Example:
%       url = get_worldcover_url(27.54, 71.91, 2021);
%       websave('data/lulc.tif', url);

    if nargin < 3
        year = 2021;
    end

    if year == 2021
        version = 'v200';
    elseif year == 2020
        version = 'v100';
    else
        error('year must be 2020 or 2021');
    end

    % Tiles are 3x3 degrees, named by their lower-left (south-west)
    % corner, rounded DOWN to the nearest multiple of 3.
    latFloor = floor(lat / 3) * 3;
    lonFloor = floor(lon / 3) * 3;

    if latFloor >= 0
        latHem = 'N';
    else
        latHem = 'S';
    end
    if lonFloor >= 0
        lonHem = 'E';
    else
        lonHem = 'W';
    end

    tileName = sprintf('%s%02d%s%03d', latHem, abs(latFloor), lonHem, abs(lonFloor));

    url = sprintf(['https://esa-worldcover.s3.eu-central-1.amazonaws.com/' ...
        '%s/%d/map/ESA_WorldCover_10m_%d_%s_%s_Map.tif'], ...
        version, year, year, version, tileName);

    fprintf('Site (%.4f, %.4f) falls in tile %s\n', lat, lon, tileName);
    fprintf('URL: %s\n', url);
end
