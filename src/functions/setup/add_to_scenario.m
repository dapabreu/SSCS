function [gs_pos, plane_pos, sat_pos] = add_to_scenario(sc, config)
% Description: Adds all satellite and ground station objects to the satcom scenario.
% Arguments:
%   sc: Satellite scenario object.
%   config: Simulation's configuration struct.
% Returns:
%   gs_pos: Positions of all ground stations.
%   plane_pos: Positions of all airplanes.
%   sat_pos: Positions of all satellites.

    % Adds ground stations:
    groundStation(sc, config.ground_lats, config.ground_lons, "Name", config.ground_names);

    % Adds airplanes:
    planes = platform(sc, config.planes_geo_traj, "Name", "P");
    
    % Adds satellites:
    if isempty(config.constellation)
        sats = walkerStar(sc, config.radius, config.inclination, config.total_satellites, config.geometry_planes, config.phasing);
    else
        sats = eval(config.constellation);
    end
    
    % If there is no backup:
    if isempty(config.backup)
    
        % Initializes the positions matrix:
        gs_pos = zeros(config.total_grounds, 3);
    
        % Assigns ground stations' positions:
        for g = 1:config.total_grounds
            gs_pos(g, :) = lla2ecef([config.ground_lats(g), config.ground_lons(g), 0]);
        end

        % Get airplane positions:
        plane_pos_orig = states(planes, "CoordinateFrame", "ecef");
        plane_pos = permute(plane_pos_orig, [3, 2, 1]);

        % Get satellite positions:
        sat_pos_orig = states(sats, "CoordinateFrame", "ecef");
        sat_pos = permute(sat_pos_orig, [3, 2, 1]);

    % If there is a backup:
    else

        % Return positions as an empty array:
        temp = load(config.backup + "positions.mat", "gs_pos", "plane_pos", "sat_pos");
        gs_pos = temp.gs_pos;
        plane_pos = temp.plane_pos;
        sat_pos = temp.sat_pos;
    end
end