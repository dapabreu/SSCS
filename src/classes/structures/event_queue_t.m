classdef event_queue_t < bucket_queue_t
% Description: Event queue object based in buckets (dictionary pointing to arrays).

    methods
        function obj = event_queue_t()
        % Description: event_queue_t constructor.
        % Returns:
        %   obj: event_queue_t object.

            obj = obj@bucket_queue_t(key_type = "int64", comp_param = "res_time");
        end
    end
end
