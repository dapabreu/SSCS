function config = create_parameters(parameters_file)
% Description: Extracts the simulation's parameters from a parameter file.
% Arguments:
%   parameters_file: The name of the file containing the simulation parameters.
% Returns:
%   config: A structure containing the gathered information from the file.
    
    % Initialize output structure:
    config = struct();

    % Open the file:
    fid = fopen(parameters_file, 'r');

    % Throws an error if opening the file failed:
    if fid == -1
        error('Cannot open file: %s', parameters_file);
    end
    
    % Read and process the file line by line:
    while ~feof(fid)
        line = strtrim(fgetl(fid));

        % Ignore the line if its empty, a comment (starts with '%'), or a header (ends with ':'):
        if isempty(line) || strncmp(line, '%', 1) || endsWith(line, ':')
            continue;
        end

        % Parse key-value pairs:
        if contains(line, '=')
            idx = strfind(line, '=');

            % Throws an error if the line is incorrectly formatted:
            if isempty(idx)
                fclose(fid);
                error('Invalid line format: %s. Expected ''key=value''.', line);
            end

            % Gets key and value:
            firstEq = idx(1);
            key = strtrim(line(1:firstEq-1));
            value = strtrim(line(firstEq+1:end));

            % Tries converting the value to a double:
            num_value = str2double(value);

            % If the conversion worked, save the value as a double:
            if ~isnan(num_value)
                config.(key) = num_value;

            % If the conversion failed, save the value as a string:
            else
                config.(key) = value;

                % If the value starts with a '/', eval the expression and save it:
                if strncmp(value, '/', 1)
                    config.(key) = eval(eraseBetween(value, 1, 1));
                end
            end
        end
    end

    % Closes the file:
    fclose(fid);

    % Defines ground station latitudes:
    if isempty(config.ground_lats)
        config.ground_lats = randi([-config.inclination, config.inclination], 1, config.total_grounds);
    end

    % Defines ground station longitudes:
    if isempty(config.ground_lons)
        config.ground_lons = randi([-180, 180], 1, config.total_grounds);
    end

    % Defines ground station names:
    if isempty(config.ground_names)
        config.ground_names = "GS" + string(1:config.total_grounds);
    end

    % Defines auxiliary values:
    config.radius = config.Re + config.altitude_m;
    config.sats_per_plane = config.total_satellites / config.geometry_planes;

    % If the number of downlink satellites wasn't specified:
    if isempty(config.total_downlinks)

        % Get minimum number of downlinks:
        if isempty(config.downlink_idxs)
            config.downlink_idxs = get_min_downlinks(config);
        end
        config.total_downlinks = length(config.downlink_idxs);
        fprintf("Got %d downlink satellites: ", config.total_downlinks);
        disp(config.downlink_idxs);

    % Defines downlink indexes if they were not specified:
    elseif isempty(config.downlink_idxs)
        config.downlink_idxs = get_best_downlinks(config);
    end

    % Defines plane trajectories if they were not already defined:
    if isempty(config.planes_geo_traj)

        % Chooses 100 as the number of points for the paths:
        path_pts = 100;

        % Defines planes altitudes, center latitude, and amplitudes (slight random deviation):
        plane_alt = repmat(config.plane_alt, [1, path_pts]);
        plane_center_lat_values = randi([-config.inclination, config.inclination], 1, config.total_planes);
        plane_amps = zeros(1, config.total_planes);
        for i = 1:config.total_planes
            max_allowed_amp = config.inclination - abs(plane_center_lat_values(i));
            plane_amps(i) = rand() * max_allowed_amp;
        end
       
        % Defines plane starting angles, time-steps, and trajectories:
        plane_ang_values = randi([-180, 180], 1, config.total_planes);
        plane_ts = linspace(0, config.t_stop, path_pts);
        config.planes_geo_traj = cell(1, config.total_planes);
        for i = 1:config.total_planes
            amp = plane_amps(i);
            center_lat = plane_center_lat_values(i);
            t = linspace(0, 2*pi, path_pts);
            plane_lat = center_lat + amp * sin(t);
            plane_start_ang = plane_ang_values(i);
            plane_lon = linspace(plane_start_ang, plane_start_ang + 360, path_pts);
            coords = [plane_lat; plane_lon; plane_alt]';
            config.planes_geo_traj{i} = geoTrajectory(coords, plane_ts);
        end
    
    % Otherwise, if a file has been provided:
    else
        temp = load(config.planes_geo_traj, "planes_geo_traj");
        config.planes_geo_traj = temp.planes_geo_traj;
    end
end
