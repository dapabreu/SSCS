function los = has_los_cross(source, targets, Re)
% Description: Calculates LoS for crosslinks.
% Arguments:
%   source: Source position.
%   targets: Targets' positions.
%   Re: Earth's radius in meters.
% Returns:
%   los: Logical array.

    % Initializes LoS array:
    num_targets = size(targets, 1);
    los = false(1, num_targets);

    % For each target, checks for LoS:
    for t = 1:num_targets
        los(t) = norm((source + targets(t, :)) / 2) >= Re;
    end
end