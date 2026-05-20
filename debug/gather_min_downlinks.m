% Clean:
clear;
clc;
close all;

% Folders:
data_folder = "../data/";
code_folder = "../code/";
save_folder = "../stats/";

% Files:
parameters_file = "parameters.txt";
link_data_file = "links.txt";

% Paths:
addpath(genpath(data_folder));
addpath(genpath(code_folder));
addpath(genpath(save_folder));

% Set up config:
config = create_config(parameters_file, link_data_file, save_folder);

% Get best downlinks for 5 GS:
downlink_idxs = get_min_downlinks(config);
fprintf("Got %d downlink satellites for 5 ground stations: ", length(downlink_idxs));
disp(downlink_idxs);

% Get best downlinks for 3 GS:
config.ground_lats = config.ground_lats(1:3);
config.ground_lons = config.ground_lons(1:3);
downlink_idxs = get_min_downlinks(config);
fprintf("Got %d downlink satellites for 3 ground stations: ", length(downlink_idxs));
disp(downlink_idxs);

% Get best downlinks for 1 GS:
config.ground_lats = config.ground_lats(2);
config.ground_lons = config.ground_lons(2);
downlink_idxs = get_min_downlinks(config);
fprintf("Got %d downlink satellites for 1 ground stations: ", length(downlink_idxs));
disp(downlink_idxs);