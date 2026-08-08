function data = get_nasa_data(lat, lon, params)
% GET_NASA_DATA  Pull annual-average climatology parameters for one site
%   lat, lon : site coordinates (decimal degrees)
%   params   : cell array of NASA POWER parameter codes,
%              e.g. {'ALLSKY_SFC_SW_DWN','T2M','WS10M','AOD_55'}
%
%   Returns a struct with one field per parameter, holding the
%   long-term annual average value ("ANN") for that site.

    paramStr = strjoin(params, ',');
    url = sprintf(['https://power.larc.nasa.gov/api/temporal/climatology/point?' ...
        'parameters=%s&community=RE&longitude=%f&latitude=%f&format=JSON'], ...
        paramStr, lon, lat);

    data = struct();
    try
        raw = webread(url);
        for i = 1:numel(params)
            p = params{i};
            if isfield(raw.properties.parameter, p)
                pdata = raw.properties.parameter.(p);
                if isfield(pdata, 'ANN')
                    data.(p) = pdata.ANN;
                else
                    data.(p) = NaN;
                end
            else
                data.(p) = NaN;
            end
        end
    catch ME
        warning('NASA POWER request failed for (%.4f, %.4f): %s', lat, lon, ME.message);
        for i = 1:numel(params)
            data.(params{i}) = NaN;
        end
    end
end
