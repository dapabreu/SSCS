classdef broadcast_event_t < event_t
% Description: Broadcast event.
    
    methods

        function treat_event(obj, sim)
        % Description: Treats a broadcast event.
        % Arguments:
        %   obj: broadcast_event_t object.
        %   sim: Simulation object.

            % Gets values:
            target = get_component(sim, obj.target);

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
                fprintf("[%d] Treating broadcast event from %s\n", sim.curr_posixtime, target.name);
            end
            
            % Gets destinations and transmission times:
            txs_idxs = find(target.los);
            tx_times = target.tx_delay(txs_idxs);
            num_tx = numel(txs_idxs);

            % For each transmission:
            for t = 1:num_tx

                % Broadcast delay:
                delay = rand() * sim.config.broadcast_delay;

                % Create the specific message:
                new_msg = broadcast_message_t('Time', datetime(double(sim.curr_posixtime + delay)/1e9, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC'), 'Unix_Time_ns', sim.curr_posixtime + delay + tx_times(t), 'SAT_ID', txs_idxs(t), 'airplane_Unix_timestamp', sim.curr_posixtime + delay, 'airplane_ICAO', target.name, 'airplane_callsign', target.name);
                
                % Updates statistics:
                for stats_algorithm = sim.statistics_algorithms
                    stats_algorithm.new_broadcast(sim, new_msg, 1);
                end

                % Creates and queues the TX event:
                tx = tx_event_t(sim.curr_posixtime, sim.curr_posixtime + delay + tx_times(t), txs_idxs(t), new_msg, obj.target);
                sim.pathing_algorithm.push_event(tx);
            end
        end
    end
end

