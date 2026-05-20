classdef simulation_t < handle
% Description: Simulation object.

    properties (Access = public)

        % Configuration:
        config;

        % Components:
        ground_stations;
        planes;
        satellites;

        % Time:
        curr_time_idx;
        curr_timeslice int64;
        next_timeslice int64;
        final_time int64;
        curr_posixtime int64;
        broadcast_posixtime int64;

        % Scenario:
        sc;

        % Custom algorithms:
        pathing_algorithm custom_pathing_t;
        statistics_algorithms (1, :) custom_statistics_t;

        % Messages:
        TT;
        msg_idx;
        curr_msgs;
        prev_msgs;

        % Auxiliary values:
        save_path;
        reg_idx;
        log_file;

        % InfluxDB connection:
        conn;

        % Satellite position memmap file:
        plane_sat_pos_memmap;
        sat_idx;
    end
    
    methods

        function obj = simulation_t(config, sc, gs_pos, mf)
        % Description: simulation_t constructor.
        % Arguments:
        %   config: Configuration struct.
        %   sc: Satellite scenario object.
        %   gs_pos: Position of the ground stations.
        %   mf: Satellite position memory-mapped file.
        % Returns:
        %   obj: simulation_t object.

            arguments
                config (1, 1) struct {mustBeNonmissing} = missing
                sc (1, 1) satelliteScenario {mustBeNonmissing} = missing
                gs_pos (:, 3) double {mustBeNonempty} = []
                mf (1, 1) parallel.pool.Constant = missing
            end
            
            % Establish Connection:
            if config.use_db
                try
                    obj.conn = influxdb("hostURL", config.hostURL, ...
                        "authToken", config.authToken, ...
                        "org", config.org);
                    disp("Successfully connected to InfluxDB at " + config.hostURL);
                catch ME
                    error("Connection Failed. Is the 'influxd' server running? " + ME.message);
                end
            end

            % Sets up configuration parameters:
            obj.config = config;
            obj.curr_time_idx = 1;
            if config.use_db
                [obj.curr_timeslice, obj.final_time] = get_times(obj.conn, obj.config.read_bucket, obj.config.squitter_measurement);
            else
                obj.curr_timeslice = int64(posixtime(obj.config.t_base) * 1e9);
                obj.final_time = int64(posixtime(obj.config.t_base + seconds(obj.config.t_stop)) * 1e9);
            end
            obj.curr_posixtime = obj.curr_timeslice;
            obj.broadcast_posixtime = obj.curr_posixtime;
            obj.final_time = min(int64(posixtime(obj.config.t_base + seconds(obj.config.t_stop)) * 1e9), obj.final_time);
            obj.next_timeslice = min(obj.curr_timeslice + int64(obj.config.update_dt * 1e9), obj.final_time);
            obj.plane_sat_pos_memmap = mf.Value;

            % Saves the satellite scenario:
            obj.sc = sc;

            % Gets positions:
            [obj.sat_idx, plane_pos, sat_pos] = get_positions(obj.plane_sat_pos_memmap, obj.curr_timeslice, obj.config.t_base, obj.config.dt);

            % Creates ground stations:
            obj.ground_stations = create_ground_stations(obj.sc, obj.config, gs_pos);

            % Creates airplanes:
            obj.planes = create_planes(obj.sc, obj.config, plane_pos);

            % Creates satellites:
            obj.satellites = create_satellites(obj.sc, obj.config, sat_pos);

            % Defines pathing algorithm:
            obj.pathing_algorithm = eval(obj.config.pathing + "(obj.config)");

            % Defines all statistics algorithms:
            num_algs = numel(obj.config.statistics);
            obj.statistics_algorithms(num_algs) = basic_statistics_t;
            for s = 1:num_algs
                obj.statistics_algorithms(s) = eval(obj.config.statistics(s) + "(obj.config)");
            end
            
            % Calculates and updates all LoS:
            all_los = update_los(obj, plane_pos, sat_pos);

            % Merges positions:
            all_pos = [gs_pos; plane_pos; sat_pos];

            % Calculates and updates all propagation delays:
            update_prop_delay(obj, all_los, all_pos);

            % Calculates and updates all BER, BPS, and TX delays:
            update_ber_bps_tx(obj, all_los, all_pos);

            % Get statistics folder:
            obj.save_path = obj.config.stats_dir + "t" + string(obj.curr_time_idx) + "_" + string(obj.curr_timeslice) + "/";
            
            % If requested, log events:
            obj.log();

            % Updates the pathing algorithm:
            obj.pathing_algorithm.update(obj);

            % If the initial setup shouldn't affect the start:
            if obj.config.external_start

                % Gives feedback on the simulation's state, if requested:
                if obj.config.print_progress
                    time_str = string(datetime('now') - obj.config.sim_start_time, 'hh:mm:ss.SSS');
                    fprintf("[WORKER %d: +%s] Running external start of %s...\n", obj.reg_idx, time_str, obj.pathing_algorithm.name);
                end

                % While there are events:
                while ~ismissing(obj.pathing_algorithm.peek_event())
                    
                    % Treat the pathing event:
                    event = obj.pathing_algorithm.pop_event();
                    obj.curr_posixtime = event.res_time;
                    event.treat_event(obj);
    
                    % Updates statistics:
                    for stats_algorithm = obj.statistics_algorithms
                        stats_algorithm.treated_event(obj, event);
                    end
                end

                % Reset current time:
                obj.curr_posixtime = obj.curr_timeslice;
            end

            % Gets new messages:
            if config.use_db

                % If the DB is used:
                obj.prev_msgs = 0;
                messages = get_messages(obj.conn, obj.config.read_bucket, obj.config.squitter_measurement, obj.curr_timeslice, obj.config.update_dt);
                obj.curr_msgs = length(messages);
                
                % Creates and queues the new RX events:
                for msg = 1:obj.curr_msgs
                    rx = rx_event_t(obj.curr_posixtime, messages(msg).Unix_Time_ns, obj.config.total_grounds + obj.config.total_planes + messages(msg).SAT_ID, messages(msg), -1);
                    obj.pathing_algorithm.push_event(rx);
                end
    
                % Register new broadcasted messages:
                for stats_algorithm = obj.statistics_algorithms
                    stats_algorithm.new_broadcast(obj, messages, obj.curr_msgs);
                end
    
                % Initialize the message timetable:
                obj.init_TT();

            % Otherwise:
            else
                obj.broadcast_posixtime = obj.curr_posixtime - obj.config.broadcast_dt;
                while obj.broadcast_posixtime + obj.config.broadcast_dt < obj.next_timeslice
                    obj.broadcast_posixtime = obj.broadcast_posixtime + obj.config.broadcast_dt;
                    for p = 1:obj.config.total_planes
                        event = broadcast_event_t(obj.curr_posixtime, obj.broadcast_posixtime, obj.config.total_grounds + p);
                        obj.pathing_algorithm.push_event(event);
                    end
                end
            end
        end

        function delete(obj)
        % Description: simulation_t destructor.
        %   obj: simulation_t object.

            if obj.log_file ~= -1
                fclose(obj.log_file);
            end

            fprintf("Clean-up finished.\n");
        end

        function save_backup(obj, curr_pos)
        % Description: Saves the simulation into a backup folder.
        % Arguments:
        %   obj: simulation_t object.
        %   curr_pos: Current position index.

            % Tries creating backup folder:
            backup_folder = obj.config.stats_dir + "backup/";
            if ~isfolder(backup_folder)
                status = mkdir(backup_folder);
                if ~status
                    error("Unable to setup backup folder");
                end
            end

            % Saves simulation object and current position index:
            sim = obj;
            save(backup_folder + "sim.mat", "sim", "curr_pos", "-v7.3");
        end

        function log(obj)
        % Description: Starts logging events if requested.
        % Arguments:
        %   obj: simulation_t object.

            % If requested, log events:
            if obj.config.log_events
                if ~isfolder(obj.save_path)
                    status = mkdir(obj.save_path);
                    if ~status
                        error("Unable to setup statistics folder");
                    end
                end
                log_name = obj.save_path + "timestep.log";
                if obj.log_file >= 3
                    fclose(obj.log_file);
                end
                if ~isfile(log_name)
                    obj.log_file = fopen(log_name, "w");
                else
                    obj.log_file = fopen(log_name, "a");
                end
                if obj.log_file < 3
                    error("Failed to open file on %s.", obj.save_path + "timestep.log");
                end
            else
                obj.log_file = -1;
            end
        end

        function tf = update(obj)
        % Description: Updates the simulation.
        % Arguments:
        %   obj: simulation_t object.
        % Returns:
        %   tf: Boolean indicating if the simulation is over or not.

            % Checks if the user wants to save and exit:
            if isfile(obj.config.stats_dir + "backup/stop.txt")
                obj.save_backup(obj.next_timeslice);
            end

            % Initialize return value:
            tf = true;

            % Resets statistics:
            for stats_algorithm = obj.statistics_algorithms
                stats_algorithm.reset_stats();
            end

            % Advance time index:
            obj.curr_time_idx = obj.curr_time_idx + 1;

            % Advance timeslices:
            obj.curr_timeslice = obj.next_timeslice;
            obj.next_timeslice = min(obj.next_timeslice + int64(obj.config.update_dt * 1e9), obj.final_time);
            obj.curr_posixtime = obj.curr_timeslice;

            % If the simulation is over:
            if obj.curr_timeslice >= obj.next_timeslice
                tf = false;

            % Otherwise:
            else

                % Get statistics folder:
                obj.save_path = obj.config.stats_dir + "t" + string(obj.curr_time_idx) + "_" + string(obj.curr_timeslice) + "/";
    
                % If requested, log events:
                obj.log();
                    
                % Gets positions:
                ground_pos = reshape([obj.ground_stations.pos], [3, obj.config.total_grounds])';
                [obj.sat_idx, plane_pos, sat_pos] = get_positions(obj.plane_sat_pos_memmap, obj.curr_timeslice, obj.config.t_base, obj.config.dt);
                new_pos = [ground_pos; plane_pos; sat_pos];
    
                % Updates satellite positions:
                for s = 1:obj.config.total_satellites
                    obj.satellites(s).update(sat_pos(s, :), obj);
                end

                % Updates airplane positions:
                for p = 1:obj.config.total_planes
                    obj.planes(p).update(plane_pos(p, :), obj);
                end
            
                % Calculates and updates all LoS:
                all_los = update_los(obj, plane_pos, sat_pos);
    
                % Calculates and updates all propagation delays:
                update_prop_delay(obj, all_los, new_pos);
    
                % Calculates and updates all BER, BPS, and TX delays:
                update_ber_bps_tx(obj, all_los, new_pos);
    
                % Updates the current algorithm:
                obj.pathing_algorithm.update(obj);

                % Gets new messages:
                if obj.config.use_db

                    % If the DB is used:
                    messages = get_messages(obj.conn, obj.config.read_bucket, obj.config.squitter_measurement, obj.curr_timeslice, obj.config.update_dt);
                    obj.prev_msgs = obj.curr_msgs;
                    obj.curr_msgs = length(messages);
                    
                    % Creates and queues the new RX events:
                    for msg = 1:obj.curr_msgs
                        rx = rx_event_t(obj.curr_posixtime, messages(msg).Unix_Time_ns, obj.config.total_grounds + obj.config.total_planes + messages(msg).SAT_ID, messages(msg), -1);
                        obj.pathing_algorithm.push_event(rx);
                    end
    
                    % Register new broadcasted messages:
                    for stats_algorithm = obj.statistics_algorithms
                        stats_algorithm.new_broadcast(obj, messages, obj.curr_msgs);
                    end
        
                    % Initialize the message timetable:
                    obj.init_TT();
   
                % Otherwise, checks if there are new broadcasts:
                else
                    while obj.curr_posixtime > obj.broadcast_posixtime + obj.config.broadcast_dt
                        obj.broadcast_posixtime = obj.broadcast_posixtime + obj.config.broadcast_dt;
                    end
                    while obj.broadcast_posixtime + obj.config.broadcast_dt < obj.next_timeslice
                        obj.broadcast_posixtime = obj.broadcast_posixtime + obj.config.broadcast_dt;
                        for p = 1:obj.config.total_planes
                            event = broadcast_event_t(obj.curr_posixtime, obj.broadcast_posixtime, obj.config.total_grounds + p);
                            obj.pathing_algorithm.push_event(event);
                        end
                    end
                end
            end
        end

        function run(obj)
        % Description: Runs the simulation.
        % Arguments:
        %   obj: simulation_t object.

            % Run while the simulation is not over:
            done = false;
            while ~done
    
                % Gives feedback on the simulation's state, if requested:
                if obj.config.print_progress
                    time_str = string(datetime('now') - obj.config.sim_start_time, 'hh:mm:ss.SSS');
                    fprintf("[WORKER %d: +%s] Running t%d of %s...\n", obj.reg_idx, time_str, obj.curr_time_idx, obj.pathing_algorithm.name);
                end
    
                % While there's events for the current timeslice:
                while true
    
                    % Gets next event:
                    next_event = obj.pathing_algorithm.peek_event();
    
                    % If there are no more remaining events, end execution loop:
                    if ismissing(next_event)
                        break;
                    end
    
                    % Gets next event resolution time:
                    next_time = next_event.res_time;
    
                    % Guarantee that leftover events execute until there are no more remaining:
                    if ~ismissing(obj.next_timeslice) && next_time >= obj.next_timeslice
                        break;
                    end
                    
                    % Treats event:
                    obj.curr_posixtime = next_time;
                    obj.pathing_algorithm.pop_event();
                    next_event.treat_event(obj);
    
                    % Updates statistics:
                    for stats_algorithm = obj.statistics_algorithms
                        stats_algorithm.treated_event(obj, next_event);
                    end
                end

                % Write to InfluxDB:
                if obj.config.use_db
                    TT_final = obj.TT(~isnat(obj.TT.Time), :);
                    TT_final = sortrows(TT_final);
                    if ~isempty(TT_final)
                        writeData(obj.conn, TT_final, obj.config.write_bucket, obj.config.outputs_measurement, ...
                            "Tags", ["SAT_ID", "airplane_ICAO", "airplane_callsign"]);
                    end
                end
    
                % Shows global and timeslice statistics for each statistics algorithm:
                for stats_algorithm = obj.statistics_algorithms
                    new_dir = obj.save_path + stats_algorithm.file_name + "/";
                    stats_algorithm.show_stats(obj, new_dir);
                end

                % Checks if the simulation is over:
                done = ~obj.update();
            end
        end

        function [component, type] = get_component(obj, idx)
        % Description: Returns the component object and type through the component's index.
        % Arguments:
        %   obj: simulation_t object.
        %   idx: Index of the component.
        % Returns:
        %   component: Component object.
        %   type: Type of component.

            % Throw an error if the index is invalid:
            if isnan(idx) || idx < 1 || idx > obj.config.total_grounds + obj.config.total_planes + obj.config.total_satellites
                warning("Provided index (%s) is invalid or out of bounds, returning blank", string(idx));
                component = component_t(0, missing);
                type = "unknown";

            % If the index is a valid component:
            else

                % If it's a ground station:
                if idx <= obj.config.total_grounds
                    component = obj.ground_stations(idx);

                % If it's an aircraft:
                elseif idx <= obj.config.total_grounds + obj.config.total_planes
                    component = obj.planes(idx - obj.config.total_grounds);

                % If it's a satellite:
                else
                    component = obj.satellites(idx - obj.config.total_grounds - obj.config.total_planes);
                end

                % Get the type:
                type = class(component);
            end
        end

        function [ground_pos, plane_pos, sat_pos] = get_pos(obj)
        % Description: Builds the components position matrixes.
        % Arguments:
        %   obj: simulation_t object.
        % Returns:
        %   ground_pos: Ground stations' position.
        %   plane_pos: Planes' position.
        %   sat_pos: Satellites' position.

            % Gathers ground stations' positions:
            ground_pos = reshape([obj.ground_stations.pos], [3, obj.config.total_grounds])';

            % Gathers planes' positions:
            plane_pos = reshape([obj.planes.pos], [3, obj.config.total_planes])';

            % Gathers satellites' positions:
            sat_pos = reshape([obj.satellites.pos], [3, obj.config.total_satellites])';
        end

        function los = update_los(obj, plane_pos, sat_pos)
        % Description: Updates the components' LoS sparse arrays and returns the LoS sparse matrix.
        % Arguments:
        %   obj: simulation_t object.
        %   plane_pos: Planes' position.
        %   sat_pos: Satellites' position.
        % Returns:
        %   los: LoS sparse matrix.

            % Gets LoS matrix:
            los = calc_los(obj, plane_pos, sat_pos);

            % Assigns ground stations' LoS:
            for g = 1:obj.config.total_grounds
                obj.ground_stations(g).los = los(g, :);
            end

            % Assigns planes' LoS:
            if ~obj.config.use_db
                init_sum = obj.config.total_grounds;
                for p = 1:obj.config.total_planes
                    obj.planes(p).los = los(init_sum + p, :);
                end
            end

            % Assigns satellites' LoS:
            init_sum = obj.config.total_grounds + obj.config.total_planes;
            for s = 1:obj.config.total_satellites
                obj.satellites(s).los = los(init_sum + s, :);
            end

        end

        function los = calc_los(obj, plane_pos, sat_pos)
        % Description: Calculates and returns the LoS sparse matrix.
        % Arguments:
        %   obj: simulation_t object.
        %   plane_pos: Planes' position.
        %   sat_pos: Satellites' position.
        % Returns:
        %   los: LoS sparse matrix.

            % Initializes LoS matrix:
            los = zeros(obj.config.total_grounds + obj.config.total_planes + obj.config.total_satellites);
            
            % Calculates uplink LoS:
            if ~obj.config.use_db
                init_sum = obj.config.total_grounds;
                los(init_sum + (1:obj.config.total_planes), (init_sum + obj.config.total_planes + 1):end) = has_los_up(plane_pos, sat_pos, obj.config.los_min_elev);
            end

            % Calculates crosslink LoS:
            init_sum = obj.config.total_grounds + obj.config.total_planes;
            for s = 1:(obj.config.total_satellites - 1)
                los(init_sum + s, (init_sum + s + 1):end) = has_los_cross(sat_pos(s, :), sat_pos((s + 1):end, :), obj.config.Re);
                los((init_sum + s + 1):end, init_sum + s) = los(init_sum + s, (init_sum + s + 1):end)';
            end

            % Calculates downlink LoS:
            downlink_scs = [obj.satellites(obj.config.downlink_idxs).sc_obj];
            for g = 1:obj.config.total_grounds
                los(init_sum + obj.config.downlink_idxs, g) = has_los_down(obj.ground_stations(g).sc_obj(), downlink_scs, obj.config.los_min_elev, datetime(double(obj.curr_timeslice)/1e9, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC'));
                los(g, init_sum + obj.config.downlink_idxs) = los(init_sum + obj.config.downlink_idxs, g)';
            end

            % Convert to sparse matrix:
            los = sparse(los);
        end

        function update_prop_delay(obj, los, pos)
        % Description: Updates the components' propagation delay arrays.
        % Arguments:
        %   obj: simulation_t object.
        %   los: Global LoS sparese matrix.
        %   pos: Global position matrix.

            % Gets propagation delay matrix:
            prop_delay = calc_prop_delay(obj, los, pos, pos);

            % Assigns ground stations' propagation delays:
            for g = 1:obj.config.total_grounds
                obj.ground_stations(g).prop_delay = prop_delay(g, :);
            end

            % Assigns planes' propagation delays:
            if ~obj.config.use_db
                init_sum = obj.config.total_grounds;
                for p = 1:obj.config.total_planes
                    obj.planes(p).prop_delay = prop_delay(init_sum + p, :);
                end
            end

            % Assigns satellites' propagation delays:
            init_sum = obj.config.total_grounds + obj.config.total_planes;
            for s = 1:obj.config.total_satellites
                obj.satellites(s).prop_delay = prop_delay(init_sum + s, :);
            end

        end

        function prop = calc_prop_delay(obj, los, src_pos, dst_pos)
        % Description: Calculates and returns the propagation delay matrix.
        % Arguments:
        %   obj: simulation_t object.
        %   los: Global LoS sparese matrix.
        %   src_pos: Sources' position.
        %   dst_pos: Destinations' position.
        % Returns:
        %   prop: Global propagation delay matrix.

            % Initializes propagation delay matrix:
            prop = Inf(size(los));

            % Gets the indexes of the sources and destinations of LoS:
            [src, dst] = find(los);

            % Gets the positions of the sources and destinations:
            s_pos = src_pos(src, :);
            d_pos = dst_pos(dst, :);

            % Calculates propagation delays:
            prop(sub2ind(size(prop), src, dst)) = vecnorm(s_pos - d_pos, 2, 2) ./ obj.config.c;
            
            % Converts propagation delays to nanoseconds:
            prop = round(prop * 1e9);
        end

        function update_ber_bps_tx(obj, los, pos)
        % Description: Updates the components' BER, capacity, and transmission delay arrays.
        % Arguments:
        %   obj: simulation_t object.
        %   los: Global LoS sparese matrix.
        %   pos: Global position matrix.

            % Gets propagation delay matrix:
            [ber, bps, tx] = calc_ber_bps_tx(obj, los, pos);

            % Assigns ground stations' BER, BPS, and TX delay values:
            for g = 1:obj.config.total_grounds
                obj.ground_stations(g).ber = ber(g, :);
                obj.ground_stations(g).bps = bps(g, :);
                obj.ground_stations(g).tx_delay = tx(g, :);
            end

            % Assigns planes' BER, BPS, and TX delay values:
            if ~obj.config.use_db
                init_sum = obj.config.total_grounds;
                for p = 1:obj.config.total_planes
                    obj.planes(p).ber = ber(init_sum + p, :);
                    obj.planes(p).bps = bps(init_sum + p, :);
                    obj.planes(p).tx_delay = tx(init_sum + p, :);
                end
            end

            % Assigns satellites' BER, BPS, and TX delay values:
            init_sum = obj.config.total_grounds + obj.config.total_planes;
            for s = 1:obj.config.total_satellites
                obj.satellites(s).ber = ber(init_sum + s, :);
                obj.satellites(s).bps = bps(init_sum + s, :);
                obj.satellites(s).tx_delay = tx(init_sum + s, :);
            end
        end

        function [ber, bps, tx] = calc_ber_bps_tx(obj, los, pos)
        % Description: Calculates and returns the BER, capacity, and transmission delay matrixes.
        % Arguments:
        %   obj: simulation_t object.
        %   los: Global LoS sparese matrix.
        %   pos: Global position matrix.
        % Returns:
        %   ber: Global BER matrix.
        %   bps: Global capacity matrix.
        %   tx: Global transmission delay matrix.

            % Initializes BER, BPS, and TX delay matrixes:
            ber = Inf(size(los));
            bps = zeros(size(los));
            tx = Inf(size(los));

            % Gets the indexes of the sources and destinations of LoS:
            [src, dst] = find(los);
            iters = length(src);

            % Calculates BER, BPS, and TX delayS:
            for i = 1:iters

                % Retrieves current source and destination:
                s = src(i);
                d = dst(i);

                % Gets current link:
                if d <= obj.config.total_grounds
                    link = obj.config.link_data.uplink;
                elseif s <= obj.config.total_grounds + obj.config.total_planes
                    link = obj.config.link_data.downlink;
                else
                    link = obj.config.link_data.crosslink;
                end

                % Calculates auxiliary values:
                pathloss = path_loss(norm(pos(s, :) - pos(d, :)), link.frequency_hz);
                snr = link.received_power - link.noise_power - pathloss;
                linear_snr = 10^(snr / 10);
                ebno_db = snr - 10 * log10(link.bits_per_symbol);

                % Calculates BER:
                if isempty(link.modulation_extra2)
                    if isempty(link.modulation_extra1)
                        curr_ber = berawgn(ebno_db, link.modulation_type, link.modulation_order);
                    else
                        curr_ber = berawgn(ebno_db, link.modulation_type, link.modulation_order, link.modulation_extra1);
                    end
                else
                    curr_ber = berawgn(ebno_db, link.modulation_type, link.modulation_order, link.modulation_extra1, link.modulation_extra2);
                end

                % Saves BER, BPS, and TX delay:
                ber(s, d) = curr_ber;
                bps(s, d) = link.bandwidth_hz * log2(1 + linear_snr);
                tx(s, d) = obj.config.num_bits / bps(s, d);
            end

            % Converts transmission delays to nanoseconds:
            tx = round(tx * 1e9);
        end

        function init_TT(obj)
        % Description: Create the message timetable.
        % Arguments:
        %   obj: simulation_t object.

            % If the DB is used:
            if obj.config.use_db
    
                % Initialize:
                obj.msg_idx = 1;
                obj.TT = timetable( ...
                    repmat(NaT, obj.curr_msgs + obj.prev_msgs, 1), ...
                    zeros(obj.curr_msgs + obj.prev_msgs, 1, 'int64'), ...
                    zeros(obj.curr_msgs + obj.prev_msgs, 1, 'int64'), ...
                    NaN(obj.curr_msgs + obj.prev_msgs, 1), ...
                    NaN(obj.curr_msgs + obj.prev_msgs, 1), ...
                    NaN(obj.curr_msgs + obj.prev_msgs, 1), ...
                    NaN(obj.curr_msgs + obj.prev_msgs, 1), NaN(obj.curr_msgs + obj.prev_msgs, 1), NaN(obj.curr_msgs + obj.prev_msgs, 1), ...
                    NaN(obj.curr_msgs + obj.prev_msgs, 1), NaN(obj.curr_msgs + obj.prev_msgs, 1), NaN(obj.curr_msgs + obj.prev_msgs, 1), ...
                    strings(obj.curr_msgs + obj.prev_msgs, 1), ...
                    strings(obj.curr_msgs + obj.prev_msgs, 1), ...
                    zeros(obj.curr_msgs + obj.prev_msgs, 1, 'int64'), ...
                    strings(obj.curr_msgs + obj.prev_msgs, 1), ...
                    strings(obj.curr_msgs + obj.prev_msgs, 1), ...
                    NaN(obj.curr_msgs + obj.prev_msgs, 1), ...
                    NaN(obj.curr_msgs + obj.prev_msgs, 1), ...
                    NaN(obj.curr_msgs + obj.prev_msgs, 1), ...
                    'VariableNames', { ...
                        'Unix_Time_ns', 'reception_time_ns', 'ToA', 'FoA', 'AoA_H', ...
                        'rx_pos_x', 'rx_pos_y', 'rx_pos_z', ...
                        'rx_vel_x', 'rx_vel_y', 'rx_vel_z', ...
                        'SAT_RM', 'SAT_ID', ...
                        'airplane_Unix_timestamp', 'airplane_ICAO', 'airplane_callsign', ...
                        'airplane_lat', 'airplane_lon', 'airplane_alt'} ...
                );
            end
        end

        function ground_station_reception(obj, message)
        % Description: Deals with reception on ground stations.
        % Arguments:
        %   obj: simulation_t object.
        %   message: Received message.

            % If the DB is used:
            if obj.config.use_db

                % Satellite position:
                rx_pos_x = message.SAT_Position_ecef(1);
                rx_pos_y = message.SAT_Position_ecef(2);
                rx_pos_z = message.SAT_Position_ecef(3);
                
                % Satellite velocity:
                rx_vel_x = message.SAT_Velocity_ecef(1);
                rx_vel_y = message.SAT_Velocity_ecef(2);
                rx_vel_z = message.SAT_Velocity_ecef(3);
              
                % Prepare other variables:
                SAT_ID = string(message.SAT_ID);
                airplane_ICAO = string(message.airplane_ICAO);
                airplane_callsign = string(message.airplane_callsign);
    
                % Appends extra table space if necessary:
                if obj.msg_idx > height(obj.TT)
                    extra = obj.TT(1:obj.curr_msgs + obj.prev_msgs, :);
                    extra.Time(:) = NaT;
                    obj.TT = [obj.TT; extra];
                end
                
                % Insert in timetable:
                obj.TT.Time(obj.msg_idx) = message.Time;
                obj.TT.Unix_Time_ns(obj.msg_idx) = message.Unix_Time_ns;
                obj.TT.reception_time_ns(obj.msg_idx) = message.t_arrival;
                obj.TT.ToA(obj.msg_idx) = message.ToA;
                obj.TT.FoA(obj.msg_idx) = message.FoA;
                obj.TT.AoA_H(obj.msg_idx) = message.AoA_H;
                obj.TT.rx_pos_x(obj.msg_idx) = rx_pos_x;
                obj.TT.rx_pos_y(obj.msg_idx) = rx_pos_y;
                obj.TT.rx_pos_z(obj.msg_idx) = rx_pos_z;
                obj.TT.rx_vel_x(obj.msg_idx) = rx_vel_x;
                obj.TT.rx_vel_y(obj.msg_idx) = rx_vel_y;
                obj.TT.rx_vel_z(obj.msg_idx) = rx_vel_z;
                obj.TT.SAT_RM(obj.msg_idx) = message.SAT_RM;
                obj.TT.SAT_ID(obj.msg_idx) = SAT_ID;
                obj.TT.airplane_Unix_timestamp(obj.msg_idx) = message.airplane_Unix_timestamp;
                obj.TT.airplane_ICAO(obj.msg_idx) = airplane_ICAO;
                obj.TT.airplane_callsign(obj.msg_idx) = airplane_callsign;
                obj.TT.airplane_lat(obj.msg_idx) = message.airplane_lat;
                obj.TT.airplane_lon(obj.msg_idx) = message.airplane_lon;
                obj.TT.airplane_alt(obj.msg_idx) = message.airplane_alt;
    
                % Increment write index:
                obj.msg_idx = obj.msg_idx + 1;
            end
        end
    end
end

