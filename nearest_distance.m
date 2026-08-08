function d_km = nearest_distance(siteLat, siteLon, featureCoords)
% NEAREST_DISTANCE  Great-circle distance (km) from a site to the
%   nearest point in a list of feature coordinates, using the
%   haversine formula (no toolbox required).
%
%   siteLat, siteLon : the site's coordinates
%   featureCoords     : Nx2 matrix of [lat, lon] for candidate features
%
%   Returns NaN if featureCoords is empty (no features found nearby).

    if isempty(featureCoords)
        d_km = NaN;
        return;
    end

    Re = 6371; % Earth radius, km
    lat1 = deg2rad(siteLat);
    lon1 = deg2rad(siteLon);
    lat2 = deg2rad(featureCoords(:,1));
    lon2 = deg2rad(featureCoords(:,2));

    dlat = lat2 - lat1;
    dlon = lon2 - lon1;

    a = sin(dlat/2).^2 + cos(lat1).*cos(lat2).*sin(dlon/2).^2;
    distances = 2 * Re * atan2(sqrt(a), sqrt(1-a));

    d_km = min(distances);
end
