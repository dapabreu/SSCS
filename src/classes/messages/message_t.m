classdef message_t < matlab.mixin.Heterogeneous
% Description: Message object.

    properties (Access = public)

        % Message ID:
        id;

        % Component that sent this message:
        from;

        % Component that created this message:
        creator;

        % Time of creation of this message:
        t_created int64;

        % Time of arrival to the current component:
        t_arrival int64;

        % Time of transmission from previous component:
        t_transmission int64;

        % BER integrity (higher is better - [0, 1]):
        ber_integrity;

        % Hop count:
        hops;

        % Payload:
        num_bits;
    end
    
    methods

        function obj = message_t(creator, t_created, t_arrival, num_bits, config)
        % Description: message_t constructor.
        % Arguments:
        %   creator: Message creator (component ID).
        %   t_created: Time of creation.
        %   t_arrival: Time of arrival at the current component (modified throughout the hops).
        %   num_bits: Number of bits of the payload.
        %   config: Extra configuration parameters (message ID, BER integrity, bit array, ...).
        % Returns:
        %   obj: message_t object.

            arguments
                creator (1, 1) double = missing
                t_created (1, 1) int64 = 0
                t_arrival (1, 1) int64 = 0
                num_bits (1, 1) double = missing
                config.id (1, 1) string = string(randi([100000, 999999]))
                config.ber_integrity (1, 1) double = 1
                config.bits (1, :) double = missing
                config.t_transmission (1, 1) int64 = 0
                config.hops (1, 1) double = 0
            end

            % Sets values:
            obj.id = config.id;
            obj.ber_integrity = config.ber_integrity;
            obj.creator = creator;
            obj.t_created = t_created;
            obj.t_arrival = t_arrival;
            obj.t_transmission = config.t_transmission;
            obj.num_bits = num_bits;
            obj.hops = config.hops;
        end
    end
end
