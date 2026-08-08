function [slopeDeg, aspectDeg] = compute_slope_aspect(Z, R)
% COMPUTE_SLOPE_ASPECT  Derive slope (degrees) and aspect (compass degrees)
%   grids from a digital elevation model, using only base MATLAB (no
%   Mapping Toolbox required beyond readgeoraster, which is built-in
%   since R2020a).
%
%   Z : elevation matrix (from readgeoraster)
%   R : raster reference object (from readgeoraster)
%
%   Returns matrices the same size as Z.

    Z = double(Z);
    latLim = R.LatitudeLimits;
    lonLim = R.LongitudeLimits;
    nRows = R.RasterSize(1);
    nCols = R.RasterSize(2);

    % Approximate meters-per-pixel (good enough for slope/aspect at this scale)
    midLat = mean(latLim);
    degPerPixelLat = (latLim(2) - latLim(1)) / nRows;
    degPerPixelLon = (lonLim(2) - lonLim(1)) / nCols;

    metersPerDegLat = 111320;                       % ~constant everywhere
    metersPerDegLon = 111320 * cosd(midLat);         % shrinks away from equator

    dy = degPerPixelLat * metersPerDegLat;           % meters per pixel, N-S
    dx = degPerPixelLon * metersPerDegLon;           % meters per pixel, E-W

    [dzdx, dzdy] = gradient(Z, dx, dy);

    slopeDeg = atand(sqrt(dzdx.^2 + dzdy.^2));

    % Aspect as compass bearing (0=N, 90=E, 180=S, 270=W)
    aspectDeg = mod(450 - atan2d(dzdy, -dzdx), 360);
end
