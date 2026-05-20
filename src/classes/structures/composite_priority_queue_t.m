classdef composite_priority_queue_t < priority_queue_t
% Description: Priority queue object that orders elements (ascending or descending) based on a property.
    
    properties (Access = public)

        % Sorting property:
        property
    end
   
    methods
        function obj = composite_priority_queue_t(type, property, config)
        % Description: simple_priority_queue_t constructor.
        % Arguments:
        %   type: Element type to store.
        %   property: Property to order
        %   config: Extra configuration values: initial size, size limit, and type of order (asc or desc).
        % Returns:
        %   obj: simple_priority_queue_t object.

            arguments
                type {mustBeNonmissing} = missing
                property (1, 1) string {mustBeNonempty} = string(missing)
                config.size (1, 1) double {mustBeGreaterThanOrEqual(config.size, 4)} = 32
                config.limit (1, 1) double = 0
                config.order (1, 1) string {mustBeMember(config.order, {'asc', 'desc'})} = "desc"
            end

            % Checks if property is valid:
            if ~isprop(type, property)
                error("Property '%s' has to belong to provided class", property);
            end

            % Assigns values:
            obj@priority_queue_t(type, size=config.size, limit=config.limit, order=config.order);
            obj.property = property;
        end

        function value = get_compare_value(obj, element)
        % Description: Get the comparable value of an element.
        % Arguments:
        %   obj: Priority queue.
        %   element: Element to get the comparable value from.
        % Returns:
        %   value: Comparable value.

            value = element.(obj.property);
        end
    end
end

