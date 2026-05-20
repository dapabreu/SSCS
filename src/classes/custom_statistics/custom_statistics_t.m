classdef custom_statistics_t < handle & matlab.mixin.Heterogeneous
% Description: Super class for gathering statistics for each and all timesteps.
    
    properties (Access = public)

        % Statistics algorithm:
        name;
        file_name;
    end

    methods (Static, Sealed, Access = protected)
        function default_object = getDefaultScalarElement
            default_object = basic_statistics_t;
        end
    end
    
    methods
        function obj = custom_statistics_t(~)
        % Description: custom_statistics_t constructor.
        % Arguments:
        %   config: Simulator's configuration struct.
        % Returns:
        %   obj: custom_statistics_t object.
        arguments
            ~
        end

            % Statistics algorithm:
            obj.name = "Custom Statistics Algorithm";
            obj.file_name = "custom_statistics_algorithm";
        end
    end

    methods (Abstract)
        
        show_stats(obj, sim, dir)
        % Description: Shows the algorithms' statistics.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   dir: Directory to save the statistics to.

        reset_stats(obj)
        % Description: Resets the algorithms' statistics for the current timeslice.
        % Arguments:
        %   obj: custom_statistics_t object.

        treated_event(obj, sim, event)
        % Description: Updates statistics upon treating an event.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   event: Treated event.

        new_broadcast(obj, sim, message, count)
        % Description: Updates statistics upon broadcasting a new message from a plane.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   message: Received message.
        %   count: Number of messages that will be received.

        new_routing_packets(obj, sim, message, count)
        % Description: Updates statistics upon sending routing packets.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   message: Message to send.
        %   count: Number of messages that will be transmitted.

        add_busy_time(obj, sim, target, time)
        % Description: Updates statistics when a component is busy.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   target: Affected component's ID.
        %   time: Total busy time.

        reception(obj, sim, message, target)
        % Description: Updates statistics upon reception in a component.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   message: Received message.
        %   target: Receiving component's ID.

        drop_packet_no_los(obj, sim, message, target)
        % Description: Updates statistics upon dropping a packet due to having no LoS to other components.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   message: Message to drop.
        %   target: Affected component's ID.

        drop_packet_buffer_full(obj, sim, message, target)
        % Description: Updates statistics upon dropping a packet due to having no more buffer capacity.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   message: Message to drop.
        %   target: Affected component's ID.

        drop_packet_expired(obj, sim, message, target)
        % Description: Updates statistics upon dropping a packet due to its flight time expiring.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   message: Message to drop.
        %   target: Affected component's ID.

        drop_packet_proc_inactive_target(obj, sim, count, target)
        % Description: Updates statistics upon dropping a packet due to the target being inactive for processing.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   count: Number of affected packets.
        %   target: Affected component's ID.

        drop_packet_rx_inactive_target(obj, sim, message, target)
        % Description: Updates statistics upon dropping a packet due to the target being inactive in receptions.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   message: Message to drop.
        %   target: Affected component's ID.

        drop_packet_inactive_link(obj, sim, message, target)
        % Description: Updates statistics upon dropping a packet due to the link to the target being inactive.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   message: Message to drop.
        %   target: Affected component's ID.

    end
end

