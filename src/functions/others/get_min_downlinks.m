function best_downlinks = get_min_downlinks(config)
% Description: Selects the minimum set of satellites for downlink needed for 100% coverage.
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
    best_downlinks = [];  % Selected satellites.
    coverage = false(1, size(sat_los, 2));  % Total coverage over time from selected satellites.
    num_sats = size(sat_los, 1);

    % For each selection:
    for i = 1:num_sats

        % Check if 100% coverage:
        if all(coverage)
            break;
        end

        % Initialize variables:
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
        if best_sat == 0 || best_gain == 0
            break;
        end
        
        % Adds the current best satellite:
        best_downlinks = [best_downlinks, best_sat];

        % Updates coverage:
        coverage = coverage | sat_los(best_sat, :);
    end

    % Sort the selected downlink indexes:
    best_downlinks = sort(best_downlinks);

    % Warn if insufficient coverage:
    if ~all(coverage)
        coverage_pct = (sum(coverage) / total_times) * 100;
        warning('Only achieved %.2f%% coverage with %d satellites.', coverage_pct, numel(best_downlinks));
    end
end
