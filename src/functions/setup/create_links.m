function link_data = create_links(link_data_file)
% Description: Extracts noise and received powers for all links from a parameter file.
% Arguments:
%   link_data_file: The name of the file containing the link parameters.
% Returns:
%   link_data: A structure containing the calculated data for each link.
    
    % Initialize link_data structure:
    link_data = struct();
    link_names = {'uplink', 'crosslink', 'downlink'};

    % Boltzmann's constant in J/K:
    k = 1.380649e-23;

    % Open the file:
    fid = fopen(link_data_file, 'r');

    % Throws an error if the file couldn't be opened:
    if fid == -1
        error('Cannot open file: %s', link_data_file);
    end
    
    % Read and process the file line by line:
    current_link = '';
    while ~feof(fid)
        line = strtrim(fgetl(fid));

        % Ignore the line if its empty or if its a comment (starts with '%'):
        if isempty(line) || strncmp(line, '%', 1)
            continue;
        end

        % Check for section headers (uplink, crosslink, downlink):
        if endsWith(line, ':')
            current_link = line(1:end-1);
            if ismember(current_link, link_names)

                % Creates the struct for the current link:
                link_data.(current_link) = struct();
            end
            continue;
        end

        % Parse key-value pairs:
        if contains(line, '=')
            tokens = strsplit(line, '=');

            % Throws an error if the line is incorrectly formatted:
            if numel(tokens) ~= 2
                fclose(fid);
                error('Invalid line format: %s.  Expected ''key=value''.', line);
            end

            % Gets the key and value:
            key = strtrim(tokens{1});
            value = strtrim(tokens{2});

            if key == "directions"

                link_data.(current_link).(key) = eval(value);
                
            else

                % Converts the value to a double:
                num_value = str2double(value);
    
                % If the conversion was successful, save the value as a double:
                if ~isnan(num_value)
                    link_data.(current_link).(key) = num_value;
    
                % If the conversion failed, save the value as a string:
                else
                    link_data.(current_link).(key) = value;
                end
            end
        end
    end

    % Closes the file:
    fclose(fid);

    % Perform calculations for each link:
    for i = 1:numel(link_names)
        link_name = link_names{i};

        % Throws an error if the link was not added:
        if ~isfield(link_data, link_name)
            error('Link %s not found in file: %s', link_name, link_data_file);
        end
        
        % Check for the existence of required fields:
        link = link_data.(link_name);
        requiredFields = {'bandwidth_hz', 'frequency_hz' 'power_w', 'tx_antenna_dbi', 'rx_antenna_dbi', 'system_loss_db', 'noise_temperature_k', 'modulation_order', 'modulation_type', 'modulation_extra1', 'modulation_extra2'};
        
        % Throws an error if there are missing fields:
        if ~all(isfield(link, requiredFields))
            error('Missing parameters for link: %s.', link_name);
        end
        
        % Throws an error if there's inconsistencies declaring modulation parameters:
        if isempty(link.modulation_extra1) && ~isempty(link.modulation_extra2)
            error('Defined modulation extra 2 but not 1 for link: %s.', link_name);
        end

        % Calculates and saves bits per symbol:
        link_data.(link_name).bits_per_symbol = log2(link.modulation_order);

        % Calculates and saves received power (dBW):
        pt_dbw = 10 * log10(link.power_w);
        link_data.(link_name).received_power = pt_dbw + link.tx_antenna_dbi + link.rx_antenna_dbi - link.system_loss_db;

        % Calculates and saves noise power (dBW):
        noise_power_watts = k * link.noise_temperature_k * link.bandwidth_hz;
        link_data.(link_name).noise_power = 10 * log10(noise_power_watts);
    end
end
