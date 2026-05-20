classdef bucket_queue_t < handle
% Description: Bucket (dictionary pointing to arrays) queue object.

    properties (Access = public)

        % Map that has an array of elements per key:
        buckets containers.Map;

        % Priority queue that has each of every active key:
        bucket_keys;

        % Elements' comparable parameter:
        comp_param;

        % Number of elements:
        num_elems;
    end


    methods

        function obj = bucket_queue_t(config)
        % Description: bucket_queue_t constructor.
        % Returns:
        %   obj: bucket_queue_t object.

        arguments
            config.key_type (1, 1) string = "int64";
            config.key_buffer = simple_priority_queue_t(int64(0), order='asc');
            config.comp_param = missing;
        end

            % Sets values:
            obj.buckets = containers.Map('KeyType', config.key_type, 'ValueType', 'any');
            obj.bucket_keys = config.key_buffer;
            obj.comp_param = config.comp_param;
            obj.num_elems = 0;
        end

        function push(obj, elems)
        % Description: Inserts one or more elements in the bucket queue. If there are multiple elements, they must have the same value for their comparable parameter.
        % Arguments:
        %   obj: bucket_queue_t object.
        %   elems: Element(s) to insert.

            % Gets the comparable parameter's value:
            val = get_comp_param(obj, elems(1));

            % Verifies that all elements have the same comparable parameter's value:
            for elem = elems
                if get_comp_param(obj, elem) ~= val
                    error("Provided elements must have the same comparable parameter's value");
                end
            end

            % If this bucket doesn't exist, create it:
            if ~isKey(obj.buckets, val)
                obj.buckets(val) = elems;
                obj.bucket_keys.push(val);

            % If this bucket exists, append the elements:
            else
                bucket = obj.buckets(val);
                bucket = [bucket, elems];
                obj.buckets(val) = bucket;
            end

            % Increment number of elements:
            obj.num_elems = obj.num_elems + numel(elems);
        end

        function value = pop(obj)
        % Description: Tries removing the first element from the bucket queue.
        % Arguments:
        %   obj: bucket_queue_t object.
        % Returns:
        %   value: Removed element (or missing if empty).

            % Assigns value:
            value = missing;

            % If the queue isn't empty:
            if ~obj.is_empty()

                % Get first bucket:
                t = obj.bucket_keys.peek();
                bucket = obj.buckets(t);
    
                % Pop first value from that bucket:
                value = bucket(1);
                bucket(1) = [];
    
                % If the bucket is empty, clear it:
                if isempty(bucket)
                    remove(obj.buckets, t);
                    obj.bucket_keys.pop();

                % Otherwise update it:
                else
                    obj.buckets(t) = bucket;
                end

                % Decrement number of elements:
                obj.num_elems = obj.num_elems - 1;
            end
        end

        function value = peek(obj)
        % Description: Try returning the first element of the bucket queue.
        % Arguments:
        %   obj: bucket_queue_t object.
        % Returns:
        %   value: First element (or missing if empty).

            % Assigns value:
            value = missing;

            % If the queue isn't empty, return the first element:
            if ~obj.is_empty()
                t = obj.bucket_keys.peek();
                bucket = obj.buckets(t);
                value = bucket(1);
            end
        end

        function value = find(obj, key)
        % Description: Try finding an element in the bucket queue.
        % Arguments:
        %   obj: bucket_queue_t object.
        %   key: Key to search for.
        % Returns:
        %   value: Found element (or missing otherwise).

            % Try finding the value:
            try
                value = obj.buckets(key);

            % If the operation failed:
            catch ME

                % If there isn't a matching key:
                if ME.identifier == "MATLAB:Containers:Map:NoKey"
                    value = missing;

                % If another error was thrown:
                else
                    rethrow(ME);
                end
            end
        end

        function alter(obj, key, value)
        % Description: Try altering an element in the bucket queue.
        % Arguments:
        %   obj: bucket_queue_t object.
        %   key: Key to search for.
        %   value: New value for key.
        % Returns:
        %   value: Found element (or missing otherwise).

            % Tries gathering the element:
            elem = obj.find(key);

            % If it does exist:
            if ~ismissing(elem)
                obj.buckets(key) = value;
            end
        end

        function empty = is_empty(obj)
        % Description: Checks if the bucket queue is empty.
        % Arguments:
        %   obj: bucket_queue_t object.
        % Returns:
        %   empty: Indicates whether the bucket queue is empty (true - empty, false - not empty).

            empty = obj.num_elems == 0;
        end

        function value = get_comp_param(obj, elem)
        % Description: Gets the comparable parameter of an element.
        % Arguments:
        %   obj: bucket_queue_t object.
        %   elem: Element.
        % Returns:
        %   value: Value of the element's comparable parameter.

            % If there isn't a specified parameter to extract the value, return the element itself:
            if ismissing(obj.comp_param)
                value = elem;

            % Otherwise return the specified parameter:
            else
                value = elem.(obj.comp_param);
            end
        end

        function clear(obj)
        % Description: Clears the bucket queue.
        % Arguments:
        %   obj: bucket_queue_t object.

            remove(obj.buckets, keys(obj.buckets));
            obj.bucket_keys.clear();
            obj.num_elems = 0;
        end

        function num = get_occupied(obj)
        % Description: Gets number of occupied slots.
        % Arguments:
        %   obj: bucket_queue_t object.
        % Returns:
        %   num: Number of occupied slots in the bucket queue.

            num = obj.num_elems;
        end
    end
end
