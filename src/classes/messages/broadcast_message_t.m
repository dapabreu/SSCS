classdef broadcast_message_t < message_t
% Description: Broadcast message object.

    properties (Access = public)

        % Absolute ToA on the satellite:
        Time;

        % Time in UNIX ns:
        Unix_Time_ns

        % Relative ToA from emission to reception on satellite:
        ToA;

        % Frequency of Arrival:
        FoA;

        % Angle of Arrival (Horizontal):
        AoA_H;

        % Satellite position:
        SAT_Position_ecef;

        % Satellite velocity:
        SAT_Velocity_ecef;

        % Satellite Rotation Matrix:
        SAT_RM;

        % Satellite ID:
        SAT_ID;

        % Aircraft message emission time:
        airplane_Unix_timestamp;

        % Aircraft ICAO ID:
        airplane_ICAO;

        % Aircraft callsign:
        airplane_callsign;

        % Aircraft position:
        airplane_lat;
        airplane_lon;
        airplane_alt;

        % Region:
        region;
    end
    
    methods

        function obj = broadcast_message_t(config)
        % Description: broadcast_message_t constructor.
        % Arguments:
        %   config: Configuration parameters.
        % Returns:
        %   obj: message_t object.

            arguments
                config.num_bits (1, 1) double = 577
                config.ber_integrity (1, 1) double = 1
                config.Time (1, 1) datetime = datetime('now')
                config.Unix_Time_ns (1, 1) int64 = 0
                config.ToA (1, 1) double = 0
                config.FoA (1, 1) double = 0
                config.AoA_H (1, 1) double = 0
                config.SAT_Position_ecef (1, 3) double = [0 0 0]
                config.SAT_Velocity_ecef (1, 3) double = [0 0 0]
                config.SAT_RM (1, 1) string = "[[0;0;0];[0;0;0];[0;0;0]]"
                config.SAT_ID (1, 1) double = missing
                config.airplane_Unix_timestamp (1, 1) int64 = 0
                config.airplane_ICAO (1, 1) string = ""
                config.airplane_callsign (1, 1) string = ""
                config.airplane_lat (1, 1) double = 0
                config.airplane_lon (1, 1) double = 0
                config.airplane_alt (1, 1) double = 0
                config.region (1, 1) string = ""
            end

            % Initialize
            obj@message_t(config.airplane_ICAO, config.Unix_Time_ns, config.Unix_Time_ns, config.num_bits, "ber_integrity", config.ber_integrity, "id", config.airplane_ICAO + "-" + compose("%03d", config.SAT_ID) + "-" + string(config.Unix_Time_ns));

            % Absolute ToA on the satellite:
            obj.Time = config.Time;
    
            % Time in UNIX ns:
            obj.Unix_Time_ns = config.Unix_Time_ns;
    
            % Relative ToA from emission to reception on satellite:
            obj.ToA = config.ToA;
    
            % Frequency of Arrival:
            obj.FoA = config.FoA;
    
            % Angle of Arrival (Horizontal):
            obj.AoA_H = config.AoA_H;
    
            % Satellite position:
            obj.SAT_Position_ecef = config.SAT_Position_ecef;
    
            % Satellite velocity:
            obj.SAT_Velocity_ecef = config.SAT_Velocity_ecef;
    
            % Satellite Rotation Matrix:
            obj.SAT_RM = config.SAT_RM;
    
            % Satellite ID:
            obj.SAT_ID = config.SAT_ID;
    
            % Aircraft message emission time:
            obj.airplane_Unix_timestamp = config.airplane_Unix_timestamp;
    
            % Aircraft ICAO ID:
            obj.airplane_ICAO = config.airplane_ICAO;
    
            % Aircraft callsign:
            obj.airplane_callsign = config.airplane_callsign;
    
            % Aircraft position:
            obj.airplane_lat = config.airplane_lat;
            obj.airplane_lon = config.airplane_lon;
            obj.airplane_alt = config.airplane_alt;

            % Region:
            obj.region = config.region;
        end
    end
end

