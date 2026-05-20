function [curr_idx, plane_pos, sat_pos] = get_positions(mf, target_ns, init_datetime, dt)
% Description: Gets the positions of the aircraft and satellites at a given time through linear interpolation.
% Arguments:
%   mf: Aircraft and satellite position memory-mapped file.
%   target_ns: Target time in POSIX nanoseconds.
%   init_datetime: Simulation starting datetime.
%   dt: Simulation timestep.
% Returns:
%   curr_idx: Current index on the global positions table.
%   plane_pos: Aircraft positions.
%   sat_pos: Satellite positions.

    % Convert datetime and timestep to nanoseconds:
    init_ns = int64(posixtime(init_datetime) * 1e9);
    step_ns = int64(dt * 1e9);
    
    % Get boundary indexes:
    curr_idx = max(1, min(floor(double(target_ns - init_ns) / double(step_ns)) + 1, size(mf.sat_pos, 2) - 1));
    next_idx = curr_idx + 1;

    % Get interpolation coefficient:
    curr_timeslice = init_ns + step_ns * (curr_idx - 1);
    coeff = double(target_ns - curr_timeslice) / double(step_ns);

    % Perform linear interpolation to get the positions:
    plane_pos = squeeze((mf.plane_pos(:, next_idx, :) - mf.plane_pos(:, curr_idx, :)) * coeff + mf.plane_pos(:, curr_idx, :));
    sat_pos = squeeze((mf.sat_pos(:, next_idx, :) - mf.sat_pos(:, curr_idx, :)) * coeff + mf.sat_pos(:, curr_idx, :));
end
