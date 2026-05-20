classdef simple_priority_queue_t < priority_queue_t
% Description: Priority queue object that orders basic elements (ascending or descending).
   
    methods
        function obj = simple_priority_queue_t(type, config)
        % Description: simple_priority_queue_t constructor.
        % Arguments:
        %   type: Element type to store.
        %   config: Extra configuration values: initial size, size limit, and type of order (asc or desc).
        % Returns:
        %   obj: simple_priority_queue_t object.

            arguments
                type {mustBeNonmissing} = missing
                config.size (1, 1) double {mustBeGreaterThanOrEqual(config.size, 4)} = 32
                config.limit (1, 1) double = 0
                config.order (1, 1) string {mustBeMember(config.order, {'asc', 'desc'})} = "desc"
            end

            obj@priority_queue_t(type, size=config.size, limit=config.limit, order=config.order);
        end

        function value = get_compare_value(~, element)
        % Description: Get the comparable value of an element.
        % Arguments:
        %   obj: Priority queue.
        %   element: Element to get the comparable value from.
        % Returns:
        %   value: Comparable value.

            value = element;
        end
    end
end

