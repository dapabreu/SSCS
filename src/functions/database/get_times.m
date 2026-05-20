function [min_time, max_time] = get_times(conn, read_bucket, squitter_measurement)
% Description: Gets minimum and maximum times.
% Arguments:
%   conn: InfluxDB connection.
%   read_bucket: Bucket.
%   squitter_measurement: Squitter measurement name.
% Returns:
%   min_time: Minimum time.
%   max_time: Maximum time.

    % Build query:
    query = [...
        'data = from(bucket:"', char(read_bucket), '") ', ...
        '|> range(start: 0) ', ...
        '|> filter(fn: (r) => r["_measurement"] == "', char(squitter_measurement), '") ', ...
        '|> filter(fn: (r) => r["_field"] == "Unix_Time_ns") ', ...
        '|> group() ', ...
        'minValue = data ', ...
        '  |> min() ', ...
        '  |> set(key: "result_type", value: "absolute_min") ', ...
        'maxValue = data ', ...
        '  |> max() ', ...
        '  |> set(key: "result_type", value: "absolute_max") ', ...
        'union(tables: [minValue, maxValue])'];

    % Get query results:
    try
        T = queryData(conn, query);
    catch
        T = {};
    end

    % If missing:
    if isempty(T)
        min_time = missing;
        max_time = missing;

    % Otherwise:
    else
        TT = T{1};
        vals = TT.('_value');
        min_time = int64(min(vals));
        max_time = int64(max(vals));
    end
end
