classdef (Abstract) priority_queue_t < handle
% Description: Priority queue object that orders elements (ascending or descending) based on a comparable value.
    
    properties (Access = public)

        % Type of element:
        type

        % Elements:
        values

        % Sorting order:
        order

        % Initial (minimum) size:
        base_size

        % Current size:
        size

        % Size limit:
        limit

        % Current inserting position:
        tail
    end

    methods (Abstract)

        value = get_compare_value(obj, element);
        % Description: Get the comparable value of an element.
        % Arguments:
        %   obj: Priority queue.
        %   element: Element to get the comparable value from.
        % Returns:
        %   value: Comparable value.

    end
    
    methods

        function obj = priority_queue_t(type, config)
        % Description: priority_queue_t constructor.
        % Arguments:
        %   type: Element type to store.
        %   config: Extra configuration values: initial size, size limit, and type of order (asc or desc).
        % Returns:
        %   obj: priority_queue_t object.

            arguments
                type {mustBeNonmissing} = missing
                config.size (1, 1) double {mustBeGreaterThanOrEqual(config.size, 4)} = 32
                config.limit (1, 1) double = 0
                config.order (1, 1) string {mustBeMember(config.order, {'asc', 'desc'})} = "desc"
            end

            % Sets values:
            obj.type = type;
            obj.order = config.order;
            obj.size = 2^nextpow2(config.size);
            obj.base_size = obj.size;
            obj.tail = 1;
            obj.limit = config.limit;
            values(obj.size) = type;
            obj.values = values;
        end
        
        function tf = push(obj, value)
        % Description: Try inserting an element in the priority queue.
        % Arguments:
        %   obj: priority_queue_t object.
        %   value: Element to insert.
        % Returns:
        %   tf: Indicates insertion success (true - inserted, false - not inserted, limit exceeded).

            % Checks the priority queue's limit:
            tf = obj.limit < 1 || obj.tail <= obj.limit;

            % If the element can be inserted:
            if tf

                % If the new element is placed at the last position:
                if obj.tail >= obj.size

                    % Increment the size to the next power of 2:
                    new_size = 2^nextpow2(obj.size + 1);
                    obj.values((obj.size + 1):new_size) = obj.type;
                    obj.size = new_size;
                end

                % Inserts the value:
                obj.values(obj.tail) = value;

                % Corrects the heap:
                heapify(obj, obj.tail);
                obj.tail = obj.tail + 1;
            end
        end

        function [value, tf] = pop(obj)
        % Description: Try removing an element from the priority queue.
        % Arguments:
        %   obj: priority_queue_t object.
        % Returns:
        %   value: Removed element (or missing if empty).
        %   tf: Indicates removal success (true - removed, false - not removed, is empty).

            % Assigns initial value:
            value = missing;

            % If the priority queue isn't empty:
            tf = ~is_empty(obj);
            if tf

                % Get the value:
                value = obj.values(1);

                % Correct the heap:
                obj.tail = obj.tail - 1;
                obj.values(1) = obj.values(obj.tail);
                heapify(obj, 1);

                % If the new size is smaller than 1/4 of the allocated size and we can still decrement the size:
                if obj.tail <= 0.25 * obj.size && obj.size > obj.base_size

                    % Decrement the size to the previous power of 2:
                    obj.size = 2^nextpow2(max(obj.base_size, 0.5 * obj.size));
                    obj.values((obj.size + 1):end) = [];
                end
            end
        end

        function heapify(obj, modified_idx)
        % Description: Corrects the priority queue using heapification steps.
        % Arguments:
        %   obj: priority_queue_t object.
        %   modified_idx: Position that was altered.

            % If it was a removal (the top of the heap was modified to be the previously last element):
            if modified_idx == 1

                % Initializes the values:
                parent = 1;
                needs_update = true;

                % While the element isn't in place:
                while needs_update

                    % Updates stopping condition to exit the loop:
                    needs_update = false;

                    % If the left child is valid:
                    idx = parent * 2;
                    if idx < obj.tail

                        % Gets the values:
                        left_val = obj.get_compare_value(obj.values(idx));
                        switch_val = left_val;
                        if idx + 1 < obj.tail
                            right_val = obj.get_compare_value(obj.values(idx + 1));
                        end
                        parent_val = obj.get_compare_value(obj.values(parent));

                        % If the right child exists and has priority over the left child:
                        if idx + 1 < obj.tail && ((strcmp(obj.order, "asc") && right_val < left_val) || (strcmp(obj.order, "desc") && right_val > left_val))
                            
                            % Update the chosen child to be the right child:
                            switch_val = right_val;
                            idx = idx + 1;
                        end

                        % If the chosen child needs to switch with the parent:
                        if (strcmp(obj.order, "asc") && switch_val < parent_val) || (strcmp(obj.order, "desc") && switch_val > parent_val)
                            
                            % Updates stopping condition to continue in the loop:
                            needs_update = true;
                        end

                        % If the element was not in place yet:
                        if needs_update

                            % Change the element to the corresponding child:
                            temp_val = obj.values(parent);
                            obj.values(parent) = obj.values(idx);
                            obj.values(idx) = temp_val;
                            parent = idx;
                        end
                    end
                end

            % If it was an insertion:
            else

                % Initialize the son node:
                son = modified_idx;

                % Get the parent of the son:
                parent = floor(son / 2);

                % While the son needs to be swapped with the parent:
                while parent >= 1

                    % Get both values:
                    par_val = obj.get_compare_value(obj.values(parent));
                    son_val = obj.get_compare_value(obj.values(son));

                    % If the son needs to be swapped with the parent:
                    if (strcmp(obj.order, "asc") && son_val < par_val) || (strcmp(obj.order, "desc") && son_val > par_val)

                        % Switch the son and parent:
                        temp_val = obj.values(parent);
                        obj.values(parent) = obj.values(son);
                        obj.values(son) = temp_val;
                        son = parent;
                        parent = floor(son / 2);

                    % If the son is in place:
                    else

                        % End the loop:
                        break;
                    end
                end
            end
        end

        function [value, tf] = peek(obj)
        % Description: Try returning the first value of the priority queue.
        % Arguments:
        %   obj: priority_queue_t object.
        % Returns:
        %   value: First element (or missing if empty).
        %   tf: Indicates whether the priority queue is empty (true - empty, false - not empty).

            % Initializes the value:
            value = missing;

            % If the priority queue isn't empty:
            tf = ~is_empty(obj);
            if tf

                % Assign the value:
                value = obj.values(1);
            end
        end

        function empty = is_empty(obj)
        % Description: Checks if the priority queue is empty.
        % Arguments:
        %   obj: priority_queue_t object.
        % Returns:
        %   empty: Indicates whether the priority queue is empty (true - empty, false - not empty).

            empty = obj.tail == 1;
        end

        function clear(obj)
        % Description: Clears the priority queue.
        % Arguments:
        %   obj: priority_queue_t object.

            obj.tail = 1;
            obj.size = obj.base_size;
            value_arr(obj.size) = obj.type;
            obj.values = value_arr;
        end

        function num = get_occupied(obj)
        % Description: Gets number of occupied slots.
        % Arguments:
        %   obj: priority_queue_t object.
        % Returns:
        %   num: Number of occupied slots in the priority queue.

            num = obj.tail - 1;
        end
    end
end

