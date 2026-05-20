% Setup:
clear;
clc;

% Define log file:
log_file = 'result.log';

% Read all lines:
fid = fopen(log_file, 'r');
if fid == -1
    error('Cannot open log file.');
end
log_lines = textscan(fid, '%s', 'Delimiter', '\n');
log_lines = log_lines{1};

% Close file:
fclose(fid);

% Read all lines:
fid = fopen("result2.log", 'w');
if fid == -1
    error('Cannot open log file.');
end

% Patterns:
finding = "LEO47";
exclude = "MSG\d{1,3}-\d{1,6}-\d{1,3}";

% Matching function:
check_match = @(line, pattern) regexp(line, pattern, 'match');
min_time = 1758193812444389820;
max_time = 1758193812944389820;

% For each line:
for i = 1:length(log_lines)

    % Gets line:
    line = log_lines{i};

    % Checks for finding without excludes:
    time_cell = check_match(line, "\d{19}");
    time = str2double(time_cell{1});
    if ~isempty(check_match(line, finding)) && isempty(check_match(line, exclude)) && time >= min_time && time < max_time
        fprintf(fid, "%s\n", line);
    end
end

% Closes file:
fclose(fid);