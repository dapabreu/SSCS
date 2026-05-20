classdef (Abstract) custom_pathing_t < handle & matlab.mixin.Heterogeneous
% Description: Super class for defining a custom pathing algorithm.

    properties (Access = public)

        % Characteristics:
        name;
        file_name;

        % Extra parameters:
        send (1, :) cell;
        buffers (1, :) buffer_t;
        intervals (1, :) interval_t;  % Interval to coordinate events.

        % Events:
        event_queue;
    end

    methods (Static, Sealed, Access = protected)
        function default_object = getDefaultScalarElement
            default_object = shortest_path_t;
        end
    end
    
    methods (Abstract)
        update(obj, sim)
        % Description: Updates the algorithm.
        % Arguments:
        %   obj: Custom algorithm.
        %   sim: Simulation object.

        action(obj, sim, routing_message, target)
        % Description: Processes a routing message.
        % Arguments:
        %   obj: Custom algorithm.
        %   sim: Simulation object.
        %   routing_message: Routing message to process.
        %   target: Component ID that is processing the routing message.
    end

    methods

        function obj = custom_pathing_t(config)
        % Description: custom_pathing_t constructor.
        % Arguments:
        %   config: Simulator's configuration struct.
        % Returns:
        %   obj: custom_pathing_t object.
        
            arguments
                config (1, 1) struct = struct("total_grounds", 3, "total_planes", 225, "total_satellites", 200, "sat_buffer", 300, "t_base", datetime("now", "TimeZone", "UTC"));
            end

            % Characteristics:
            obj.name = "Custom Pathing Algorithm";
            obj.file_name = "custom_pathing_algorithm";
            obj.send = repmat({NaN}, 1, config.total_grounds + config.total_planes + config.total_satellites);
            obj.buffers(config.total_grounds + config.total_planes + config.total_satellites) = buffer_t;
            obj.intervals(config.total_grounds + config.total_planes + config.total_satellites) = interval_t;
            for s = 1:config.total_satellites
                obj.buffers(config.total_grounds + config.total_planes + s) = buffer_t(config.sat_buffer);
                obj.intervals(config.total_grounds + config.total_planes + s) = interval_t(to_posix_ns(config.t_base));
            end

            % Events:
            obj.event_queue = event_queue_t();
        end

        function [message, tf] = peek_buffer(obj, idx)
        % Description: Tries getting the first message in a component's buffer.
        % Arguments:
        %   obj: custom_pathing_t object.
        %   idx: Specific component.
        % Returns:
        %   message: First message (or missing).
        %   tf: Indicates if the message was added successfully.

            [message, tf] = obj.buffers(idx).peek();
        end

        function tf = insert_buffer(obj, idx, message)
        % Description: Tries inserting a message in a component's buffer.
        % Arguments:
        %   obj: custom_pathing_t object.
        %   idx: Specific component.
        %   message: Message to insert.
        % Returns:
        %   tf: Indicates if the message was added successfully.

            tf = obj.buffers(idx).insert(message);
        end

        function [message, tf] = remove_buffer(obj, idx)
        % Description: Tries removing a message from a component's buffer.
        % Arguments:
        %   obj: custom_pathing_t object.
        %   idx: Specific component.
        % Returns:
        %   message: Removed message (or missing if empty).
        %   tf: Indicates if the buffer was empty.

            [message, tf] = obj.buffers(idx).remove();
        end

        function clear_buffer(obj, idx, sim, failure)
        % Description: Clears a component's buffer.
        % Arguments:
        %   obj: custom_pathing_t object.
        %   idx: Specific component.
        %   sim: simulation_t object.
        %   failure: Indicates if this buffer clearing is due to a satellite failure:

            % Clear buffers:
            obj.buffers(idx).clear();

            % If packet dropping was due to a failure:
            if failure

                % Get satellite:
                tgt = get_component(sim, idx);

                % Get number of discarded messages:
                num_discarded = obj.buffers(idx).get_occupied();

                % Print packet drops:
                files = [0, 0];
                if sim.config.print_events
                    files(1) = 1;
                end
                if sim.config.log_events
                    files(2) = sim.log_file;
                end
                files(files == 0) = [];
                for file = files
                    fprintf("[%d] Satellite %s is now inactive, dropping %d packets...\n", sim.curr_posixtime, tgt.name, num_discarded);
                end

                % Updates statistics:
                for stats_algorithm = sim.statistics_algorithms
                    stats_algorithm.drop_packet_proc_inactive_target(sim, num_discarded, idx);
                end
            end
        end

        function tf = is_empty_buffer(obj, idx)
        % Description: Checks if a component's buffer is empty.
        % Arguments:
        %   obj: custom_pathing_t object.
        %   idx: Specific component.
        % Returns:
        %   tf: Indicates if the buffer is empty.

            tf = obj.buffers(idx).is_empty();
        end

        function [t_i, t_f] = increment_interval(obj, idx, base, time)
        % Description: Increments a component's interval.
        % Arguments:
        %   obj: custom_pathing_t object.
        %   idx: Specific component.
        %   base: Base time.
        %   time: Occupied time.
        % Returns:
        %   t_i: Initial time.
        %   t_f: Final time.

            [t_i, t_f] = obj.intervals(idx).increment(base, time);
        end

        function event = peek_event(obj)
        % Description: Returns the next event without removing it.
        % Arguments:
        %   obj: custom_pathing_t object.
        % Returns:
        %   event: Next event.

            event = obj.event_queue.peek();
        end

        function push_event(obj, event)
        % Description: Inserts a new event.
        % Arguments:
        %   obj: custom_pathing_t object.
        %   event: New event.

            obj.event_queue.push(event);
        end

        function event = pop_event(obj)
        % Description: Returns the next event, removing it.
        % Arguments:
        %   obj: custom_pathing_t object.
        % Returns:
        %   event: Next event.

            event = obj.event_queue.pop();
        end

        function treat_processing_event(~, sim, event, message)
        % Description: Processes normal (plane broadcasted) message.
        % Arguments:
        %   obj: custom_pathing_t object.
        %   sim: simulation_t object.
        %   event: Processing event.
        %   message: Message to process.

            event.queue_tx_event(sim, message);
        end

        function treat_dropped_broadcast(~, ~, ~)
        % Description: Treats the dropping of a normal (plane broadcasted) message due to no LoS.
        % Arguments:
        %   obj: custom_pathing_t object.
        %   sim: simulation_t object.
        %   target: Satellite that lost LoS.
        end
    end
end

