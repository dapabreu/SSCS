classdef proc_event_t < event_t
% Description: Processing event object.

    methods

        function treat_event(obj, sim)
        % Description: Treats a processing event.
        % Arguments:
        %   obj: proc_event_t object.
        %   sim: Simulation object.

            % Gets values:
            [target, tgt_class] = get_component(sim, obj.target);
            message = sim.pathing_algorithm.peek_buffer(obj.target);

            % If there's no messages to process, return:
            if ismissing(message)
                return;
            end

            % Get message type:
            msg_type = class(message);

            % Check if component is active:
            if tgt_class == "satellite_t" && ~target.is_active

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
                    fprintf("[%d - MSG%s] Satellite %s is inactive, not processing (%s)\n", sim.curr_posixtime, message.id, target.name, msg_type);
                end

                % Updates statistics:
                for stats_algorithm = sim.statistics_algorithms
                    stats_algorithm.drop_packet_proc_inactive_target(sim, 1, who);
                end

                return;
            end

            % Prints event:
            files = [0, 0];
            if sim.config.print_events
                files(1) = 1;
            end
            if sim.config.log_events
                files(2) = sim.log_file;
            end
            files(files == 0) = [];
            for file = files
                fprintf(file, "[%d - MSG%s] Treating processing event at %s (%s)\n", sim.curr_posixtime, message.id, target.name, msg_type);
            end

            % If it's a routing message:
            if strcmp(class(message), "routing_message_t")

                % Removes message from buffer:
                sim.pathing_algorithm.remove_buffer(obj.target);

                % Does the specified action:
                sim.pathing_algorithm.action(sim, message, obj.target);

                % Queues processing event if necessary:
                if ~sim.pathing_algorithm.is_empty_buffer(obj.target)
                    queue_proc_event(obj, sim, obj.target);
                end

            % If it's a normal broadcast:
            else

                % Gets destination nodes:
                next = sim.pathing_algorithm.send{obj.target};

                % If they're invalid:
                if all(isnan(next)) || all(~target.los(next))

                    % Removes message from buffer:
                    sim.pathing_algorithm.remove_buffer(obj.target);

                    % Warns packet drop:
                    files = [0, 0];
                    if sim.config.print_events
                        files(1) = 1;
                    end
                    if sim.config.log_events
                        files(2) = sim.log_file;
                    end
                    files(files == 0) = [];
                    for file = files
                        fprintf(file, "[%d - MSG%s] Dropped message at node %s - no node to send to\n", sim.curr_posixtime, message.id, target.name);
                    end

                    % Updates statistics:
                    for stats_algorithm = sim.statistics_algorithms
                        stats_algorithm.drop_packet_no_los(sim, message, target.id);
                    end

                    % Updates pathing algorithm:
                    sim.pathing_algorithm.treat_dropped_broadcast(sim, obj.target);
                    
                    % Queues processing event if necessary:
                    if ~sim.pathing_algorithm.is_empty_buffer(obj.target)
                        queue_proc_event(obj, sim, obj.target);
                    end

                % If the message has expired:
                elseif sim.curr_posixtime - message.t_created > to_posix_ns(sim.config.time_limit)

                    % Removes message from buffer:
                    sim.pathing_algorithm.remove_buffer(obj.target);

                    % Warns packet drop:
                    files = [0, 0];
                    if sim.config.print_events
                        files(1) = 1;
                    end
                    if sim.config.log_events
                        files(2) = sim.log_file;
                    end
                    files(files == 0) = [];
                    for file = files
                        fprintf(file, "[%d - MSG%s] Dropped message at node %s - expired\n", sim.curr_posixtime, message.id, target.name);
                    end
                    
                    % Updates statistics:
                    for stats_algorithm = sim.statistics_algorithms
                        stats_algorithm.drop_packet_expired(sim, message, target.id);
                    end

                    % Queues processing event if necessary:
                    if ~sim.pathing_algorithm.is_empty_buffer(obj.target)
                        queue_proc_event(obj, sim, obj.target);
                    end

                % If the message is valid:
                else

                    % Treat the event:
                    sim.pathing_algorithm.treat_processing_event(sim, obj, message);
                end
            end
        end
    end
end
