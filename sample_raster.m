function val = sample_raster(lat, lon, Z, R)
% SAMPLE_RASTER  Get the raster value (elevation, slope, LULC class, etc.)
%   at a specific lat/lon point.
%   Z : 2D matrix of raster values (from readgeoraster)
%   R : raster reference object (from readgeoraster)
%
%   Returns NaN if the point falls outside the raster's coverage.

    latLim = R.LatitudeLimits;
    lonLim = R.LongitudeLimits;

    if lat < latLim(1) || lat > latLim(2) || lon < lonLim(1) || lon > lonLim(2)
        val = NaN;
        return;
    end

    nRows = R.RasterSize(1);
    nCols = R.RasterSize(2);

    % Raster rows go from north (top, row 1) to south (bottom, row nRows)
    row = round((latLim(2) - lat) / (latLim(2) - latLim(1)) * (nRows - 1)) + 1;
    col = round((lon - lonLim(1)) / (lonLim(2) - lonLim(1)) * (nCols - 1)) + 1;

    row = min(max(row, 1), nRows);
    col = min(max(col, 1), nCols);

    val = double(Z(row, col));
end
