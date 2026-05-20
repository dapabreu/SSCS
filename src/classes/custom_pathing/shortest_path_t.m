classdef shortest_path_t < custom_pathing_t
% Description: Shortest path algorithm
%   Routes each satellite to the satellite that optimizes travel time.

    methods

        function obj = shortest_path_t(config)
        % Description: shortest_path_t constructor.
        % Arguments:
        %   config: Simulator's configuration struct.
        % Returns:
        %   obj: shortest_path_t object.

            arguments
                config (1, 1) struct = struct("total_grounds", 3, "total_planes", 225, "total_satellites", 200, "sat_buffer", 300, "t_base", datetime("now", "TimeZone", "UTC"));
            end

            % Constructs main object:
            obj@custom_pathing_t(config);

            % Defines extra values:
            obj.name = "Shortest Path";
            obj.file_name = "shortest_path";
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

            % Builds necessary LoS matrix
            first_sep = total_grounds;
            second_sep = total_grounds + total_planes;
            gs_los = reshape([sim.ground_stations.los], [total_grounds + total_planes + total_satellites, total_grounds])';
            sat_los = reshape([sim.satellites.los], [total_grounds + total_planes + total_satellites, total_satellites])';
            sat_gs_los = [gs_los(:, [1:first_sep, (second_sep + 1):end]); sat_los(:, [1:first_sep, (second_sep + 1):end])];

            % Initializes adjacency matrix:
            adj = zeros(total_grounds + total_satellites);

            % Gets the indexes of the sources and destinations of LoS:
            [src, dst] = find(sat_gs_los);
            iters = length(src);

            for i = 1:iters

                % Retrieves current source and destination:
                s = src(i);
                if s > total_grounds
                    true_s = s + total_planes;
                else
                    true_s = s;
                end
                d = dst(i);
                if d > total_grounds
                    true_d = d + total_planes;
                else
                    true_d = d;
                end

                 % Gets current source and destination:
                [src_component, src_type] = get_component(sim, true_s);
                [~, dst_type] = get_component(sim, true_d);

                % Sets adjacency value:
                if src_type == "ground_station_t" || dst_type == "ground_station_t" || ismember(true_d, src_component.get_adjacent_satellites(sim))
                    adj(s, d) = src_component.prop_delay(true_d) + src_component.tx_delay(true_d);
                end
            end

            % Creates directed graph:
            sat_graph = digraph(adj);

            % Initializes latency matrix:
            sat_latency = Inf(1, total_satellites);

            % Defines sources (satellites):
            sources = total_grounds + (1:total_satellites);

            % For each ground station:
            for g = 1:total_grounds

                % Gets the shortest path trees from every satellite to the selected ground station:
                [trees, dists] = shortestpathtree(sat_graph, sources, g, 'OutputForm','cell');

                % For each satellite:
                for s = 1:total_satellites

                    % If the latency is lower than the one in the already selected route:
                    if sat_latency(s) > dists(s)

                        % Updates route:
                        sat_latency(s) = dists(s);
                        curr_tree = trees{s};
                        obj.send{total_grounds + total_planes + s} = curr_tree(2);
                        if obj.send{total_grounds + total_planes + s} > total_grounds
                            obj.send{total_grounds + total_planes + s} = obj.send{total_grounds + total_planes + s} + total_planes;
                        end
                    end
                end
            end
        end

        function action(~, ~, ~, ~)
        % Description: Processes a routing message. Since the shortest path doesn't use these messages, its only declared.
        % Arguments:
        %   obj: Custom algorithm.
        %   sim: Simulation object.
        %   routing_message: Routing message to process.
        %   target: Component ID that is processing the routing message.
        end
    end
end
