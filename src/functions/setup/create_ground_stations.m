function ground_stations = create_ground_stations(sc, config, gs_pos)
% Description: Builds ground_station_t array.
% Arguments:
%   sc: Satellite scenario object.
%   config: Configuration struct.
%   gs_pos: Ground stations' positions.
% Returns:
%   ground_stations: ground_station_t array.

    % Initializes the ground_station_t array:
    ground_stations(config.total_grounds) = ground_station_t;

    % Gets the ground station scenario objects:
    gs = sc.GroundStations;
    for g = 1:config.total_grounds

        % Creates the ground station:
        ground_stations(g) = ground_station_t(g, gs(g), name=config.ground_names(g), first_pos=gs_pos(g, :));
    end
end

