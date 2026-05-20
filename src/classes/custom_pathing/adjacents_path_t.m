classdef adjacents_path_t < custom_pathing_t
% Description: Adjacent's path algorithm
%   Whenever a downlink satellite sees a ground station, it warns adjacent
%   satellites that it has a valid route, these satellites then compare the
%   time of arrival of the routing message and define the sending satellite
%   as the target of future transmissions if they have no defined route or
%   if the travel time is less than the currently defined route. Whenever a
%   satellite sets a new route, it warns its adjacent satellites of the new
%   route.

    properties (Access = public)

        % Extra parameters:
        cost;
        expiry;
        prev_los;
        routes (1, :) cell;
    end
    
    methods

        function obj = adjacents_path_t(config)
        % Description: adjacents_path_t constructor.
        % Arguments:
        %   config: Simulator's configuration struct.
        % Returns:
        %   obj: adjacents_path_t object.

            arguments
                config (1, 1) struct = struct("total_grounds", 3, "total_planes", 225, "total_satellites", 200, "sat_buffer", 300, "t_base", datetime("now", "TimeZone", "UTC"));
            end

            % Constructs main object:
            obj@custom_pathing_t(config);

            % Defines extra values:
            obj.name = "Adjacent's Path";
            obj.file_name = "adjacents_path";
            obj.cost = int64(Inf(1, config.total_grounds + config.total_planes + config.total_satellites));
            obj.expiry = int64(zeros(1, config.total_grounds + config.total_planes + config.total_satellites));
            obj.prev_los = false(1, config.total_grounds + config.total_planes + config.total_satellites);
            obj.send = repmat({[]}, 1, config.total_grounds + config.total_planes + config.total_satellites);
            obj.routes = repmat({[]}, 1, config.total_grounds + config.total_planes + config.total_satellites);
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

            % Builds LoS matrix between downlink satellites and ground stations:
            all_los = reshape([sim.satellites.los], [total_grounds + total_planes + total_satellites, total_satellites])';
            all_los = all_los(:, 1:total_grounds);

            % Gets the indexes of valid LoS and the number of "active" links:
            [sat, gs] = find(all_los);
            sat = total_grounds + total_planes + sat;
            num_iters = numel(sat);

            % For each valid downlink satellite:
            for i = 1:num_iters

                % Checks if the downlink has new LoS (existing LoS doesn't re-trigger algorithm):
                if ~obj.prev_los(sat(i)) || isnan(obj.send{sat(i)})
                    obj.prev_los(sat(i)) = true;

                    % Gets components:
                    ground_station = sim.get_component(gs(i));
                    satellite = sim.get_component(sat(i));

                    % Checks for how long the LoS will be valid:
                    [~, elevations] = aer(ground_station.sc_obj, satellite.sc_obj);
                    los = elevations >= sim.config.los_min_elev;
                    los = los((sim.sat_idx + 1):end);
                    last = sim.sat_idx + find(~los, 1);

                    % Saves route values:
                    if ~isempty(last)
                        obj.expiry(sat(i)) = to_posix_ns(sim.config.t_base + seconds((last - 1) * sim.config.update_dt));
                    else
                        obj.expiry(sat(i)) = to_posix_ns(sim.config.t_base + seconds(sim.config.t_stop));
                    end
                    obj.send{sat(i)} = gs(i);
                    satellite.roll_sending();
                    obj.routes{sat(i)} = [sat(i), gs(i)];
                    obj.cost(sat(i)) = satellite.tx_delay(gs(i)) + satellite.prop_delay(gs(i));

                    % Gets adjacent satellites and base message:
                    adjs = satellite.get_adjacent_satellites(sim);
                    num_tx = numel(adjs);
                    tx_times = satellite.tx_delay(adjs);
                    msg = routing_message_t(sat(i), sim.curr_posixtime, 0, sim.config.num_bits);

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
                        fprintf(file, "[%d - MSG%s] Triggered route broadcast due to new LoS from %s to %s\n", sim.curr_posixtime, msg.id, satellite.name, ground_station.name);
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

            % Update previous LoS connections:
            obj.prev_los(total_grounds + total_planes + (1:total_satellites)) = any(all_los, 2)';

            % For each satellite:
            for s = total_grounds + (1:total_satellites)

                % If the route has expired:
                if obj.expiry(s) < sim.curr_posixtime

                    % Clear values:
                    obj.send{s} = NaN;
                    obj.routes{s} = [];
                    obj.cost(s) = Inf;
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

            % Gets values:
            satellite = sim.get_component(target);
            from = routing_message.from;
            from_sat = sim.get_component(from);
            extra_time = routing_message.t_arrival - routing_message.t_transmission;

            % Checks if it's worth the switch:
            if obj.switch_route(sim, target, from, extra_time)

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
                    fprintf(file, "[%d - MSG%s] Altered %s's destination, now sending to %s (broadcast)\n", sim.curr_posixtime, routing_message.id, satellite.name, from_sat.name);
                end

                % Saves route values:
                obj.expiry(target) = obj.expiry(from);
                obj.cost(target) = obj.cost(from) + extra_time;
                obj.send{target} = from;
                satellite.roll_sending();
                obj.routes{target} = [target, obj.routes{from}];

                % Gets adjacent satellites and base message:
                adjs = satellite.get_adjacent_satellites(sim);
                idx = find(adjs == from, 1);
                if ~isempty(idx)
                    adjs(idx) = [];
                end
                num_tx = numel(adjs);
                tx_times = satellite.tx_delay(adjs);
                msg = routing_message_t(target, sim.curr_posixtime, 0, sim.config.num_bits);

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
        end

        function treat_processing_event(obj, sim, event, message)
        % Description: Processes normal (plane broadcasted) message.
        % Arguments:
        %   obj: custom_pathing_t object.
        %   sim: simulation_t object.
        %   event: Processing event.
        %   message: Message to process.
            
            % Find if the message was sent from our recipient:
            if ~isempty(find(message.from == obj.send{event.target}, 1))

                % Get involved components:
                target_sat = sim.get_component(event.target);
                from_sat = sim.get_component(message.from);

                % Print loop detection:
                files = [0, 0];
                if sim.config.print_events
                    files(1) = 1;
                end
                if sim.config.log_events
                    files(2) = sim.log_file;
                end
                files(files == 0) = [];
                for file = files
                    fprintf(file, "[%d - MSG%s] Removing loop at %s with %s\n", sim.curr_posixtime, message.id, target_sat.name, from_sat.name);
                end

                % Remove the satellite from our sending-to list to get rid of the loop:
                temp_send = obj.send{event.target};
                temp_routes = obj.routes{event.target};
                temp_send = temp_send(temp_send ~= message.from);
                temp_routes = temp_routes(temp_routes ~= message.from);
                if isempty(temp_send)
                    temp_send = NaN;
                    obj.expiry(event.target) = 0;
                    obj.cost(event.target) = Inf;
                end
                obj.send{event.target} = temp_send;
                obj.routes{event.target} = temp_routes;
            end
            
            % Treats processing event:
            treat_processing_event@custom_pathing_t(obj, sim, event, message);
        end

        function tf = switch_route(obj, sim, target, from, extra_time)
        % Description: Evaluates if a given satellite should switch from its current route to a newly proposed one.
        % Arguments:
        %   obj: Custom routing algorithm.
        %   sim: Simulation object.
        %   target: Target satellite's ID.
        %   from: Satellite ID of the next element in the newly proposed route.
        %   extra_time: Transmission and propagation times to next route element.
        % Returns:
        %   tf: Switch indicator (true - switch; false - don't switch).

            % Calculate weights:
            prev_weight = obj.calc_weight(sim, target, 0);
            new_weight = obj.calc_weight(sim, from, extra_time);
            tf = false;

            % If the sender and weight are valid:
            if new_weight ~= 0 && ~ismember(target, obj.routes{from})
                tf =    prev_weight < new_weight || ...
                        obj.expiry(target) < sim.curr_posixtime || ...
                        obj.send{target} == from;
            end
        end

        function w = calc_weight(obj, sim, dst, extra_time)
        % Description: Calculates the weight of a route.
        % Arguments:
        %   obj: Custom routing algorithm.
        %   sim: Simulation object.
        %   dst: Satellite ID of next route element.
        %   extra_time: Transmission and propagation times to next route element.
        % Returns:
        %   w: Weight of the route.
        
            % Remaining time in seconds:
            rem = obj.expiry(dst) - sim.curr_posixtime;

            % Cost in seconds:
            cst = obj.cost(dst) + extra_time;

            % If the cost is over the time limit, set weight to 0:
            if cst > to_posix_ns(sim.config.time_limit)
                w = 0;

            % Otherwise, calculate the weight:
            else
                w = double(rem) / double(1 + cst);
            end
        end
    end
end
