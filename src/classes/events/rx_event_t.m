classdef rx_event_t < link_event_t
% Description: Reception event object.

    methods

        function treat_event(obj, sim)
        % Description: Treats an RX event.
        % Arguments:
        %   obj: rx_event_t object.
        %   sim: Simulation object.

            % Get components:
            if obj.source == -1
                source = struct("name", obj.message.airplane_ICAO);
            else
                source = get_component(sim, obj.source);
            end
            [target, target_class] = get_component(sim, obj.target);
            reception = true;

            % Get message type:
            msg_type = class(obj.message);

            % Check if component is active:
            if target_class == "satellite_t" && ~target.is_active

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
                    fprintf("[%d - MSG%s] Satellite %s is inactive, dropping packet (%s)\n", sim.curr_posixtime, obj.message.id, target.name, msg_type);
                end

                % Updates statistics:
                for stats_algorithm = sim.statistics_algorithms
                    stats_algorithm.drop_packet_rx_inactive_target(sim, obj.message, who);
                end

                return;
            end

            % If a satellite received the packet:
            if ~strcmp(target_class, "ground_station_t")

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
                    fprintf(file, "[%d - MSG%s] Treating RX event from %s to %s (%s)\n", sim.curr_posixtime, obj.message.id, source.name, target.name, msg_type);
                end
    
                % Sets new values:
                obj.message.t_arrival = sim.curr_posixtime;
                obj.message.from = obj.source;
    
                % Checks if it's necessary to create a processing event:
                create_proc = sim.pathing_algorithm.is_empty_buffer(obj.target);
    
                % Tries inserting the message in the buffer:
                tf = sim.pathing_algorithm.insert_buffer(obj.target, obj.message);
                if tf
    
                    % Creates a processing event if necessary:
                    if create_proc
                        queue_proc_event(obj, sim, obj.target);
                    end
    
                % If the buffer was full:
                else
    
                    % Warns packet drop:
                    reception = false;
                    files = [0, 0];
                    if sim.config.print_events
                        files(1) = 1;
                    end
                    if sim.config.log_events
                        files(2) = sim.log_file;
                    end
                    files(files == 0) = [];
                    for file = files
                        fprintf(file, "[%d - MSG%s] Dropped message at node %s - buffer is full\n", sim.curr_posixtime, obj.message.id, target.name);
                    end
                    
                    % Updates statistics:
                    for stats_algorithm = sim.statistics_algorithms
                        stats_algorithm.drop_packet_buffer_full(sim, obj.message, target.id);
                    end
                end

            % If it's a ground station, update the message:
            else
                
                % Sets new values:
                obj.message.t_arrival = sim.curr_posixtime;
                obj.message.from = obj.source;

                % Warns the simulation:
                sim.ground_station_reception(obj.message);
            end

            % Updates statistics upon reception:
            if reception
                for stats_algorithm = sim.statistics_algorithms
                    stats_algorithm.reception(sim, obj.message, obj.target);
                end
            end
        end
    end
end
