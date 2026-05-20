classdef adjacents_path_2_t < adjacents_path_t
% Description: Adjacent's path algorithm version 2
%   Works like the 1st version of the adjacent's path algorithm, but downlink
%   satellites also send out routing messages when they no longer have LoS to
%   ground stations, which get propagated until they reach a satellite with a
%   valid route, which in turn responds with its own routing message to set a
%   new route on the requesting satellite, which then propagates the response.

    properties (Access = public)

        % Cell array of satellites that requested a new route.
        requested (1, :) cell;
    end
    
    methods

        function obj = adjacents_path_2_t(config)
        % Description: adjacents_path_2_t constructor.
        % Arguments:
        %   config: Simulator's configuration struct.
        % Returns:
        %   obj: adjacents_2_path_t object.

            arguments
                config (1, 1) struct = struct("total_grounds", 3, "total_planes", 225, "total_satellites", 200, "sat_buffer", 300, "t_base", datetime("now", "TimeZone", "UTC"));
            end

            % Constructs main object:
            obj@adjacents_path_t(config);

            % Defines extra values:
            obj.name = "Adjacent's Path v2";
            obj.file_name = "adjacents_path_2";
            obj.requested = cell(1, config.total_grounds + config.total_planes + config.total_satellites);
        end

        function update(obj, sim)
        % Description: Updates the algorithm.
        % Arguments:
        %   obj: Custom algorithm.
        %   sim: Simulation object.

            % Save previous LoS:
            last_prev_los = obj.prev_los;

            % Calls superclass update method:
            update@adjacents_path_t(obj, sim);

            % Gets indexes of the downlink satellites that lost LoS to ground stations:
            sat = find(last_prev_los & ~obj.prev_los);
            num_iters = numel(sat);

            % For each valid downlink satellite:
            for i = 1:num_iters

                % Gets component:
                satellite = sim.get_component(sat(i));

                % Gets adjacent satellites and base message:
                adjs = satellite.get_adjacent_satellites(sim);
                num_tx = numel(adjs);
                tx_times = satellite.tx_delay(adjs);
                msg = routing_message_t(sat(i), sim.curr_posixtime, 0, sim.config.num_bits, type = 2);

                % Prints trigger:
                files = [0, 0];
                if sim.config.print_events
                    files(1) = 1;
                end
                if sim.config.log_events
                    files(2) = sim.log_file;
                end
                files(files == 0) = [];
                for file = files
                    fprintf(file, "[%d - MSG%s] Triggered route request due to %s losing LoS\n", sim.curr_posixtime, msg.id, satellite.name);
                end

                % Updates statistics:
                for stats_algorithm = sim.statistics_algorithms
                    stats_algorithm.new_routing_packets(sim, msg, num_tx);
                end
                
                % Adds TX events:
                for t = 1:num_tx
                    [t_i, t_f] = obj.increment_interval(sat(i), sim.curr_posixtime, tx_times(t));
                    for stats_algorithm = sim.statistics_algorithms
                        stats_algorithm.add_busy_time(sim, sat(i), tx_times(t));
                    end
                    msg.t_transmission = t_i;
                    tx = tx_event_t(t_i, t_f, adjs(t), msg, sat(i), false);
                    obj.push_event(tx);
                end
            end
        end

        function action(obj, sim, routing_message, target)
        % Description: Processes a routing message.
        % Arguments:
        %   obj: Custom algorithm.
        %   sim: Simulation object.
        %   routing_message: Routing message to process.
        %   target: Component ID that is processing the routing message.

            % Sets base values:
            from = routing_message.from;
            from_sat = sim.get_component(from);
            extra_time = routing_message.t_arrival - routing_message.t_transmission;

            % If the routing message is promoting a new route:
            if routing_message.type == 1

                % Calls superclass action method:
                action@adjacents_path_t(obj, sim, routing_message, target);

            % If the routing message is requesting a new route:
            elseif routing_message.type == 2

                % Gets component:
                satellite = sim.get_component(target);

                % If the satellite has a valid route, respond with it:
                if obj.expiry(target) >= sim.curr_posixtime

                    % Creates response message:
                    msg = routing_message_t(target, sim.curr_posixtime, 0, sim.config.num_bits, type = 3);

                    % Prints trigger:
                    files = [0, 0];
                    if sim.config.print_events
                        files(1) = 1;
                    end
                    if sim.config.log_events
                        files(2) = sim.log_file;
                    end
                    files(files == 0) = [];
                    for file = files
                        fprintf(file, "[%d - MSG%s] Triggered route response from %s due to %s's request\n", sim.curr_posixtime, msg.id, satellite.name, from_sat.name);
                    end

                    % Updates statistics:
                    for stats_algorithm = sim.statistics_algorithms
                        stats_algorithm.new_routing_packets(sim, msg, 1);
                    end

                    % Adds TX event:
                    tx_time = satellite.tx_delay(from);
                    [t_i, t_f] = obj.increment_interval(target, sim.curr_posixtime, tx_time);
                    for stats_algorithm = sim.statistics_algorithms
                        stats_algorithm.add_busy_time(sim, target, tx_time);
                    end
                    msg.t_transmission = t_i;
                    tx = tx_event_t(t_i, t_f, from, msg, target, false);
                    obj.push_event(tx);

                % If the satellite doesn't have a valid route, request one:
                else

                    % Gets the list of already requested:
                    already_requested = obj.requested{target};

                    % If the satellite hasn't requested any routes:
                    if isempty(already_requested)
    
                        % Gets adjacent satellites and base message:
                        adjs = satellite.get_adjacent_satellites(sim);
                        idx = find(adjs == from, 1);
                        if ~isempty(idx)
                            adjs(idx) = [];
                        end
                        num_tx = numel(adjs);
                        tx_times = satellite.tx_delay(adjs);
                        msg = routing_message_t(target, sim.curr_posixtime, 0, sim.config.num_bits, type = 2);

                        % Prints trigger:
                        files = [0, 0];
                        if sim.config.print_events
                            files(1) = 1;
                        end
                        if sim.config.log_events
                            files(2) = sim.log_file;
                        end
                        files(files == 0) = [];
                        for file = files
                            fprintf(file, "[%d - MSG%s] Triggered route request from %s due to %s's request\n", sim.curr_posixtime, msg.id, satellite.name, from_sat.name);
                        end
        
                        % Updates statistics:
                        for stats_algorithm = sim.statistics_algorithms
                            stats_algorithm.new_routing_packets(sim, msg, num_tx);
                        end
                        
                        % Adds TX events:
                        for t = 1:num_tx
                            [t_i, t_f] = obj.increment_interval(target, sim.curr_posixtime, tx_times(t));
                            for stats_algorithm = sim.statistics_algorithms
                                stats_algorithm.add_busy_time(sim, target, tx_times(t));
                            end
                            msg.t_transmission = t_i;
                            tx = tx_event_t(t_i, t_f, adjs(t), msg, target, false);
                            obj.push_event(tx);
                        end
                    end

                    % Adds the satellite to the response list:
                    if ~ismember(from, already_requested)
                        obj.requested{target} = [already_requested, from];
                    end
                end

            % If the routing message is reponding to a route request:
            elseif routing_message.type == 3

                % Gets component:
                satellite = sim.get_component(target);

                % Gets the list of already requested and base message:
                already_requested = obj.requested{target};
                idx = find(already_requested == from, 1);
                if ~isempty(idx)
                    already_requested(idx) = [];
                end
                num_tx = numel(already_requested);
                tx_times = satellite.tx_delay(already_requested);
                msg = routing_message_t(target, routing_message.t_created, 0, sim.config.num_bits, type = 3);

                % Prints trigger:
                files = [0, 0];
                if sim.config.print_events
                    files(1) = 1;
                end
                if sim.config.log_events
                    files(2) = sim.log_file;
                end
                files(files == 0) = [];
                for file = files
                    fprintf(file, "[%d - MSG%s] Triggered route response from %s due to %s's response\n", sim.curr_posixtime, msg.id, satellite.name, from_sat.name);
                end

                % Updates statistics:
                for stats_algorithm = sim.statistics_algorithms
                    stats_algorithm.new_routing_packets(sim, msg, num_tx);
                end
                
                % Adds TX events:
                for t = 1:num_tx
                    [t_i, t_f] = obj.increment_interval(target, sim.curr_posixtime, tx_times(t));
                    for stats_algorithm = sim.statistics_algorithms
                        stats_algorithm.add_busy_time(sim, target, tx_times(t));
                    end
                    msg.t_transmission = t_i;
                    tx = tx_event_t(t_i, t_f, already_requested(t), msg, target, false);
                    obj.push_event(tx);
                end

                % If the satellite doesn't have a valid route, set it:
                if obj.expiry(target) < sim.curr_posixtime

                    % Print route switch:
                    files = [0, 0];
                    if sim.config.print_events
                        files(1) = 1;
                    end
                    if sim.config.log_events
                        files(2) = sim.log_file;
                    end
                    files(files == 0) = [];
                    for file = files
                        fprintf(file, "[%d - MSG%s] Altered %s's destination, now sending to %s (response)\n", sim.curr_posixtime, routing_message.id, satellite.name, from_sat.name);
                    end

                    obj.expiry(target) = obj.expiry(from);
                    obj.cost(target) = extra_time + obj.cost(from);
                    obj.send{target} = from;
                    satellite.roll_sending();
                    obj.routes{target} = [target, obj.routes{from}];
                end

                % Clears list of already requested:
                obj.requested{target} = [];
            end
        end

        function treat_dropped_broadcast(obj, sim, target)
        % Description: Treats the dropping of a normal (plane broadcasted) message due to no LoS.
        % Arguments:
        %   obj: custom_pathing_t object.
        %   sim: simulation_t object.
        %   target: Satellite that lost LoS.

            % Gets component:
            satellite = sim.get_component(target);

            % Gets adjacent satellites and base message:
            adjs = satellite.get_adjacent_satellites(sim);
            num_tx = numel(adjs);
            tx_times = satellite.tx_delay(adjs);
            msg = routing_message_t(target, sim.curr_posixtime, 0, sim.config.num_bits, type = 2);

            % Prints trigger:
            files = [0, 0];
            if sim.config.print_events
                files(1) = 1;
            end
            if sim.config.log_events
                files(2) = sim.log_file;
            end
            files(files == 0) = [];
            for file = files
                fprintf(file, "[%d - MSG%s] Triggered route request due to %s losing LoS\n", sim.curr_posixtime, msg.id, satellite.name);
            end

            % Updates statistics:
            for stats_algorithm = sim.statistics_algorithms
                stats_algorithm.new_routing_packets(sim, msg, num_tx);
            end
            
            % Adds TX events:
            for t = 1:num_tx
                [t_i, t_f] = obj.increment_interval(target, sim.curr_posixtime, tx_times(t));
                for stats_algorithm = sim.statistics_algorithms
                    stats_algorithm.add_busy_time(sim, target, tx_times(t));
                end
                msg.t_transmission = t_i;
                tx = tx_event_t(t_i, t_f, adjs(t), msg, target, false);
                obj.push_event(tx);
            end
        end

        function w = calc_weight(obj, sim, dst, extra_time)
        % Description: Calculates the weight of a route.
        % Arguments:
        %   obj: Custom routing algorithm.
        %   sim: Simulation object.
        %   dst: Component ID of next route element.
        %   tx_time: Transmission and processing time to next route element.
        % Returns:
        %   w: Weight of the route.
        
            % Cost in seconds:
            cst = obj.cost(dst) + extra_time;

            % If the cost is over the time limit, set weight to 0:
            if cst > to_posix_ns(sim.config.time_limit)
                w = 0;

            % Otherwise, calculate the weight:
            else
                w = 1 / double(1 + cst);
            end
        end
    end
end

