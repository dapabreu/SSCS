function config = create_config(parameters_file, link_data_file, failure_data_file, save_folder)
% Description: Builds the configuration struct.
% Arguments:
%   parameters_file: File that contains the simulation parameters.
%   link_data_file: File that contains all links' parameters.
%   link_data_file: File that contains all failure parameters.
%   save_folder: Folder to add the statistics.
% Returns:
%   config: Configuration struct.

    % Reads and saves the simulation's parameters:
    config = create_parameters(parameters_file);

    % If there isn't a backup:
    if isempty(config.backup)

        % Reads and saves the links' parameters:
        config.link_data = create_links(link_data_file);

        % Reads and saves the failure scenario parameters:
        config.failure_data = create_failure(failure_data_file);
    
        % Defines the current time string for the log file:
        config.sim_start_time = datetime('now');
        config.curr_time_str = string(config.sim_start_time, 'yyyy-MM-dd_HH-mm-ss');
    
        % Defines statistics directory:
        config.stats_dir = save_folder + config.curr_time_str + "_stats/";
    
        % Tries creating the statistics folder:
        if ~isfolder(config.stats_dir)
            status = mkdir(config.stats_dir);
    
            % Throws an error if the creation failed:
            if ~status
                error("Unable to setup statistics folder");
            end
    
            % Tries creating the backup folder:
            status = mkdir(config.stats_dir + "backup/");
        
            % Throws an error if the creation failed:
            if ~status
                error("Unable to setup backup folder");
            end
        end

    % If there's a backup:
    else

        % Saves backup:
        backup = config.backup;

        % Load the backup's config:
        temp = load(config.backup + "backup/config.mat");

        % Assigns backup's config:
        config = temp.config;
        config.backup = backup;
    end

    % Check validity of failure scenario:
    if ~isfield(config.failure_data, config.failure_scenario)
        error("Specified failure scenario does not exist");
    end
end

