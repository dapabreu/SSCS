classdef (Abstract) link_event_t < event_t
% Description: Link event.

    properties (Access = public)

        % Message:
        message

        % Message's source:
        source
    end

    methods

        function obj = link_event_t(gen_time, res_time, target, message, source)
        % Description: link_event_t constructor.
        % Arguments:
        %   gen_time: Time of generation for the event.
        %   res_time: Time of resolution for the event.
        %   target: Transmission target.
        %   message: Message being transmitted.
        %   source: Transmission source.
        % Returns:
        %   obj: link_event_t object.

            arguments
                gen_time (1, 1) double = missing
                res_time (1, 1) double = missing
                target (1, 1) double = missing
                message (1, 1) message_t = message_t()
                source (1, 1) double = missing
            end
            
            % Sets values:
            obj@event_t(gen_time, res_time, target);
            obj.message = message;
            obj.source = source;
        end
    end
end

