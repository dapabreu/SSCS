% Setup:
clear;
clc;

% Define log file:
log_file = 'adjacents_path.log';

% Read all lines:
fid = fopen(log_file, 'r');
if fid == -1
    error('Cannot open log file.');
end
log_lines = textscan(fid, '%s', 'Delimiter', '\n');
log_lines = log_lines{1};

% Close file:
fclose(fid);

% Patterns:
id_pattern = 'MSG\d{1,3}-\d{1,6}-\d{1,3}';
tx_pattern = 'MSG\d{1,3}-\d{1,6}-\d{1,3}] Treating TX event from P';
dropped_pattern = 'MSG\d{1,3}-\d{1,6}-\d{1,3}] Dropped';
received_pattern = 'MSG\d{1,3}-\d{1,6}-\d{1,3}] Received';

% Counters:
tx_count = 0;
dropped_count = 0;
received_count = 0;

% Messages:
msgs = dictionary;

% Matching function:
check_match = @(line, pattern) regexp(line, pattern, 'match');

% For each line:
for i = 1:length(log_lines)

    % Gets line:
    line = log_lines{i};

    % Checks transmission:
    if ~isempty(check_match(line, tx_pattern))
        tx_count = tx_count + 1;
        msgs = msgs.insert(check_match(line, id_pattern), i);
    end

    % Checks dropped:
    if ~isempty(check_match(line, dropped_pattern))
        dropped_count = dropped_count + 1;
        msgs = msgs.remove(check_match(line, id_pattern));
    end

    % Checks received:
    if ~isempty(check_match(line, received_pattern))
        received_count = received_count + 1;
        msgs = msgs.remove(check_match(line, id_pattern));
    end
end

% Prints results:
fprintf("Found:\n\t%d broadcasted messages\n\t%d dropped messages\n\t%d received messages\n%d accounted for\n%d missing\nMessages:\n", tx_count, dropped_count, received_count, dropped_count + received_count, tx_count - dropped_count - received_count);
disp(msgs);