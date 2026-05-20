classdef message_trace_t
% Description: Class that defines a message trace (path).

    properties (Access = public)

        % Component that sent the message:
        source;

        % Component that received the message:
        target;

        % Link identifier:
        link_id;

        % Message's ID:
        message_id;

        % Message (optional):
        message;

        % Indicates if the message was a plane broadcast message:
        is_broadcast;

        % Time of reception:
        rx_time int64;
    end
    
    methods
        function obj = message_trace_t(source, target, message_id, is_broadcast, rx_time, extra)
        % Description: message_trace_t constructor.
        % Arguments:
        %   source: Source of message.
        %   target: Destination of message.
        %   message_id: Message's ID.
        %   is_broadcast: Indicates if the message is a plane broadcast.
        %   tx_time: Time of transmission.
        %   extra: Extra message parameter.
        % Returns:
        %   obj: message_trace_t object.

            arguments
                source (1, 1) double = NaN
                target (1, 1) double = NaN
                message_id (1, 1) string = "missing"
                is_broadcast (1, 1) logical = true
                rx_time (1, 1) int64 = 0
                extra.message (1, 1) message_t = message_t()
            end

            % Sets values:
            obj.source = source;
            obj.target = target;
            if source < target
                obj.link_id = string(source) + "-" + string(target);
            else
                obj.link_id = string(target) + "-" + string(source);
            end
            obj.message_id = message_id;
            obj.is_broadcast = is_broadcast;
            obj.rx_time = rx_time;
            obj.message = extra.message;
        end
    end
end

