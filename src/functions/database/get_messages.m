function messages = get_messages(conn, read_bucket, squitter_measurement, curr_time, dt)
% Description: Gets the information of the messages in a given time period.
% Arguments:
%   conn: InfluxDB connection.
%   read_bucket: Bucket.
%   squitter_measurement: Squitter measurement name.
%   curr_time: Current time.
%   dt: Time window (in seconds).
% Returns:
%   messages: Final retrieved broadcast messages.

    % Format time:
    if isnumeric(curr_time)
        curr_time = int64(curr_time);
        target_ns = curr_time;
        t_obj = datetime(double(curr_time)/1e9, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
    elseif isdatetime(curr_time)
        t_obj = curr_time;
        if isempty(t_obj.TimeZone)
            t_obj.TimeZone = 'UTC';
        end
        target_ns = int64(posixtime(t_obj) * 1e9); 
    end
    final_ns = target_ns + int64(dt * 1e9);
    start_str = string(t_obj - seconds(0.05), "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSS'Z'");
    stop_str = string(t_obj + seconds(dt) + seconds(0.05), "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSS'Z'");

    % Build query:
    query = [...
        'from(bucket:"', char(read_bucket), '") ', ...
        '|> range(start: ', char(start_str), ', stop: ', char(stop_str), ') ', ...
        '|> filter(fn: (r) => r._measurement == "', char(squitter_measurement), '") ', ...
        '|> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")', ...
        '|> filter(fn: (r) => r.Unix_Time_ns >= ', char(string(target_ns)), ') ', ...
        '|> filter(fn: (r) => r.Unix_Time_ns < ', char(string(final_ns)), ') '];

    % Query data:
    try
        T = queryData(conn, query);
    catch
        messages = [];
        return;
    end

    % Create messages:
    TT = T{1};
    num_rows = size(TT, 1);
    messages(1:num_rows) = broadcast_message_t;
    for i = 1:num_rows
        sat_pos = [TT.rx_pos_x(i), TT.rx_pos_y(i), TT.rx_pos_z(i)];
        sat_vel = [TT.rx_vel_x(i), TT.rx_vel_y(i), TT.rx_vel_z(i)];
        msg_time = TT.Properties.RowTimes(i);
        messages(i) = broadcast_message_t(...
            'Time', msg_time, 'Unix_Time_ns', TT.Unix_Time_ns(i), ...
            'ToA', TT.ToA(i), 'FoA', TT.FoA(i), 'AoA_H', TT.AoA_H(i), ...
            'SAT_Position_ecef', sat_pos, 'SAT_Velocity_ecef', sat_vel, 'SAT_RM', TT.SAT_RM(i), 'SAT_ID', TT.SAT_ID(i), ...
            'airplane_Unix_timestamp', TT.airplane_Unix_timestamp(i), 'airplane_ICAO', TT.airplane_ICAO(i), 'airplane_callsign', TT.airplane_callsign(i), ...
            'airplane_lat', TT.airplane_lat(i), 'airplane_lon', TT.airplane_lon(i), 'airplane_alt', TT.airplane_alt(i), 'region', read_bucket);
    end
end
