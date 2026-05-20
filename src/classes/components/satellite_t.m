classdef satellite_t < component_t
% Description: Satellite component object.

    properties (Access = public)

        % Characteristics:
        downlink;  % 1 if its capable of sending downlinks, 0 otherwise
        failure_model;
        is_active (1, 1) logical;
        inactive_timer;
        can_send;
        BER_base;
    end

    methods

        function obj = satellite_t(id, sc_obj, downlink, config)
        % Description: satellite_t constructor.
        % Arguments:
        %   id: Satellite's ID.
        %   sc_obj: Satellite's satelliteScenario object.
        %   downlink: Indicates if the satellite is capable of downlinking.
        %   config: Extra configuration parameters (failure rate, processing delay, satellite's name, and LLA for position instead of states(sc_obj)).
        % Returns:
        %   obj: satellite_t object.

            arguments
                id (1, 1) double = missing
                sc_obj (1, 1) = missing
                downlink (1, 1) logical = 0
                config.failure_model (1, 1) struct = struct('node_failure', 0, 'node_downtime', 0, 'base_ber', 0, 'link_failure', 0)
                config.processing_delay (1, 1) double {mustBeNonnegative} = 0
                config.name (1, 1) string = string(id)
                config.first_pos (1, 3) double = [0, 0, 0]
            end

            % Sets values:
            obj@component_t(id, sc_obj, processing_delay=config.processing_delay, name=config.name, first_pos=config.first_pos);
            obj.downlink = downlink;
            obj.failure_model = config.failure_model;
            obj.is_active = true;
            obj.inactive_timer = 0;
            obj.can_send = true;
            if obj.failure_model.base_ber > 0
                mu_log = log10(obj.failure_model.base_ber);
                sigma_log = 0.5;
                obj.BER_base = 10^(normrnd(mu_log, sigma_log));
                obj.BER_base = min(obj.BER_base, 0.5);
            else
                obj.BER_base = 0;
            end
        end

        function roll_failure(obj, sim)
        % Description: Re-rolls for failure under non-nominal conditions.
        % Arguments:
        %   obj: satellite_t object.
        %   sim: simulation_t object.

            if obj.failure_model.node_failure > 0
                if ~obj.is_active && obj.inactive_timer > 0
                    obj.inactive_timer = obj.inactive_timer - 1;
                    if obj.inactive_timer <= 0
                        obj.is_active = true;
                    end
                elseif obj.is_active
                    if rand(1) < obj.failure_model.node_failure
                        obj.is_active = false;
                        obj.inactive_timer = obj.failure_model.node_downtime / sim.config.update_dt;
                        sim.pathing_algorithm.clear_buffer(obj.id, sim, true);
                    end
                end
            end
        end

        function roll_sending(obj)
        % Description: Re-rolls for link failure under non-nominal conditions.
        % Arguments:
        %   obj: satellite_t object.

            if obj.failure_model.link_failure > 0
                obj.can_send = rand(1) > obj.failure_model.link_failure;
            else
                obj.can_send = true;
            end
        end

        function adj_sats = get_adjacent_satellites(obj, sim)
        % Description: Get adjacent satellites with LoS.
        % Arguments:
        %   obj: satellite_t object.
        %   sim: Simulation object.
        % Returns:
        %   adj_sats: Adjacent satellites.

            % Gets values:
            total_grounds = sim.config.total_grounds;
            total_planes = sim.config.total_planes;
            total_satellites = sim.config.total_satellites;
            sats_per_plane = sim.config.sats_per_plane;
            centered = mod(obj.id - total_grounds - total_planes, sats_per_plane);

            % Gets initial adjacent satellites:
            top = obj.id + 1;
            bottom = obj.id - 1;
            left = obj.id - sats_per_plane;
            right = obj.id + sats_per_plane;

            % If it's the last satellite of the orbit, correct top satellite:
            if centered == 0
                top = top - sats_per_plane;
            end

            % If it's the first satellite of the orbit, correct bottom satellite:
            if centered == 1
                bottom = bottom + sats_per_plane;
            end

            % If the left satellite subceeds orbit indexes, correct left satellite:
            if left < total_grounds + total_planes + 1
                adj_line = obj.tx_delay((total_grounds + total_planes + total_satellites - sats_per_plane + 1):end) + obj.prop_delay((total_grounds + total_planes + total_satellites - sats_per_plane + 1):end);
                [~, closest_idxs] = sort(adj_line);
                left = total_grounds + total_planes + total_satellites + closest_idxs(1) - sats_per_plane;
            end

            % If the right satellite exceeds orbit indexes, correct right satellite:
            if right > total_grounds + total_planes + total_satellites
                adj_line = obj.tx_delay(total_grounds + total_planes + (1:sats_per_plane)) + obj.prop_delay(total_grounds + total_planes + (1:sats_per_plane));
                [~, closest_idxs] = sort(adj_line);
                right = total_grounds + total_planes + closest_idxs(1);
            end

            % Gathers adjacent satellites and verifies LoS:
            adj_sats = [top, bottom, left, right];
            adj_sats(isinf(obj.tx_delay(adj_sats) + obj.prop_delay(adj_sats))) = [];
        end

        function update(obj, new_pos, sim)
        % Description: Updates the satellite.
        % Arguments:
        %   obj: satellite_t object.
        %   new_pos: New position.
        %   sim: simulation_t object.

            % Updates values:
            update@component_t(obj, new_pos);

            % Update failure conditions:
            obj.roll_failure(sim);
        end
    end
end
