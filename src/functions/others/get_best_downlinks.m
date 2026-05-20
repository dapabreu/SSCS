function best_downlinks = get_best_downlinks(config)
% Description: Selects best satellites for downlinks.
% Arguments:
%   config: Simulation parameters.
% Returns:
%   best_downlinks: Indices of selected satellites.

    % Creates scenario:
    sc = satelliteScenario(config.t_base, config.t_base + seconds(config.t_stop), config.dt);

    % Adds ground stations:
    grounds = groundStation(sc, config.ground_lats, config.ground_lons);

    % Adds satellites:
    if isempty(config.constellation)
        sats = walkerStar(sc, config.radius, config.inclination, config.total_satellites, config.geometry_planes, config.phasing);
    else
        sats = eval(config.constellation);
    end

    % Auxiliary values:
    total_times = numel(sc.StartTime:seconds(sc.SampleTime):sc.StopTime);
    total_grounds = numel(grounds);

    % Initializes and calculates Line-of-Sight (LoS) matrix: 
    sat_los = false(config.total_satellites, total_times);
    for g = 1:total_grounds
        [~, el, ~] = aer(grounds(g), sats);
        sat_los = sat_los | (el >= config.los_min_elev);
    end

    % Selects the best downlink combination:
    best_downlinks = zeros(1, config.total_downlinks);  % Selected satellites.
    coverage = false(1, size(sat_los, 2));  % Total coverage over time from selected satellites.
    num_sats = size(sat_los, 1);

    % For each selection:
    for d = 1:config.total_downlinks
        best_sat = 0;
        best_gain = 0;

        % For each satellite:
        for s = 1:num_sats
            
            % If we already selected this satellite, move on to the next:
            if ismember(s, best_downlinks)
                continue
            end

            % Compute new coverage this satellite would add:
            new_coverage = sat_los(s, :) & ~coverage;
            gain = sum(new_coverage);
            
            % If this satellite is better than the current best, switch:
            if gain > best_gain
                best_gain = gain;
                best_sat = s;
            end
        end

        % If no satellite was selected:
        if best_sat == 0
            break;
        end
        
        % Adds the current best satellite:
        best_downlinks(d) = best_sat;

        % Updates coverage:
        coverage = coverage | sat_los(best_sat, :);

        % If the satellites cover all times, restart the total coverage and fill it again:
        if all(coverage == true)
            coverage = false(1, size(sat_los, 2));
        end
    end

    % If there are any remaining satellites:
    remaining = sum(best_downlinks == 0);
    if remaining > 0
        remaining_sats = 1:num_sats;
        best_downlinks(config.total_downlinks - remaining + 1:end) = randsample(remaining_sats(~ismember(remaining_sats, best_downlinks)), remaining);
    end

    % Sort the selected downlink indexes:
    best_downlinks = sort(best_downlinks);
end
