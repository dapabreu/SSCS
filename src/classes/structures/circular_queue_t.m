classdef circular_queue_t < handle
% Description: Circular queue object that swaps older elements for newer ones.

    properties (Access = public)

        % Maximum capacity:
        capacity

        % Stored data:
        data (1, :) cell

        % Next insertion position:
        pointer
    end
    
    methods

        function obj = circular_queue_t(capacity)
        % Description: circular_queue_t constructor.
        % Arguments:
        %   capacity: Maximum capacity for the circular queue.
        % Returns:
        %   obj: circular_queue_t object.

            arguments
                capacity (1, 1) double = 300
            end

            % Set values:
            obj.capacity = capacity;
            obj.pointer = 1;
            obj.data = repmat({missing}, 1, obj.capacity);
        end
        
        function push(obj, value)
        % Description: Insert a new value into the circular queue.
        % Arguments:
        %   obj: circular_queue_t object.
        %   value: New value to insert.

            % Insert value:
            obj.data{obj.pointer} = value;

            % Increment next position:
            obj.pointer = obj.pointer + 1;
            if obj.pointer > obj.capacity
                obj.pointer = 1;
            end
        end
        
        function tf = find(obj, value)
        % Description: Search for a value in the circular queue.
        % Arguments:
        %   obj: circular_queue_t object.
        %   value: Value to search for.
        % Returns:
        %   tf: Indicates whether the element was found (true - it was, false - it wasn't).

            % Initializes return value:
            tf = false;

            % For every value:
            for val = 1:obj.capacity

                % If the value is found:
                if obj.data{val} == value

                    % Return true:
                    tf = true;
                    return;
                end
            end
        end
    end
end
