% Clean:
clear;
clc;
close all;

% Folders:
data_folder = "../data/";
code_folder = "../code/";
save_folder = "../stats/";

% Files:
parameters_files = ["parameters1gs-25pl.txt", "parameters3gs-25pl.txt", "parameters5gs-25pl.txt"];
link_data_file = "links.txt";

% Paths:
addpath(genpath(data_folder));
addpath(genpath(code_folder));
addpath(genpath(save_folder));

for parameters_file = parameters_files

    % Set up config:
    config = create_config(parameters_file, link_data_file, save_folder);
    
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
    downlink_sats = sats(config.downlink_idxs);
    
    % Auxiliary values:
    total_times = numel(sc.StartTime:seconds(sc.SampleTime):sc.StopTime);
    total_grounds = numel(grounds);
    
    % Initializes and calculates Line-of-Sight (LoS) matrix: 
    sat_los = false(config.total_downlinks, total_times);
    for g = 1:total_grounds
        [~, el, ~] = aer(grounds(g), downlink_sats);
        sat_los = sat_los | (el >= config.los_min_elev);
    end
    
    % Present LoS coverage:
    fprintf("Got coverage on %d out of %d times for %dGS-%dPL\n", sum(any(sat_los)), size(sat_los, 2), config.total_grounds, config.total_planes);
end