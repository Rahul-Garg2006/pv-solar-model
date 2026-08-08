function [areaSqKm, areaAcres] = compute_land_availability(siteLat, siteLon, ...
    radiusKm, lulcGrid, lulcR, slopeGrid, slopeR, lulcCode, maxSlopeDeg)
% COMPUTE_LAND_AVAILABILITY  Estimate how much usable land exists within
%   a radius of a site, based on LULC classification and terrain slope.
%
%   A pixel counts as "available" only if BOTH:
%     - its LULC code matches lulcCode (e.g. 60 = bare/sparse vegetation
%       in ESA WorldCover)
%     - its slope is <= maxSlopeDeg (e.g. 15 degrees)
%
%   Inputs:
%     siteLat, siteLon : site coordinates
%     radiusKm          : search radius around the site (e.g. 5)
%     lulcGrid, lulcR   : LULC matrix and its raster reference (from readgeoraster)
%     slopeGrid, slopeR : slope matrix (degrees) and its raster reference
%                         (slopeR is the SAME reference as the DEM it came from)
%     lulcCode          : which LULC code counts as "available" (60 = bare/sparse)
%     maxSlopeDeg       : maximum slope considered buildable (e.g. 15)
%
%   Outputs:
%     areaSqKm   : total available land area, square kilometers
%     areaAcres  : same area, in acres
%
%   NOTE: LULC and DEM/slope rasters usually have different pixel
%   resolutions (e.g. LULC at 10m, DEM at 30m). This function evaluates
%   each LULC pixel individually (since it's normally the finer
%   resolution) and looks up the corresponding slope value at that exact
%   point using sample_raster -- so the two grids don't need to match in
%   size or alignment.

    % --- Step 1: figure out which LULC pixels fall within radiusKm of the site ---
    latLim = lulcR.LatitudeLimits;
    lonLim = lulcR.LongitudeLimits;
    nRows = lulcR.RasterSize(1);
    nCols = lulcR.RasterSize(2);

    % Degrees-per-pixel for the LULC grid
    degPerPixelLat = (latLim(2) - latLim(1)) / nRows;
    degPerPixelLon = (lonLim(2) - lonLim(1)) / nCols;

    midLat = mean(latLim);
    metersPerDegLat = 111320;
    metersPerDegLon = 111320 * cosd(midLat);

    pixelHeightM = degPerPixelLat * metersPerDegLat;
    pixelWidthM  = degPerPixelLon * metersPerDegLon;
    pixelAreaSqM = pixelHeightM * pixelWidthM;

    % Convert the search radius into a degree-box around the site, so we
    % only loop over the small relevant chunk of the LULC grid instead of
    % the entire downloaded tile (much faster).
    radiusDegLat = radiusKm / (metersPerDegLat/1000);
    radiusDegLon = radiusKm / (metersPerDegLon/1000);

    rowStart = max(1, round((latLim(2) - (siteLat+radiusDegLat)) / degPerPixelLat));
    rowEnd   = min(nRows, round((latLim(2) - (siteLat-radiusDegLat)) / degPerPixelLat));
    colStart = max(1, round(((siteLon-radiusDegLon) - lonLim(1)) / degPerPixelLon));
    colEnd   = min(nCols, round(((siteLon+radiusDegLon) - lonLim(1)) / degPerPixelLon));

    if rowStart > rowEnd || colStart > colEnd
        areaSqKm = 0;
        areaAcres = 0;
        return;
    end

    subGrid = lulcGrid(rowStart:rowEnd, colStart:colEnd);

    % --- Step 2: build the actual lat/lon of every pixel in this sub-grid ---
    rowIdx = (rowStart:rowEnd)';
    colIdx = (colStart:colEnd);

    pixelLats = latLim(2) - (rowIdx - 0.5) * degPerPixelLat;   % column vector
    pixelLons = lonLim(1) + (colIdx - 0.5) * degPerPixelLon;   % row vector

    [lonGridSub, latGridSub] = meshgrid(pixelLons, pixelLats);  % same size as subGrid

    % --- Step 3: keep only pixels truly within radiusKm (circular, not box) ---
    Re = 6371;
    lat1 = deg2rad(siteLat); lon1 = deg2rad(siteLon);
    lat2 = deg2rad(latGridSub); lon2 = deg2rad(lonGridSub);
    dlat = lat2 - lat1; dlon = lon2 - lon1;
    a = sin(dlat/2).^2 + cos(lat1).*cos(lat2).*sin(dlon/2).^2;
    distKm = 2 * Re * atan2(sqrt(a), sqrt(1-a));

    withinRadius = distKm <= radiusKm;

    % --- Step 4: check LULC condition ---
    isCorrectLULC = (double(subGrid) == lulcCode);

    % --- Step 5: check slope condition (look up slope at each kept pixel) ---
    keepMask = withinRadius & isCorrectLULC;
    [keepRows, keepCols] = find(keepMask);

    availableCount = 0;
    for k = 1:numel(keepRows)
        pLat = latGridSub(keepRows(k), keepCols(k));
        pLon = lonGridSub(keepRows(k), keepCols(k));
        sVal = sample_raster(pLat, pLon, slopeGrid, slopeR);
        if ~isnan(sVal) && sVal <= maxSlopeDeg
            availableCount = availableCount + 1;
        end
    end

    % --- Step 6: convert pixel count to real area ---
    areaSqM = availableCount * pixelAreaSqM;
    areaSqKm = areaSqM / 1e6;
    areaAcres = areaSqM / 4046.86; % 1 acre = 4046.86 sq meters
end
