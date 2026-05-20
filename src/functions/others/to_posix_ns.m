function unix_ns = to_posix_ns(input)
% Description: Convert datetime or scalar seconds to POSIX (UNIX) time in nanoseconds.
% Arguments:
%   input: Datetime or scalar seconds.
% Returns:
%   unix_ns: Converted value into POSIX time in nanoseconds.

    % If missing:
    if ismissing(input)
        unix_ns = 0;
   
    % Otherwise:
    else

        % If its a datetime:
        if isa(input, 'datetime')
    
            % By default, ensure UTC timezone for consistency:
            if isempty(input.TimeZone)
                input.TimeZone = 'UTC';
            end
            unix_seconds = posixtime(input);
    
        % If its in seconds:
        elseif isnumeric(input)
            unix_seconds = double(input);
    
        % If its an invalid type:
        else
            error('Input must be a datetime or numeric (seconds).');
        end
    
        % Convert to nanoseconds
        unix_ns = unix_seconds * int64(1e9);

    end
end
