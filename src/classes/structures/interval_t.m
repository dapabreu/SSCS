classdef interval_t < handle
% Description: Interval object that "simulates" occupied time for the components.
    
    properties (Access = public)

        % Next available time:
        tail int64
    end
    
    methods
        function obj = interval_t(base)
        % Description: interval_t constructor.
        % Arguments:
        %   base: Base time value.
        % Returns:
        %   obj: interval_t object.

            arguments
                base int64 = 0
            end

            % Assign base value as the next available time:
            obj.tail = int64(base);
        end
        
        function [first, last] = increment(obj, begin, value)
        % Description: Increments the next available time for the component.
        % Arguments:
        %   obj: interval_t object.
        %   begin: New base time value.
        %   value: Occupied time.
        % Returns:
        %   first: First occupied instance.
        %   last: Last occupied instance.

            % Get next available time after applying new base time:
            obj.tail = max(obj.tail, begin);

            % Get first and last values:
            first = obj.tail;
            obj.tail = obj.tail + value;
            last = obj.tail;
        end
    end
end

