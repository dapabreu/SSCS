classdef (Abstract) event_t < handle & matlab.mixin.Heterogeneous
% Description: Event object.
    
    properties (Access = public)

        % Times at which the event was generated:
        gen_time int64

        % Time at which the event is resolved:
        res_time int64

        % Target executing the event:
        target
    end

    methods (Static, Sealed, Access = protected)
        function default_object = getDefaultScalarElement
            default_object = rx_event_t;
        end
    end

    methods (Abstract)
        treat_event(obj, sim)
        % Description: Treats an event.
        % Arguments:
        %   obj: Event object.
        %   sim: Simulation object.
    end

    methods
        function obj = event_t(gen_time, res_time, target)
        % Description: event_t constructor.
        % Arguments:
        %   gen_time: Time of generation for the event.
        %   res_time: Time of resolution for the event.
        %   target: Transmission target.
        % Returns:
        %   obj: event_t object.

            arguments
                gen_time (1, 1) int64 = 0
                res_time (1, 1) int64 = 0
                target (1, 1) double = missing
            end
            
            % Sets values:
            obj.gen_time = gen_time;
            obj.res_time = res_time;
            obj.target = target;
        end

        function queue_proc_event(~, sim, who)
        % Description: Creates and queues a processing event.
        % Arguments:
        %   obj: proc_event_t object.
        %   sim: Simulation object.
        %   who: Component that'll process.

            % Gets values:
            [component, cmp_class] = sim.get_component(who);
            processing_delay = component.processing_delay;

            % Check if component is active:
            if cmp_class == "satellite_t" && ~component.is_active
                return;
            end

            % Increments the component's interval:
            [t_i, t_f] = sim.pathing_algorithm.increment_interval(who, sim.curr_posixtime, processing_delay);

            % Updates statistics:
            for stats_algorithm = sim.statistics_algorithms
                stats_algorithm.add_busy_time(sim, who, processing_delay);
            end

            % Creates and queues the processing event:
            proc = proc_event_t(t_i, t_f, who);
            sim.pathing_algorithm.push_event(proc);
        end

        function queue_tx_event(obj, sim, message)
        % Description: Creates and queues a TX event.
        % Arguments:
        %   obj: proc_event_t object.
        %   sim: Simulation object.
        %   message: Message object.
        
            % Gets values:
            [component, cmp_class] = sim.get_component(obj.target);
            tx_delay = component.tx_delay;
            next = sim.pathing_algorithm.send{obj.target};

            % Check if component is active:
            if cmp_class == "satellite_t" && ~component.is_active
                return;
            end

            % For each destination:
            for n = next

                % If it's invalid, skip it:
                if isnan(n) || ~component.los(n)
                    continue;
                end

                % Increments the component's interval:
                [t_i, t_f] = sim.pathing_algorithm.increment_interval(obj.target, sim.curr_posixtime, tx_delay(n));

                % Updates statistics:
                for stats_algorithm = sim.statistics_algorithms
                    stats_algorithm.add_busy_time(sim, obj.target, tx_delay(n));
                end

                % Creates and queues the TX event:
                message.t_transmission = t_i;
                tx = tx_event_t(t_i, t_f, n, message, obj.target);
                sim.pathing_algorithm.push_event(tx);
            end
        end

        function queue_rx_event(obj, sim, source, message)
        % Description: Creates and queues an RX event.
        % Arguments:
        %   obj: proc_event_t object.
        %   sim: Simulation object.
        %   source: Source of the RX event.
        %   message: Message.

            % Gets component:
            [component, cmp_class] = sim.get_component(source);

            % Check if component is active:
            if cmp_class == "satellite_t" && ~component.is_active
                return;
            end

            % Creates and queues the RX event:
            rx = rx_event_t(sim.curr_posixtime, sim.curr_posixtime + component.prop_delay(obj.target), obj.target, message, source);
            sim.pathing_algorithm.push_event(rx);
        end
    end
end

