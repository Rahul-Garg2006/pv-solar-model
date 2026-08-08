function [passed, failReason] = apply_knockout(sites, thresholds, lulcRejectCodes)
% APPLY_KNOCKOUT  Layer 1 — eliminates sites that fail any hard threshold.
%
%   sites      : table, one row per site, with one column per parameter
%   thresholds : struct, field name = column name in `sites`,
%                value = [min max]. Use -Inf or Inf if only one bound
%                applies (e.g. [4.8, Inf] means "must be >= 4.8").
%                Do NOT include 'LULC_code' or 'Aspect' here -- they are
%                handled separately below since they aren't simple
%                numeric ranges.
%   lulcRejectCodes : vector of LULC_code values that should cause
%                     rejection (e.g. [10 50 80 90 95] for forest,
%                     built-up, water, wetland, mangrove). Pass [] to
%                     skip this check.
%   aspectRange     : [minDeg maxDeg] compass range considered
%                     acceptable (e.g. [135 225] for south-facing).
%                     Sites with Aspect outside this range are rejected.
%                     Pass [] to skip this check.
%
%   Returns:
%   passed     : logical column vector, true = site survives
%   failReason : cell array of strings listing which parameter(s) failed

    n = height(sites);
    passed = true(n,1);
    failReason = repmat({''}, n, 1);

    paramNames = fieldnames(thresholds);

    % --- Simple numeric [min max] checks (GHI, Slope, distances, etc.) ---
    for i = 1:n
        for k = 1:numel(paramNames)
            p = paramNames{k};
            if ~ismember(p, sites.Properties.VariableNames)
                continue; % parameter not in table, skip silently
            end
            bounds = thresholds.(p);
            val = sites.(p)(i);

            if isnan(val)
                continue; % can't evaluate, don't auto-fail on missing data
            end

            if val < bounds(1) || val > bounds(2)
                passed(i) = false;
                failReason{i} = [failReason{i}, p, '; '];
            end
        end
    end

    % --- LULC categorical check ---
    if nargin >= 3 && ~isempty(lulcRejectCodes) && ismember('LULC_code', sites.Properties.VariableNames)
        for i = 1:n
            val = sites.LULC_code(i);
            if isnan(val)
                continue;
            end
            if ismember(val, lulcRejectCodes)
                passed(i) = false;
                failReason{i} = [failReason{i}, 'LULC_code; '];
            end
        end
    end

    % --- Aspect range check (handles compass wraparound correctly) ---
    