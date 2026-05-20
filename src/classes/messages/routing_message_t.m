classdef routing_message_t < message_t
% Description: Routing messages used by custom pathing algorithms to provoke a specific action.

    properties (Access = public)
    
        % Routing message type:
        type;
    end

    methods
        function obj = routing_message_t(creator, t_created, t_arrival, num_bits, config)
        % Description: routing_message_t constructor.
        % Arguments:
        %   creator: Message creator (component ID).
        %   t_created: Time of creation.
        %   t_arrival: Time of arrival at the current component (modified throughout the hops).
        %   num_bits: Number of bits of the payload.
        %   config: Extra configuration parameters (message ID, BER integrity, bit array, and type).
        % Returns:
        %   obj: routing_message_t object.

            arguments
                creator (1, 1) double = missing
                t_created (1, 1) int64 = 0
                t_arrival (1, 1) int64 = 0
                num_bits (1, 1) double = missing
                config.id (1, 1) string = string(randi([100000, 999999])) + "R"
                config.ber_integrity (1, 1) double = 1
                config.bits (1, :) double = missing
                config.type (1, 1) double = 1
                config.t_transmission (1, 1) int64 = 0
            end

            % Sets values:
            obj = obj@message_t(creator, t_created, t_arrival, num_bits, id=config.id, ber_integrity=config.ber_integrity, bits=config.bits, t_transmission=config.t_transmission);
            obj.type = config.type;
        end
    end
end
