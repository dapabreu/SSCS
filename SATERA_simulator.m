%% CLEAN-UP

clear;
clc;
close all;

%% CONFIGURATION

% Folders:
data_folder = "./data/";
code_folder = "./src/";
save_folder = "./stats/";

% Files:
parameters_file = "parameters.txt";
link_data_file = "links.txt";
failure_data_file = "failure.txt";

% Paths:
addpath(genpath(data_folder));
addpath(genpath(code_folder));
addpath(genpath(save_folder));

% Sets up the simulator:
config = create_config(parameters_file, link_data_file, failure_data_file, save_folder);
sc = satelliteScenario(config.t_base, config.t_base + seconds(config.t_stop), config.dt);

% Adds objects to scenario and gets all positions:
[gs_pos, plane_pos, sat_pos] = add_to_scenario(sc, config);

% If there is no backup:
if isempty(config.backup)
    
    % Save as v7.3 .mat (required for memory mapping):
    save(config.stats_dir + 'positions.mat', 'gs_pos', 'plane_pos', 'sat_pos', '-v7.3');
end

% Captures output, if requested:
if config.capture_output
    if ~isfolder(config.stats_dir + "logs/")
        status = mkdir(config.stats_dir + "logs/");
        if ~status
            error("Unable to setup statistics folder");
        end
    end
    diary(config.stats_dir + "logs/output.log");
end

%% SIMULATION

% Create a memmap handle that can be broadcast to worker:
pos_map = parallel.pool.Constant(@() matfile(config.stats_dir + 'positions.mat'));

% Gets backup location:
backup = config.backup;

% Try simulation:
try

    % Gets positions via memory map:
    mf = pos_map.Value;

    % If there is no backup:
    if isempty(backup)

        % Sets current position index:
        curr_pos = 1;
    
        % Creates the simulation:
        sim = simulation_t(config, sc, gs_pos, mf);

    % If there is a backup:
    else

        % Loads simulation object and current position index:
        temp = load(backup + "backup/sim.mat");
        sim = temp.sim;
        curr_pos = temp.curr_pos;
    end

    % Runs the simulation:
    tic;
    sim.run()
    toc

catch ME
    fprintf("[%s] ERROR: %s\n", string(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ME.getReport());
end

% Checks if the user wants to save and exit:
save(config.stats_dir + "backup/config.mat", "config", "-v7.3");
if isfile(config.stats_dir + "backup/stop.txt")
    delete(config.stats_dir + "backup/stop.txt");
end

% Stops capturing output, if necessary:
if config.capture_output
    diary off;
end
