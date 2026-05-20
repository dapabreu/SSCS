function failure_data = create_failure(failure_data_file)
% Description: Extracts all failure data from a parameter file.
% Arguments:
%   failure_data_file: The name of the file containing the failure parameters.
% Returns:
%   failure_data: A structure containing the data for each failure scenario.
    
    % Initialize failure_data structure:
    failure_data = struct();
    link_names = {'nominal', 'weak', 'moderate', 'severe'};

    % Open the file:
    fid = fopen(failure_data_file, 'r');

    % Throws an error if the file couldn't be opened:
    if fid == -1
        error('Cannot open file: %s', failure_data_file);
    end
    
    % Read and process the file line by line:
    current_failure = '';
    while ~feof(fid)
        line = strtrim(fgetl(fid));

        % Ignore the line if its empty or if its a comment (starts with '%'):
        if isempty(line) || strncmp(line, '%', 1)
            continue;
        end

        % Check for section headers (nominal, weak, moderate, severe):
        if endsWith(line, ':')
            current_failure = line(1:end-1);
            if ismember(current_failure, link_names)

                % Creates the struct for the current scenario:
                failure_data.(current_failure) = struct();
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

            % Converts the value to a double:
            num_value = str2double(value);

            % If the conversion was successful, save the value as a double:
            if ~isnan(num_value)
                failure_data.(current_failure).(key) = num_value;

            % If the conversion failed, save the value as a string:
            else
                failure_data.(current_failure).(key) = value;
            end
        end
    end

    % Closes the file:
    fclose(fid);
end
