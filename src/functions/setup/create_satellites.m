function satellites = create_satellites(sc, config, sat_pos)
% Description: Builds satellite_t array.
% Arguments:
%   sc: Satellite scenario object.
%   config: Configuration struct.
%   sat_pos: Satellites' positions.
% Returns:
%   satellites: satellite_t array.

    % Initializes the satellite_t array:
    satellites(config.total_satellites) = satellite_t;

    % Gets the satellite constellation:
    sats = sc.Satellites;
    down_idx = 1;
    for s = 1:config.total_satellites

        % Checks if the satellite is a downlink satellite:
        if down_idx <= config.total_downlinks && s == config.downlink_idxs(down_idx)
            downlink = true;
            down_idx = down_idx + 1;
        else
            downlink = false;
        end

        % Creates the satellite:
        satellites(s) = satellite_t(config.total_grounds + config.total_planes + s, sats(s), downlink, failure_model=config.failure_data.(config.failure_scenario), processing_delay=config.processing_delay, name="LEO" + s, first_pos=sat_pos(s, :));
    end
end

