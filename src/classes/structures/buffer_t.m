classdef buffer_t < handle
% Description: Buffer object that stores messages using a priority queue (ordered by time of arrival).
    
    properties (Access = public)

        % Size of the buffer:
        buff_size;

        % Buffer:
        buffer;
    end
    
    methods

        function obj = buffer_t(limit)
        % Description: buffer_t constructor.
        % Arguments:
        %   limit: Buffer size.
        % Returns:
        %   obj: buffer_t object.

            arguments
                limit (1, 1) double {mustBeNonnegative} = 0
            end

            % Defines values:
            obj.buff_size = limit;
            if limit ~= 0
                obj.buffer = composite_priority_queue_t(message_t, 't_arrival', limit=limit, order='asc', size=limit);
            else
                obj.buffer = composite_priority_queue_t(message_t, 't_arrival', limit=limit, order='asc');
            end
        end
        
        function tf = insert(obj, message)
        % Description: Try inserting a message in the buffer.
        % Arguments:
        %   obj: buffer_t object.
        %   message: Message to insert.
        % Returns:
        %   tf: Indicates insertion success (true - inserted, false - not inserted, limit exceeded).

            tf = obj.buffer.push(message);
        end

        function [message, tf] = remove(obj)
        % Description: Try removing a message from the buffer.
        % Arguments:
        %   obj: buffer_t object.
        % Returns:
        %   message: Removed message (or missing if empty).
        %   tf: Indicates removal success (true - removed, false - not removed, is empty).

            [message, tf] = obj.buffer.pop();
        end

        function [message, tf] = peek(obj)
        % Description: Try returning the first message of the buffer.
        % Arguments:
        %   obj: buffer_t object.
        % Returns:
        %   value: First message (or missing if empty).
        %   tf: Indicates whether the buffer is empty (true - empty, false - not empty).

            [message, tf] = obj.buffer.peek();
        end

        function tf = is_empty(obj)
        % Description: Checks if the buffer is empty.
        % Arguments:
        %   obj: buffer_t object.
        % Returns:
        %   tf: Indicates whether the buffer is empty (true - empty, false - not empty).

            tf = obj.buffer.is_empty();
        end

        function clear(obj)
        % Description: Clears the buffer.
        % Arguments:
        %   obj: buffer_t object.

            obj.buffer.clear();
        end

        function num = get_occupied(obj)
        % Description: Gets number of occupied slots.
        % Arguments:
        %   obj: buffer_t object.
        % Returns:
        %   num: Number of occupied slots in the priority queue.

            num = obj.buffer.get_occupied();
        end
    end
end

