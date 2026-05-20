classdef tx_event_t < link_event_t
% Description: Transmission event object.

    properties (Access = public)

        % Indicates whether this event should trigger processing events:
        create_proc;
    end

    methods

        function obj = tx_event_t(gen_time, res_time, target, message, source, create_proc)
        % Description: tx_event_t constructor.
        % Arguments:
        %   gen_time: Time of generation for the event.
        %   res_time: Time of resolution for the event.
        %   target: Transmission target.
        %   message: Message being transmitted.
        %   source: Transmission source.
        %   create_proc: Indicates whether this event should trigger processing events.
        % Returns:
        %   obj: tx_event_t object.

            arguments
                gen_time (1, 1) double = missing
                res_time (1, 1) double = missing
                target (1, 1) double = missing
                message (1, 1) message_t = message_t()
                source (1, 1) double = missing
                create_proc (1, 1) logical = true
            end
            
            % Sets values:
            obj@link_event_t(gen_time, res_time, target, message, source);
            obj.create_proc = create_proc;
        end

        function treat_event(obj, sim)
        % Description: Treats a TX event.
        % Arguments:
        %   obj: tx_event_t object.
        %   sim: Simulation object.

            % Get components:
            [source, src_class] = get_component(sim, obj.source);
            target = get_component(sim, obj.target);

            % Get message type:
            msg_type = class(obj.message);

            % Check if component is active:
            if src_class == "satellite_t" && ~source.is_active
                return;
            end

            % Check if component can send:
            if src_class == "satellite_t" && ~source.can_send
                
                % Print packet drop:
                files = [0, 0];
                if sim.config.print_events
                    files(1) = 1;
                end
                if sim.config.log_events
                    files(2) = sim.log_file;
                end
                files(files == 0) = [];
                for file = files
                    fprintf("[%d - MSG%s] Link from %s to %s is inactive, dropping packet (%s)\n", sim.curr_posixtime, obj.message.id, source.name, target.name, msg_type);
                end

                % Updates statistics:
                for stats_algorithm = sim.statistics_algorithms
                    stats_algorithm.drop_packet_inactive_link(sim, obj.message, who);
                end

                return;
            end

            % Print event:
            files = [0, 0];
            if sim.config.print_events
                files(1) = 1;
            end
            if sim.config.log_events
                files(2) = sim.log_file;
            end
            files(files == 0) = [];
            for file = files
                fprintf(file, "[%d - MSG%s] Treating TX event from %s to %s (%s)\n", sim.curr_posixtime, obj.message.id, source.name, target.name, msg_type);
            end

            % Update the BER integrity:
            obj.message.ber_integrity = obj.message.ber_integrity * (1 - source.ber(obj.target));
            if src_class == "satellite_t"
                obj.message.ber_integrity = obj.message.ber_integrity * (1 - source.BER_base);
            end

            % Update hop count:
            obj.message.hops = obj.message.hops + 1;

            % Queue the RX event:
            queue_rx_event(obj, sim, obj.source, obj.message);

            % Remove the message from the buffer and trigger a processing event, if necessary:
            if class(obj.message) == "broadcast_message_t"
                sim.pathing_algorithm.remove_buffer(obj.source);
            end
            if ~sim.pathing_algorithm.is_empty_buffer(obj.source) && obj.create_proc
                queue_proc_event(obj, sim, obj.source);
            end
        end
    end
end

