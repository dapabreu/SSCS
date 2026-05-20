function los = has_los_down(gs, sats, min_elev, time)
% Description: Calculates LoS for downlinks.
% Arguments:
%   gs: Ground Station object.
%   sats: Satellite objects.
%   min_elev: Minimum elevation for LoS.
%   time: Datetime to check.
% Returns:
%   los: Logical array.

    % Gets elevation values:
    [~, elevations, ~] = aer(gs, sats, time);

    % Gets final LoS array:
    los = elevations >= min_elev;
end