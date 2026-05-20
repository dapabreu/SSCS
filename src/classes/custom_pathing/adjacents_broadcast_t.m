classdef adjacents_broadcast_t < custom_pathing_t
% Description: Adjacent's broadcast algorithm
%   Whenever a satellite receives a message, they send it to all adjacent
%   satellites, apart from the satellite that originally sent the message
%   (unless the message comes directly from a plane).

    properties (Access = public)

        % Last packets received in all components:
        last_packets (1, :) circular_queue_t;
    end
    
    methods

        function obj = adjacents_broadcast_t(config)
        % Description: adjacents_broadcast_t constructor.
        % Arguments:
        %   config: Simulator's configuration struct.
        % Returns:
        %   obj: adjacents_broadcast_t object.

            arguments
                config (1, 1) struct = struct("total_grounds", 3, "total_planes", 225, "total_satellites", 200, "sat_buffer", 300, "t_base", datetime("now", "TimeZone", "UTC"));
            end

            % Constructs main object:
            obj@custom_pathing_t(config);

            % Defines extra values:
            obj.name = "Adjacent's Broadcast";
            obj.file_name = "adjacents_broadcast";
            obj.last_packets(config.total_grounds + config.total_planes + config.total_satellites) = circular_queue_t;
            for s = 1:config.total_satellites
                obj.last_packets(config.total_grounds + config.total_planes + s) = circular_queue_t(4 * config.sat_buffer);
            end
        end

        function update(obj, sim)
        % Description: Updates the algorithm.
        % Arguments:
        %   obj: Custom algorithm.
        %   sim: Simulation object.

            % Gets values:
            total_grounds = sim.config.total_grounds;
            total_planes = sim.config.total_planes;
            total_satellites = sim.config.total_satellites;

            % For each satellite, define the next satellite as the adjacent satellites:
            for s = 1:total_satellites
                obj.send{total_grounds + total_planes + s} = sim.satellites(s).get_adjacent_satellites(sim);
            end

            % Gets LoS between downlink satellites and ground stations:
            all_los = reshape([sim.satellites.los], [total_grounds + total_planes + total_satellites, total_satellites])';
            all_los = all_los(:, 1:total_grounds);
            
            % Sets all downlink satellites that have LoS to ground stations to send messages to them:
            [sat, gs] = find(all_los);
            sat = total_grounds + total_planes + sat;
            num_iters = numel(sat);
            for i = 1:num_iters
                obj.send{sat(i)} = gs(i);
            end
        end

        function action(~, ~, ~, ~)
        % Description: Processes a routing message. Since the adjacent's broadcast doesn't use these messages, its only declared.
        % Arguments:
        %   obj: Custom algorithm.
        %   sim: Simulation object.
        %   routing_message: Routing message to process.
        %   target: Component ID that is processing the routing message.
        end

        function treat_processing_event(obj, sim, event, message)
        % Description: Processes normal (plane broadcasted) message.
        % Arguments:
        %   obj: custom_pathing_t object.
        %   sim: simulation_t object.
        %   event: Processing event.
        %   message: Message to process.

            % Removes the message from the buffer:
            target = event.target;
            obj.remove_buffer(target);

            % Checks if the satellite already sent this message before, if not send it:
            if ~obj.last_packets(target).find(message.id)

                % Saves the message:
                obj.last_packets(target).push(message.id);

                % Sends the message:
                component = sim.get_component(target);
                next = obj.send{target};
                for n = next
                    if isnan(n) || ~component.los(n) || n == message.from
                        continue;
                    end
                    tx_delay = component.tx_delay(n);
                    [t_i, t_f] = obj.increment_interval(target, sim.curr_posixtime, tx_delay);
                    for stats_algorithm = sim.statistics_algorithms
                        stats_algorithm.add_busy_time(sim, target, tx_delay);
                    end
                    tx = tx_event_t(t_i, t_f, n, message, target, false);
                    obj.push_event(tx);
                end
            end

            % If the satellite's buffer isn't empty, continue processing:
            if ~obj.is_empty_buffer(target)
                queue_proc_event(event, sim, target);
            end
        end
    end
end
