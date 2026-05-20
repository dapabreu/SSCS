function planes = create_planes(sc, config, plane_pos)
% Description: Builds plane_t array.
% Arguments:
%   sc: Satellite scenario object.
%   config: Configuration struct.
%   plane_pos: Airplanes' positions.
% Returns:
%   planes: plane_t array.

    % Initializes the plane_t array:
    planes(config.total_planes) = plane_t;

    % Creates the platform scenario objects:
    pls = platform(sc, config.planes_geo_traj, "Name", "P");
    for p = 1:config.total_planes

        % Creates the plane:
        planes(p) = plane_t(config.total_grounds + p, pls(p), name="P" + p, first_pos=plane_pos(p, :));
    end
end

