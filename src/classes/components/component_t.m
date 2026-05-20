classdef component_t < handle
% Description: Super class for defining a physical node (component).
    
    properties (Access = public)

        % Characteristics:
        id;
        name;
        sc_obj;
        processing_delay;

        % Position:
        pos;

        % Interaction with other components:
        prop_delay;
        tx_delay;
        los;
        ber;
        bps;

        % Simulation:
        time_idx;
    end

    methods

        function obj = component_t(id, sc_obj, config)
        % Description: component_t constructor.
        % Arguments:
        %   id: Component's ID.
        %   sc_obj: Component's satelliteScenario object.
        %   config: Extra configuration parameters (processing delay, component's name, and LLA for position instead of states(sc_obj)).
        % Returns:
        %   obj: component_t object.

            arguments
                id (1, 1) double = missing
                sc_obj (1, 1) = missing
                config.processing_delay (1, 1) double {mustBeNonnegative} = 0
                config.name (1, 1) string = string(id)
                config.first_pos (1, 3) double = [0, 0, 0]
            end

            % Simulation:
            obj.time_idx = 1;

            % Characteristics:
            obj.id = id;
            obj.name = config.name;
            obj.sc_obj = sc_obj;
            obj.processing_delay = to_posix_ns(config.processing_delay);
    
            % Position:
            obj.pos = config.first_pos;

            % Interaction with other components:
            obj.prop_delay = [];
            obj.tx_delay = [];
            obj.los = [];
            obj.ber = [];
            obj.bps = [];
        end

        function update(obj, new_pos, ~)
        % Description: Updates the component.
        % Arguments:
        %   obj: component_t object.
        %   new_pos: New position.
        %   sim: simulation_t object.

            % Updates values:
            obj.time_idx = obj.time_idx + 1;
            obj.pos = new_pos;
            obj.prop_delay = [];
            obj.tx_delay = [];
            obj.los = [];
            obj.ber = [];
            obj.bps = [];
        end
    end
end