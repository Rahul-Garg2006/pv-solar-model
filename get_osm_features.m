function coords = get_osm_features(lat, lon, radiusKm, tagQuery)
% GET_OSM_FEATURES  Query OpenStreetMap (via Overpass API) for features
%   of a given type near a point, e.g. roads, substations, water bodies.
%
%   lat, lon  : center point (decimal degrees)
%   radiusKm  : how far around the point to search (keep this modest --
%               30-50km is plenty for road/grid/water proximity checks;
%               larger radii are much more likely to time out)
%   tagQuery  : OSM tag filter string, e.g. 'highway' or 'power=substation'
%               or 'natural=water'
%
%   Returns an Nx2 matrix of [lat, lon] for matching features.
%   Returns an empty matrix if nothing found or the query fails after
%   all retry attempts.
%
%   This function automatically retries with increasing delays if the
%   Overpass server responds with "429 Too Many Requests" or a timeout,
%   since the public Overpass server rate-limits clients that send many
%   requests in a short time.

    radiusM = radiusKm * 1000;

    if contains(tagQuery, '=')
        parts = strsplit(tagQuery, '=');
        tagFilter = sprintf('["%s"="%s"]', parts{1}, parts{2});
    else
        tagFilter = sprintf('["%s"]', tagQuery);
    end

    query = sprintf(['[out:json][timeout:25];' ...
        '(way%s(around:%d,%f,%f);node%s(around:%d,%f,%f);' ...
        ');out center;'], ...
        tagFilter, radiusM, lat, lon, tagFilter, radiusM, lat, lon);

    url = 'https://overpass-api.de/api/interpreter';
    opts = weboptions('Timeout', 30);

    coords = [];
    maxRetries = 4;
    baseDelay = 5; % seconds

    for attempt = 1:maxRetries
        try
            result = webread(url, 'data', query, opts);

            if isfield(result, 'elements')
                elements = result.elements;
                numEls = numel(elements);
                for i = 1:numEls
                    % Overpass responses come back as a uniform struct
                    % array when every element has identical fields, but
                    % as a cell array when elements differ (e.g. some
                    % "node" results with direct lat/lon mixed with
                    % "way" results that only have a "center" field).
                    % Handle both cases.
                    if iscell(elements)
                        el = elements{i};
                    else
                        el = elements(i);
                    end

                    if isfield(el, 'lat') && isfield(el, 'lon')
                        coords = [coords; el.lat, el.lon]; %#ok<AGROW>
                    elseif isfield(el, 'center')
                        coords = [coords; el.center.lat, el.center.lon]; %#ok<AGROW>
                    end
                end
            end
            return; % success -- stop retrying

        catch ME
            isRateLimit = contains(ME.message, '429') || ...
                          contains(ME.message, 'Too Many Requests');
            isTimeout = contains(ME.message, '504') || ...
                        contains(ME.message, 'Gateway Timeout') || ...
                        contains(ME.message, 'timeout', 'IgnoreCase', true);

            if (isRateLimit || isTimeout) && attempt < maxRetries
                waitTime = baseDelay * (2^(attempt-1)); % exponential backoff
                fprintf('      (rate-limited/timeout, waiting %ds before retry %d/%d)\n', ...
                    waitTime, attempt+1, maxRetries);
                pause(waitTime);
            else
                warning('Overpass query failed near (%.4f, %.4f) for "%s": %s', ...
                    lat, lon, tagQuery, ME.message);
                return;
            end
        end
    end
end
