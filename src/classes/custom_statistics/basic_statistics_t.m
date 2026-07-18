classdef basic_statistics_t < custom_statistics_t
% Description: Basic statistics gatherer.
    
    properties (Access = public)

        % Received packets:
        last_received_packets (1, :) circular_queue_t

        % Global statistics:
        total_treated_events;
        total_broadcast_packets;
        total_routing_packets;
        total_received;
        total_duplicates;
        total_dropped_buffer;
        total_dropped_no_los;
        total_dropped_failure;
        total_expired;
        total_time;
        total_ber;
        total_occupied;
        total_hops;
        total_bits;
        peak_buffer_depth;      
        sum_buffer_depth;       
        total_buffer_samples;
        total_jitter_sum;
        total_jitter_count;
        last_delay_map;
        total_time_M2;
        total_ber_M2;
        total_jitter_M2;
        buffer_depth_M2;
        total_hops_M2;

        % Timeslice statistics:
        treated_events;
        broadcast_packets;
        routing_packets;
        received;
        duplicates;
        dropped_buffer;
        dropped_no_los;
        dropped_failure;
        expired;
        time;
        ber;
        occupied;
        message_paths;
        hops;
        bits;
        jitter_sum;
        jitter_count;
        time_M2;
        ber_M2;
        jitter_M2;
        hops_M2;

        % Raw Data Export arrays (Timeslice Buffers):
        raw_idx;
        raw_latencies;
        raw_jitters;
        raw_hops;
        raw_bers;
        raw_status;

        % Figure values:
        text_offset = 2e5;
        view_offset = 1e7;
        occupancy_offset = 6e5;
        occupancy_threshold = 25;
        color = "summer";
        flip_color = true;
        save_figure = false;
        bg_color = 'black';
        text_color = "white";
        route_usage = true;  % Displays routes with usage information. False displays more recent usages per route
        route_usage_max = 0;
    end
    
    methods
        function obj = basic_statistics_t(config)
        % Description: custom_statistics_t constructor.
        % Arguments:
        %   config: Simulator's configuration struct.
        % Returns:
        %   obj: custom_statistics_t object.

        arguments
            config (1, 1) struct = struct("total_grounds", 3, "total_planes", 225, "total_satellites", 200, "duplicate_buffer", 100);
        end

            % Creates base values:
            obj = obj@custom_statistics_t(config);
            obj.name = "Basic Statistics";
            obj.file_name = "basic_statistics";

            % Last received packets:
            obj.last_received_packets = circular_queue_t(config.duplicate_buffer);

            % Global statistics:
            obj.total_treated_events = 0;
            obj.total_broadcast_packets = 0;
            obj.total_routing_packets = 0;
            obj.total_received = zeros(1, config.total_grounds);
            obj.total_duplicates = 0;
            obj.total_dropped_buffer = 0;
            obj.total_dropped_no_los = 0;
            obj.total_dropped_failure = 0;
            obj.total_expired = 0;
            obj.total_time = 0;
            obj.total_ber = 0;
            obj.total_occupied = int64(zeros(1, config.total_grounds + config.total_planes + config.total_satellites));
            obj.total_hops = 0;
            obj.total_bits = 0;
            obj.peak_buffer_depth = zeros(1, config.total_grounds + config.total_planes + config.total_satellites); 
            obj.sum_buffer_depth = 0;
            obj.total_buffer_samples = 0;
            obj.last_delay_map = containers.Map('KeyType', 'char', 'ValueType', 'double');
            obj.total_jitter_sum = 0;
            obj.total_jitter_count = 0;
            obj.total_time_M2 = 0;
            obj.total_ber_M2 = 0;
            obj.total_jitter_M2 = 0;
            obj.buffer_depth_M2 = 0;
            obj.total_hops_M2 = 0;

            % Timeslice statistics:
            obj.treated_events = 0;
            obj.broadcast_packets = 0;
            obj.routing_packets = 0;
            obj.received = zeros(1, config.total_grounds);
            obj.duplicates = 0;
            obj.dropped_buffer = 0;
            obj.dropped_no_los = 0;
            obj.dropped_failure = 0;
            obj.expired = 0;
            obj.time = 0;
            obj.ber = 0;
            obj.occupied = int64(zeros(1, config.total_grounds + config.total_planes + config.total_satellites));
            obj.message_paths = bucket_queue_t(comp_param = "link_id", key_type = "char", key_buffer = simple_priority_queue_t("a", order='asc'));
            obj.hops = 0;
            obj.bits = 0;
            obj.jitter_sum = 0;
            obj.jitter_count = 0;
            obj.time_M2 = 0;
            obj.ber_M2 = 0;
            obj.jitter_M2 = 0;
            obj.hops_M2 = 0;

            % Pre-allocate timeslice buffers for CSV export
            obj.raw_idx = 1;
            obj.raw_latencies = zeros(1000000, 1);
            obj.raw_jitters = zeros(1000000, 1);
            obj.raw_hops = zeros(1000000, 1);
            obj.raw_bers = zeros(1000000, 1);
            obj.raw_status = zeros(1000000, 1, 'int8'); % 0=Rx, 1=NoLoS, 2=Buffer, 3=Expired, 4=Failure
        end
        
        function show_stats(obj, sim, dir)
        % Description: Shows the algorithms' statistics.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   dir: Directory to save the statistics to.
            
            % Creates statistics folder if necessary:
            if sim.config.graphical_stats || sim.config.text_stats
                if ~isfolder(dir)
                    status = mkdir(dir);
                    if ~status
                        error("Unable to setup statistics folder");
                    end
                end
            end

            % If the user wants text statistics:
            if sim.config.text_stats

                % Gets values:
                grounds = sim.config.total_grounds;
                planes = sim.config.total_planes;
    
                % Gets max occupied satellite for the current timeslice:
                [max_sat_occ, max_sat_occ_idx] = max(obj.occupied((grounds + planes + 1):end));
                max_sat_occ = double(max_sat_occ);
                max_sat_occ_component = sim.get_component(grounds + planes + max_sat_occ_idx);
                
                % Gets average satellite occupation for the current timeslice:
                avg_sat_occ = double(mean(obj.occupied((grounds + planes + 1):end)));
                
                % Gets max occupied satellite for all simulated timeslices:
                [total_max_sat_occ, total_max_sat_occ_idx] = max(obj.total_occupied((grounds + planes + 1):end));
                total_max_sat_occ = double(total_max_sat_occ);
                total_max_sat_occ_component = sim.get_component(grounds + planes + total_max_sat_occ_idx);
                
                % Gets average satellite occupation for all simulated timeslices:
                total_avg_sat_occ = double(mean(obj.total_occupied((grounds + planes + 1):end)));

                % Total transmissions (Timeslice):
                ts_rx = sum(obj.received);
                ts_lost = obj.dropped_buffer + obj.dropped_no_los + obj.dropped_failure + obj.expired;
                ts_total = ts_rx + ts_lost;

                % Packet Delivery Ratio (PDR) & Loss Ratio (PLR) (Timeslice):
                if ts_total > 0
                    ts_pdr = (ts_rx / ts_total) * 100;
                    ts_plr = (ts_lost / ts_total) * 100;
                else
                    ts_pdr = 0;
                    ts_plr = 0;
                end

                % Throughput (Timeslice):
                ts_seconds = sim.config.dt;
                if ts_seconds > 0
                    ts_throughput = obj.bits / ts_seconds;
                else
                    ts_throughput = 0;
                end

                % NRL (Timeslice):
                if ts_rx > 0
                    ts_nrl = obj.routing_packets / ts_rx;
                    ts_avg_hops = obj.hops / ts_rx;
                else
                    ts_nrl = 0;
                    ts_avg_hops = 0;
                end

                % Jitter (Timeslice):
                if obj.jitter_count > 0
                    ts_avg_jitter = (double(obj.jitter_sum) / double(obj.jitter_count)) / 1e6;
                else
                    ts_avg_jitter = 0;
                end

                % Jain's Fairness Index (Timeslice):
                ts_flows = sum(obj.received > 0);
                if ts_flows > 0
                    ts_jains = sum(obj.received)^2 / (ts_flows * sum(obj.received.^2));
                else
                    ts_jains = 0;
                end

                % Total transmissions (Global):
                g_rx = sum(obj.total_received);
                g_lost = obj.total_dropped_buffer + obj.total_dropped_no_los + obj.total_dropped_failure + obj.total_expired;
                g_total = g_rx + g_lost;

                % Packet Delivery Ratio (PDR) & Loss Ratio (PLR) (Global):
                if g_total > 0
                    g_pdr = (g_rx / g_total) * 100;
                    g_plr = (g_lost / g_total) * 100;
                else
                    g_pdr = 0;
                    g_plr = 0;
                end

                % Throughput (Global):
                g_seconds = sim.curr_time_idx * sim.config.dt;
                if g_seconds > 0
                    g_throughput = obj.total_bits / g_seconds;
                else
                    g_throughput = 0;
                end

                % NRL (Global):
                if g_rx > 0
                    g_nrl = obj.total_routing_packets / g_rx;
                    g_avg_hops = obj.total_hops / g_rx;
                else
                    g_nrl = 0;
                    g_avg_hops = 0;
                end

                % Jitter (Global):
                if obj.total_jitter_count > 0
                    g_avg_jitter = (double(obj.total_jitter_sum) / double(obj.total_jitter_count)) / 1e6;
                else
                    g_avg_jitter = 0;
                end

                % Buffer Stats (Global):
                max_buffer = max(obj.peak_buffer_depth);
                if obj.total_buffer_samples > 0
                    avg_buffer = obj.sum_buffer_depth / obj.total_buffer_samples;
                else
                    avg_buffer = 0;
                end

                % Jain's Fairness Index (Global):
                g_flows = sum(obj.total_received > 0);
                if g_flows > 0
                    g_jains = sum(obj.total_received)^2 / (g_flows * sum(obj.total_received.^2));
                else
                    g_jains = 0;
                end

                % Calculate standard deviations (Timeslice):
                ts_time_std = 0;
                if ts_rx > 1
                    ts_time_std = sqrt(obj.time_M2 / (ts_rx - 1));
                end
                ts_ber_std = 0;
                if ts_rx > 1
                    ts_ber_std = sqrt(obj.ber_M2 / (ts_rx - 1));
                end
                ts_jitter_std = 0;
                if obj.jitter_count > 1
                    ts_jitter_std = sqrt(obj.jitter_M2 / (obj.jitter_count - 1)) / 1e6;
                end
                ts_hops_std = 0;
                if ts_rx > 1
                    ts_hops_std = sqrt(obj.hops_M2 / (ts_rx - 1));
                end
                ts_occ_array = double(obj.occupied((grounds + planes + 1):end));
                ts_sat_occ_std = std(ts_occ_array);

                % Calculate standard deviations (Global):
                g_time_std = 0;
                if g_rx > 1
                    g_time_std = sqrt(obj.total_time_M2 / (g_rx - 1));
                end
                g_ber_std = 0;
                if g_rx > 1
                    g_ber_std = sqrt(obj.total_ber_M2 / (g_rx - 1));
                end
                g_jitter_std = 0;
                if obj.total_jitter_count > 1
                    g_jitter_std = sqrt(obj.total_jitter_M2 / (obj.total_jitter_count - 1)) / 1e6;
                end
                g_buffer_std = 0;
                if obj.total_buffer_samples > 1
                    g_buffer_std = sqrt(obj.buffer_depth_M2 / (obj.total_buffer_samples - 1));
                end
                g_hops_std = 0;
                if g_rx > 1
                    g_hops_std = sqrt(obj.total_hops_M2 / (g_rx - 1));
                end
                g_occ_array = double(obj.total_occupied((grounds + planes + 1):end));
                g_sat_occ_std = std(g_occ_array);

                % Writes the statistics:
                fid = fopen(dir + "stats.log", "w");
                if fid < 3
                    error("Failed to open file on %s.", dir);
                end
                
                % Timeslice statistics:
                fprintf(fid, "Timeslice statistics:\n");
                fprintf(fid, "\tEvents: %d\n\tBroadcast packets: %d\n\tRouting packets: %d\n", obj.treated_events, obj.broadcast_packets, obj.routing_packets);
                fprintf(fid, "\tReceived: %d\n\tDuplicates received: %d\n", ts_rx, obj.duplicates);
                fprintf(fid, "\tDropped (full buffer): %d\n\tDropped (no LoS): %d\n\tDropped (failure): %d\n\tExpired: %d\n", obj.dropped_buffer, obj.dropped_no_los, obj.dropped_failure, obj.expired);
                fprintf(fid, "\tAverage delivery time: %.2fms (σ: %.2fms)\n\tAverage BER: %e (σ: %e)\n", obj.time / 1e6, ts_time_std / 1e6, obj.ber, ts_ber_std);
                fprintf(fid, "\tMax occupation: %s - %.2fms (%.2f%%)\n\tAverage occupation: %.2fms (%.2f%%) (σ: %.2fms)\n", max_sat_occ_component.name, max_sat_occ / 1e6, 100 * (max_sat_occ / 1e9) / sim.config.dt, avg_sat_occ / 1e6, 100 * (avg_sat_occ / 1e9) / sim.config.dt, ts_sat_occ_std / 1e6);
                fprintf(fid, "\tThroughput: %.2f bits/sec\n", ts_throughput);
                fprintf(fid, "\tPacket Delivery Ratio (PDR): %.2f%%\n", ts_pdr);
                fprintf(fid, "\tPacket Loss Ratio (PLR): %.2f%%\n", ts_plr);
                fprintf(fid, "\tNormalized Routing Load (NRL): %.4f\n", ts_nrl);
                fprintf(fid, "\tAverage Hop Count: %.2f (σ: %.2f)\n", ts_avg_hops, ts_hops_std);
                fprintf(fid, "\tAverage Jitter: %.2f ms (σ: %.2f ms)\n", ts_avg_jitter, ts_jitter_std);
                fprintf(fid, "\tJain's Fairness Index: %.4f\n", ts_jains);
                                
                % Global statistics:
                fprintf(fid, "\nGlobal statistics:\n");
                fprintf(fid, "\tEvents: %d\n\tBroadcast packets: %d\n\tRouting packets: %d\n", obj.total_treated_events, obj.total_broadcast_packets, obj.total_routing_packets);
                fprintf(fid, "\tReceived: %d\n\tDuplicates received: %d\n", g_rx, obj.total_duplicates);
                fprintf(fid, "\tDropped (full buffer): %d\n\tDropped (no LoS): %d\n\tDropped (failure): %d\n\tExpired: %d\n", obj.total_dropped_buffer, obj.total_dropped_no_los, obj.total_dropped_failure, obj.total_expired);
                fprintf(fid, "\tAverage delivery time: %.2fms (σ: %.2fms)\n\tAverage BER: %e (σ: %e)\n", obj.total_time / 1e6, g_time_std / 1e6, obj.total_ber, g_ber_std);
                fprintf(fid, "\tMax occupation: %s - %.2fms (%.2f%%)\n\tAverage occupation: %.2fms (%.2f%%) (σ: %.2fms)\n", total_max_sat_occ_component.name, total_max_sat_occ / 1e6, 100 * (total_max_sat_occ / 1e9) / (sim.curr_time_idx * sim.config.dt), total_avg_sat_occ / 1e6, 100 * (total_avg_sat_occ / 1e9) / (sim.curr_time_idx * sim.config.dt), g_sat_occ_std / 1e6);
                fprintf(fid, "\tThroughput: %.2f bits/sec\n", g_throughput);
                fprintf(fid, "\tPacket Delivery Ratio (PDR): %.2f%%\n", g_pdr);
                fprintf(fid, "\tPacket Loss Ratio (PLR): %.2f%%\n", g_plr);
                fprintf(fid, "\tNormalized Routing Load (NRL): %.4f\n", g_nrl);
                fprintf(fid, "\tAverage Hop Count: %.2f (σ: %.2f)\n", g_avg_hops, g_hops_std);
                fprintf(fid, "\tAverage Jitter: %.2f ms (σ: %.2f ms)\n", g_avg_jitter, g_jitter_std);
                fprintf(fid, "\tJain's Fairness Index: %.4f\n", g_jains);
                fprintf(fid, "\tBuffer Statistics:\n\t\tPeak Depth: %d\n\t\tAverage Depth: %.2f (σ: %.2f)\n", max_buffer, avg_buffer, g_buffer_std);
                fclose(fid);

                % Export to CSV:
                valid_count = obj.raw_idx - 1;
                if valid_count > 0

                    % Map numeric status to human-readable strings:
                    status_map = {'Received', 'Dropped_No_LoS', 'Dropped_Buffer_Full', 'Dropped_Expired', 'Dropped_Failure'};
                    status_strs = status_map(obj.raw_status(1:valid_count) + 1)';
                    export_table = table(...
                        obj.raw_latencies(1:valid_count), ...
                        obj.raw_jitters(1:valid_count), ...
                        obj.raw_hops(1:valid_count), ...
                        obj.raw_bers(1:valid_count), ...
                        status_strs, ...
                        'VariableNames', {'Latency_ms', 'Jitter_ms', 'Hops', 'BER', 'Status'});
                    
                    % Get path:
                    csv_path = sprintf("%s%dgs-%ddl-%dpl-%s_data.csv", sim.config.stats_dir, sim.config.total_grounds, sim.config.total_downlinks, sim.config.total_planes, sim.config.failure_scenario);
                    
                    % Append to existing file without rewriting headers:
                    if isfile(csv_path)
                        writetable(export_table, csv_path, 'WriteMode', 'append', 'WriteVariableNames', false);
                    % Create new file with headers on the first timestep:
                    else
                        writetable(export_table, csv_path, 'WriteMode', 'overwrite', 'WriteVariableNames', true);
                    end
                end
            end

            % If the user wants graphical statistics:
            if sim.config.graphical_stats

                % Shows the timeslice's animation:
                create_scene(obj, sim);
                show_animation(obj, sim);
    
                % Saves figure and image:
                f = gcf();
                if obj.save_figure
                    savefig(f, dir + obj.file_name + ".fig", "-v7.3");
                end
                exportgraphics(f, dir + obj.file_name + ".png", 'Resolution', 300);
                close(f);
            end
            
        end

        function create_scene(obj, sim)
        % Description: Creates the animation scene.
        % Arguments:
        %   obj: basic_statistics_t object.
        %   sim: Simulation object.

            % Gathers necessary values:
            total_grounds = sim.config.total_grounds;
            total_planes = sim.config.total_planes;
            total_satellites = sim.config.total_satellites;
        
            % Creates the new figure:
            screen_size = get(groot, 'ScreenSize');
            fig_title = obj.name + ": t" + string(sim.curr_time_idx) + " (" + string(sim.curr_timeslice) + ")";
            figure('Name', fig_title, 'NumberTitle', 'off', 'ToolBar', 'none', 'Position', screen_size, 'Visible', 'off', 'Color', obj.bg_color);
        
            % Defines the title for the whole figure:
            sgtitle(fig_title);
        
            % Plots the earth:
            [X, Y, Z] = sphere(200);
            earth_texture = imread('landOcean.jpg');
            earth_texture = flipud(earth_texture);
            earth = surf(X * sim.config.Re, Y * sim.config.Re, Z * sim.config.Re);
            earth.FaceColor = 'texturemap';
            earth.EdgeColor = 'none';
            earth.CData = earth_texture;
            earth.CDataMapping = 'direct';
            alpha(earth, 0.6);
            hold on;
            axis equal;
            xlabel('X (m)');
            ylabel('Y (m)');
            zlabel('Z (m)');
            view(30, 30);
            grid on;
            set(gca, 'Color', obj.bg_color);

            % Gets all positions:
            [ground_pos, plane_pos, sat_pos] = sim.get_pos();
            node_pos = [ground_pos; plane_pos; sat_pos];

            % Separate coordinates for the nodes:
            x_pos = node_pos(:, 1);
            y_pos = node_pos(:, 2);
            z_pos = node_pos(:, 3);
            
            % Plots all ground stations and assigns their names:
            for g = 1:total_grounds
                text(x_pos(g), y_pos(g), z_pos(g), '📡', 'FontSize', 12, 'Color', obj.text_color);
            end

            % Plots all planes and assigns their names:
            for p = 1:total_planes
                text(x_pos(total_grounds + p), y_pos(total_grounds + p), z_pos(total_grounds + p), '✈', 'FontSize', 10, 'Color', obj.text_color);
            end
    
            % Plots all satellites:
            for s = 1:total_satellites
                if any(sim.config.downlink_idxs == s)
                    text(x_pos(total_grounds + total_planes + s), y_pos(total_grounds + total_planes + s), z_pos(total_grounds + total_planes + s), '🛰📶', 'FontSize', 8, 'Color', obj.text_color);
                else
                    text(x_pos(total_grounds + total_planes + s), y_pos(total_grounds + total_planes + s), z_pos(total_grounds + total_planes + s), '🛰', 'FontSize', 8, 'Color', obj.text_color);
                end
            end
        end

        function show_animation(obj, sim)
        % Description: Creates the animation scene.
        % Arguments:
        %   obj: basic_statistics_t object.
        %   sim: Simulation object.

            % Gets color gradients:
            occ_color = flipud(autumn(101));
            if ~obj.route_usage
                rx_count = obj.message_paths.get_occupied();
                color_arr = eval(obj.color + "(" + string(rx_count) + ")");
                if obj.flip_color
                    color_arr = flipud(color_arr);
                end
                color_idx = 1;
            end
            
            % For each hop:
            while ~obj.message_paths.is_empty()

                % Gets trace and components:
                trace = obj.message_paths.pop();
                if trace.source == -1
                    src_comp = struct("name", trace.message.airplane_ICAO, "pos", lla2ecef([trace.message.airplane_lat, trace.message.airplane_lon, trace.message.airplane_alt]));
                else
                    src_comp = sim.get_component(trace.source);
                end
                tgt_comp = sim.get_component(trace.target);

                % Gets color:
                if obj.route_usage
                    curr_color = occ_color(round(double(trace.rx_time) * 100 / obj.route_usage_max) + 1, :);
                else
                    curr_color = color_arr(color_idx, :);
                end
        
                % Draws the full line:
                plot3([src_comp.pos(1), tgt_comp.pos(1)], [src_comp.pos(2), tgt_comp.pos(2)], [src_comp.pos(3), tgt_comp.pos(3)], 'Color', curr_color, 'LineWidth', 2.5);

                % Increments color index:
                if ~obj.route_usage
                    color_idx = color_idx + 1;
                end
            end
        
            % Displays occupancy percentages:
            occupancy = double(100 * obj.occupied) / double(to_posix_ns(sim.config.dt));
            n_len = numel(occupancy);
            max_occ = max(occupancy) / 100;
            for n = 1:n_len
                if occupancy(n) > obj.occupancy_threshold * max_occ
                    node = sim.get_component(n);
                    n_pos = node.pos;
                    text_pos = n_pos + obj.occupancy_offset * n_pos/norm(n_pos);
                    text(text_pos(1), text_pos(2), text_pos(3), string(occupancy(n)) + '%', 'FontSize', 7, 'FontWeight', 'bold', 'Color', occ_color(round(occupancy(n) / max_occ) + 1, :));
                end
            end
            for g = 1:sim.config.total_grounds
                n_pos = sim.ground_stations(g).pos;
                text_pos = n_pos + obj.occupancy_offset * n_pos/norm(n_pos);
                text(text_pos(1), text_pos(2), text_pos(3), string(obj.received(g)), 'FontSize', 7, 'FontWeight', 'bold', 'Color', obj.text_color);
            end

            % Gets the most used ground station and the corresponding number of usages:
            [~, most_used_gs] = max(obj.received);

            % Centers the camera to save the figure:
            pt = sim.ground_stations(most_used_gs).pos;
            camtarget(pt);
            direction = pt * obj.view_offset / norm(pt);
            campos(pt + direction);
        end

        function reset_stats(obj)
        % Description: Resets the algorithms' statistics for the current timeslice.
        % Arguments:
        %   obj: custom_statistics_t object.

            % Resets current statistics:
            obj.treated_events = 0;
            obj.broadcast_packets = 0;
            obj.routing_packets = 0;
            obj.received(1:end) = 0;
            obj.duplicates = 0;
            obj.dropped_buffer = 0;
            obj.dropped_no_los = 0;
            obj.dropped_failure = 0;
            obj.expired = 0;
            obj.time = 0;
            obj.ber = 0;
            obj.occupied(1:end) = int64(0);
            obj.message_paths.clear();
            obj.route_usage_max = 0;
            obj.hops = 0;
            obj.bits = 0;
            obj.jitter_sum = 0;
            obj.jitter_count = 0;
            obj.time_M2 = 0;
            obj.ber_M2 = 0;
            obj.jitter_M2 = 0;
            obj.hops_M2 = 0;

            % Reset raw data buffer index for the new timeslice:
            obj.raw_idx = 1;
        end

        function treated_event(obj, ~, ~)
        % Description: Updates statistics upon treating an event.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   event: Treated event.

            obj.total_treated_events = obj.total_treated_events + 1;
            obj.treated_events = obj.treated_events + 1;
        end

        function new_broadcast(obj, ~, ~, count)
        % Description: Updates statistics upon broadcasting new messages from planes.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   messages: Received messages.
        %   count: Number of messages that will be received.

            obj.total_broadcast_packets = obj.total_broadcast_packets + count;
            obj.broadcast_packets = obj.broadcast_packets + count;
        end

        function new_routing_packets(obj, ~, ~, count)
        % Description: Updates statistics upon sending routing packets.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   message: Message to send.
        %   count: Number of messages that will be transmitted.

            obj.routing_packets = obj.routing_packets + count;
            obj.total_routing_packets = obj.total_routing_packets + count;
        end

        function add_busy_time(obj, ~, target, time)
        % Description: Updates statistics when a component is busy (processing or transmitting).
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   target: Affected component's ID.
        %   time: Total busy time.

            obj.total_occupied(target) = obj.total_occupied(target) + time;
            obj.occupied(target) = obj.occupied(target) + time;
        end

        function reception(obj, sim, message, target)
        % Description: Updates statistics upon reception in a component.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   message: Received message.
        %   target: Receiving component's ID.

            % Get info:
            [component, tgt_type] = sim.get_component(target);
            is_broadcast = strcmp(class(message), "broadcast_message_t");

            % If it's a broadcast packet reaching a ground station:
            if strcmp(tgt_type, "ground_station_t") && is_broadcast

                msg = "message";

                % Checks if the ground stations haven't already received this message before:
                if ~obj.last_received_packets.find(message.id)

                    % Saves the message:
                    obj.last_received_packets.push(message.id);

                % If they already have:
                else

                    % Update statistics:
                    obj.total_duplicates = obj.total_duplicates + 1;
                    obj.duplicates = obj.duplicates + 1;
                    msg = "duplicate message";

                    % If the simulation doesn't allow duplicates:
                    if ~sim.config.allow_duplicates

                        % Prints reception:
                        files = [0, 0];
                        if sim.config.print_events
                            files(1) = 1;
                        end
                        if sim.config.log_events
                            files(2) = sim.log_file;
                        end
                        files(files == 0) = [];
                        for file = files
                            fprintf(file, "[%d - MSG%s] Received %s at node %s - ignoring\n", sim.curr_posixtime, message.id, msg, component.name);
                        end

                        % Exits:
                        return;
                    end
                end

                % Gets values for Welford's Algorithm:
                curr_ber = message.ber_integrity;
                x_ber = 1 - curr_ber;
                curr_time = sim.curr_posixtime - message.t_created;
                x_time = double(curr_time);
                curr_hops = double(message.hops);

                % Timeslice statistics:
                obj.received(target) = obj.received(target) + 1;
                obj.bits = obj.bits + message.num_bits;
                
                ts_n = sum(obj.received);
                
                delta_ber = x_ber - obj.ber;
                obj.ber = obj.ber + delta_ber / ts_n;
                obj.ber_M2 = obj.ber_M2 + delta_ber * (x_ber - obj.ber);
                
                delta_time = x_time - obj.time;
                obj.time = obj.time + delta_time / ts_n;
                obj.time_M2 = obj.time_M2 + delta_time * (x_time - obj.time);

                prev_ts_hops_mean = obj.hops / max(1, ts_n - 1);
                obj.hops = obj.hops + curr_hops;
                curr_ts_hops_mean = obj.hops / ts_n;
                obj.hops_M2 = obj.hops_M2 + (curr_hops - prev_ts_hops_mean) * (curr_hops - curr_ts_hops_mean);
    
                % Global statistics:
                obj.total_received(target) = obj.total_received(target) + 1;
                obj.total_bits = obj.total_bits + message.num_bits;
                
                g_n = sum(obj.total_received);
                
                delta_total_ber = x_ber - obj.total_ber;
                obj.total_ber = obj.total_ber + delta_total_ber / g_n;
                obj.total_ber_M2 = obj.total_ber_M2 + delta_total_ber * (x_ber - obj.total_ber);
                
                delta_total_time = x_time - obj.total_time;
                obj.total_time = obj.total_time + delta_total_time / g_n;
                obj.total_time_M2 = obj.total_time_M2 + delta_total_time * (x_time - obj.total_time);

                prev_g_hops_mean = obj.total_hops / max(1, g_n - 1);
                obj.total_hops = obj.total_hops + curr_hops;
                curr_g_hops_mean = obj.total_hops / g_n;
                obj.total_hops_M2 = obj.total_hops_M2 + (curr_hops - prev_g_hops_mean) * (curr_hops - curr_g_hops_mean);
                
                % Jitter:
                src_id = message.airplane_ICAO;
                jitter_val = 0;
                if obj.last_delay_map.isKey(src_id)
                    prev_delay = obj.last_delay_map(src_id);
                    jitter_val = abs(x_time - prev_delay);
                    
                    % Update Timeslice Jitter:
                    obj.jitter_count = obj.jitter_count + 1;
                    prev_ts_jitter_mean = obj.jitter_sum / max(1, obj.jitter_count - 1);
                    obj.jitter_sum = obj.jitter_sum + jitter_val;
                    curr_ts_jitter_mean = obj.jitter_sum / obj.jitter_count;
                    obj.jitter_M2 = obj.jitter_M2 + (jitter_val - prev_ts_jitter_mean) * (jitter_val - curr_ts_jitter_mean);

                    % Update Global Jitter:
                    obj.total_jitter_count = obj.total_jitter_count + 1;
                    prev_g_jitter_mean = obj.total_jitter_sum / max(1, obj.total_jitter_count - 1);
                    obj.total_jitter_sum = obj.total_jitter_sum + jitter_val;
                    curr_g_jitter_mean = obj.total_jitter_sum / obj.total_jitter_count;
                    obj.total_jitter_M2 = obj.total_jitter_M2 + (jitter_val - prev_g_jitter_mean) * (jitter_val - curr_g_jitter_mean);
                end
                obj.last_delay_map(src_id) = x_time;
    
                % If message is late:
                if curr_time > to_posix_ns(sim.config.time_limit)
                    obj.expired = obj.expired + 1;
                    obj.total_expired = obj.total_expired + 1;
                end

                % Raw data logging:
                if obj.raw_idx <= 100000
                    obj.raw_latencies(obj.raw_idx) = double(curr_time) / 1e6;
                    obj.raw_jitters(obj.raw_idx) = jitter_val / 1e6;
                    obj.raw_hops(obj.raw_idx) = double(message.hops);
                    obj.raw_bers(obj.raw_idx) = 1 - curr_ber;
                    obj.raw_status(obj.raw_idx) = 0;
                    obj.raw_idx = obj.raw_idx + 1;
                end
    
                % Prints reception:
                files = [0, 0];
                if sim.config.print_events
                    files(1) = 1;
                end
                if sim.config.log_events
                    files(2) = sim.log_file;
                end
                files(files == 0) = [];
                for file = files
                    fprintf(file, "[%d - MSG%s] Received %s at node %s: BER = %e, Δt = %.2fms\n", sim.curr_posixtime, message.id, msg, component.name, 1 - curr_ber, double(curr_time)/1e6);
                end
            
            % Otherwise, if it's a satellite:
            elseif strcmp(tgt_type, "satellite_t")

                % Update buffer depths:
                curr_depth = double(sim.pathing_algorithm.buffers(target).get_occupied);
                obj.total_buffer_samples = obj.total_buffer_samples + 1;
                
                prev_mean_buffer = obj.sum_buffer_depth / max(1, obj.total_buffer_samples - 1);
                obj.sum_buffer_depth = obj.sum_buffer_depth + curr_depth;
                curr_mean_buffer = obj.sum_buffer_depth / obj.total_buffer_samples;
                
                obj.buffer_depth_M2 = obj.buffer_depth_M2 + (curr_depth - prev_mean_buffer) * (curr_depth - curr_mean_buffer);

                if curr_depth > obj.peak_buffer_depth(target)
                    obj.peak_buffer_depth(target) = curr_depth;
                end
            end

            % Adds reception to message trace:
            if message.from == -1
                trace = message_trace_t(message.from, target, message.id, is_broadcast, sim.curr_posixtime, "message", message);
            else
                trace = message_trace_t(message.from, target, message.id, is_broadcast, sim.curr_posixtime);
            end
            prev_trace = obj.message_paths.find(trace.link_id);
            if ismissing(prev_trace)
                if obj.route_usage
                    trace.rx_time = 1;
                    if trace.rx_time > obj.route_usage_max
                        obj.route_usage_max = trace.rx_time;
                    end
                end
                obj.message_paths.push(trace);
            else
                if obj.route_usage
                    trace.rx_time = prev_trace.rx_time + 1;
                    if trace.rx_time > obj.route_usage_max
                        obj.route_usage_max = trace.rx_time;
                    end
                end
                obj.message_paths.alter(trace.link_id, trace);
            end
        end

        function drop_packet_no_los(obj, sim, message, ~)
        % Description: Updates statistics upon dropping a packet due to having no LoS to other components.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   message: Message to drop.
        %   target: Affected component's ID.

            obj.total_dropped_no_los = obj.total_dropped_no_los + 1;
            obj.dropped_no_los = obj.dropped_no_los + 1;
            if obj.raw_idx <= 100000
                obj.raw_latencies(obj.raw_idx) = double(sim.curr_posixtime - message.t_created) / 1e6;
                obj.raw_jitters(obj.raw_idx) = NaN;
                obj.raw_hops(obj.raw_idx) = double(message.hops);
                obj.raw_bers(obj.raw_idx) = 1 - message.ber_integrity;
                obj.raw_status(obj.raw_idx) = 1;
                obj.raw_idx = obj.raw_idx + 1;
            end
        end

        function drop_packet_buffer_full(obj, sim, message, ~)
        % Description: Updates statistics upon dropping a packet due to having no more buffer capacity.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   message: Message to drop.
        %   target: Affected component's ID.

            obj.total_dropped_buffer = obj.total_dropped_buffer + 1;
            obj.dropped_buffer = obj.dropped_buffer + 1;
            if obj.raw_idx <= 100000
                obj.raw_latencies(obj.raw_idx) = double(sim.curr_posixtime - message.t_created) / 1e6;
                obj.raw_jitters(obj.raw_idx) = NaN;
                obj.raw_hops(obj.raw_idx) = double(message.hops);
                obj.raw_bers(obj.raw_idx) = 1 - message.ber_integrity;
                obj.raw_status(obj.raw_idx) = 2;
                obj.raw_idx = obj.raw_idx + 1;
            end
        end

        function drop_packet_expired(obj, sim, message, ~)
        % Description: Updates statistics upon dropping a packet due to its flight time expiring.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   message: Message to drop.
        %   target: Affected component's ID.

            obj.expired = obj.expired + 1;
            obj.total_expired = obj.total_expired + 1;
            if obj.raw_idx <= 100000
                obj.raw_latencies(obj.raw_idx) = double(sim.curr_posixtime - message.t_created) / 1e6;
                obj.raw_jitters(obj.raw_idx) = NaN;
                obj.raw_hops(obj.raw_idx) = double(message.hops);
                obj.raw_bers(obj.raw_idx) = 1 - message.ber_integrity;
                obj.raw_status(obj.raw_idx) = 3;
                obj.raw_idx = obj.raw_idx + 1;
            end
        end

        function drop_packet_proc_inactive_target(obj, ~, count, ~)
        % Description: Updates statistics upon dropping a packet due to the target being inactive for processing.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   count: Number of affected packets.
        %   target: Affected component's ID.

            obj.dropped_failure = obj.dropped_failure + count;
            obj.total_dropped_failure = obj.total_dropped_failure + count;
            if obj.raw_idx <= 100000
                obj.raw_latencies(obj.raw_idx) = NaN;
                obj.raw_jitters(obj.raw_idx) = NaN;
                obj.raw_hops(obj.raw_idx) = NaN;
                obj.raw_bers(obj.raw_idx) = NaN;
                obj.raw_status(obj.raw_idx) = 4;
                obj.raw_idx = obj.raw_idx + 1;
            end
        end

        function drop_packet_rx_inactive_target(obj, sim, message, ~)
        % Description: Updates statistics upon dropping a packet due to the target being inactive in receptions.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   message: Message to drop.
        %   target: Affected component's ID.

            obj.dropped_failure = obj.dropped_failure + 1;
            obj.total_dropped_failure = obj.total_dropped_failure + 1;
            if obj.raw_idx <= 100000
                obj.raw_latencies(obj.raw_idx) = double(sim.curr_posixtime - message.t_created) / 1e6;
                obj.raw_jitters(obj.raw_idx) = NaN;
                obj.raw_hops(obj.raw_idx) = double(message.hops);
                obj.raw_bers(obj.raw_idx) = 1 - message.ber_integrity;
                obj.raw_status(obj.raw_idx) = 4;
                obj.raw_idx = obj.raw_idx + 1;
            end
        end

        function drop_packet_inactive_link(obj, sim, message, ~)
        % Description: Updates statistics upon dropping a packet due to the link to the target being inactive.
        % Arguments:
        %   obj: custom_statistics_t object.
        %   sim: simulation_t object.
        %   message: Message to drop.
        %   target: Affected component's ID.

            obj.dropped_failure = obj.dropped_failure + 1;
            obj.total_dropped_failure = obj.total_dropped_failure + 1;
            if obj.raw_idx <= 100000
                obj.raw_latencies(obj.raw_idx) = double(sim.curr_posixtime - message.t_created) / 1e6;
                obj.raw_jitters(obj.raw_idx) = NaN;
                obj.raw_hops(obj.raw_idx) = double(message.hops);
                obj.raw_bers(obj.raw_idx) = 1 - message.ber_integrity;
                obj.raw_status(obj.raw_idx) = 4;
                obj.raw_idx = obj.raw_idx + 1;
            end
        end
    end
end

