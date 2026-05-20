% function InputData = generate_measurements(aircraft_data, sat_pos_all, sat_vel_all, isDetected, cfg, squitter, PrecompData)
% %GENERATE_MEASUREMENTS Generate TOA, FOA, AOA (with noise) for visible satellites
% %
% % Input:
% %   aircraft_data : struct/table with fields (ground truth)
% %       .icao  
% %       .t (POSIX time vector)
% %       .pos_ecef [Ntx3], .vel_ecef [Ntx3], .lat [Ntx1], .lon [Ntx1], .alt [Ntx1]
% %   sat_pos_all   : [3 x Nt x Nsat] satellite ECEF positions
% %   sat_vel_all   : [3 x Nt x Nsat] satellite ECEF velocities
% %    isDetected   : [Nsat x Nt ] with 1 being detected and 0 no
% %   cfg           : configuration struct (noise sigmas, thresholds, constants)
% %   squitter      : ADS-B squitters
% %
% % Output:
% %   InputData : table with one row per (satellite, message) pair
% 
% 
% c0 = physconst('LightSpeed');
% 
% % % Inicialización de tabla de salida
% % InputData = table();
% 
% % Inicialización de tabla de salida
% InputData = table();
% numSatellites = sum(isDetected(:)); % Número de satélites detectados 
% %InputData = table('Size', [maxRows, 16], 'VariableTypes', repmat({"datetime", "int64", "double", "double", "double", "double", "double", "double", "int64", "string", "string", "double", "double", "double", "double", "double"}, 1, 1), 'VariableNames', {'Time','Unix_Time_ns','ToA','FoA','AoA_H', 'SAT_Position_ecef','SAT_Velocity_ecef','SAT_ID', 'airplane_Unix_timestamp','airplane_ICAO','airplane_callsign','airplane_lat','airplane_lon','airplane_alt','airplane_vx','airplane_vy','airplane_vz'});
% 
% rowIndex = 1; % Inicializar el índice de fila
% 
% for k = 1:numel(aircraft_data.t)
% 
%     if ~any(isDetected(:,k))
%         continue;
%     end
% 
%     % === 1) Tiempo y posición de la aeronave ===
%     % t_emit = datetime(aircraft_data.t(k), 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
%      t_emit = aircraft_data.t(k);
%      %t_emit.TimeZone = 'UTC';
% 
%     % === 2) Posición/velocidad de satélites que detectan el ads-b msg ===
%     SAT_pos = squeeze(sat_pos_all(:, k, isDetected(:,k)))'; % en el instante que se envió la señal
%     SAT_vel = squeeze(sat_vel_all(:, k, isDetected(:,k)))'; % en el instante que se envió la señal
%     SAT_ID = find(isDetected(:,k));
%     % === 3) Medidas (TOA, FOA, AOA) ===
% 
%     % 3.1 TOA 
%     R_emit = vecnorm(SAT_pos - aircraft_data.pos_ecef(k,:), 2, 2);
%     %TOA_clean = R_emit / c0;
%     TOA = R_emit / c0 + cfg.sigma.TOA * randn(size(SAT_pos,1),1);
% 
%     % 3.2 FOA
%     los_vec = SAT_pos - aircraft_data.pos_ecef(k,:);
%     los_unit = los_vec ./ vecnorm(los_vec, 2, 2);
%     rel_vel = SAT_vel - aircraft_data.vel_ecef(k,:);
%     %FOA_clean = -cfg.link.fADSB_Hz * sum(rel_vel .* los_unit, 2) / c0;
%     FOA = -cfg.link.fADSB_Hz * sum(rel_vel .* los_unit, 2)/c0 + cfg.sigma.FOA * randn(size(SAT_pos,1),1);
% 
%     % 3.3 AOA (horizontal)
%     dx = aircraft_data.pos_ecef(k,1) - SAT_pos(:,1);
%     dy = aircraft_data.pos_ecef(k,2) - SAT_pos(:,2);
%     %AOA_clean = atan2(dy, dx);
%     AOA = atan2(dy, dx) + cfg.sigma.AOA * randn(size(SAT_pos,1),1);
% 
%     % === 4) Metadatos ===
%     satellite_Time = t_emit + seconds(TOA);
%     unix_time_ns = int64((posixtime(aircraft_data.t(k)) + TOA) * 1e9);
%     % Sat position
%     % Get all satellites at all reception times (it's almost the same at
%     % emission time, but between 30-60 metres of difference), maybe we could avoid this
%     %[SAT_pos, SAT_vel] = GetSatelliteState(PrecompData, satellite_Time, SAT_ID); % it's very time consuming
% 
%     % === 5) Attitude ===
%     %lla_recv = ecef2lla(SAT_pos); % sat lat, lon
%     % 
%     % 
%     % % SAT_pos: N x 3 matriz con posiciones ECEF
%     % % SAT_vel: N x 3 matriz con velocidades ECEF
%     % N = size(SAT_pos, 1);
%     % 
%     % % Prealocar salida: cada DCM será 3x3, podemos guardarlas en un array 3x3xN
%     % R_body2ECEF_all = zeros(3, 3, N);
%     % 
%     % for i = 1:N
%     %     % Extraer posición y velocidad del satélite i
%     %     r = SAT_pos(i, :);
%     %     v = SAT_vel(i, :);
%     % 
%     %     % 1) Ejes LVLH candidatos
%     %     z_c = -r / norm(r);                % nadir
%     %     h_vec = cross(r, v);               % momento angular
%     %     y_c = h_vec / norm(h_vec);         % normal orbital
%     %     x_c = cross(y_c, z_c);             % prograde
%     % 
%     %     % 2) Orthonormalización
%     %     x = x_c / norm(x_c);
%     %     z = z_c / norm(z_c);
%     %     y = cross(z, x); y = y / norm(y);
%     % 
%     %     % 3) Construir DCM (body -> ECEF)
%     %     R_body2ECEF_all(:, :, i) = [x; y; z].';  % columnas = ejes del body
%     % end
%     % 
%     % % Convertir el array 3x3xN en un cell array, cada celda = matriz 3x3
%     % DCM_cell = squeeze(num2cell(R_body2ECEF_all, [1 2]));
% 
% 
%     fila = table( ...
%         satellite_Time, unix_time_ns, TOA, FOA, AOA, SAT_pos, SAT_vel, SAT_ID, ...
%         repmat(posxitime(squitter{1}.time(k)), size(SAT_pos,1), 1), ...
%         repmat(squitter{1}.icao(k), size(SAT_pos,1), 1), ...
%         repmat(squitter{1}.callsign(k), size(SAT_pos,1), 1),...
%         repmat(squitter{1}.lat(k), size(SAT_pos,1), 1),...
%         repmat(squitter{1}.lon(k), size(SAT_pos,1), 1),...
%         repmat(squitter{1}.alt(k), size(SAT_pos,1), 1),...
%         repmat(squitter{1}.vx(k), size(SAT_pos,1), 1),...
%         repmat(squitter{1}.vy(k), size(SAT_pos,1), 1),...
%         repmat(squitter{1}.vz(k), size(SAT_pos,1), 1));
% 
%      %fila = table( ...
%          % satellite_Time, unix_time_ns, TOA, FOA, AOA,SAT_pos, SAT_vel, DCM_cell, SAT_ID, ...
%          % repmat( table2array(squitter{1,1}(k,:)), size(SAT_pos,1), 1));
% 
%      InputData = [InputData; fila];
% 
% %     InputData(rowIndex:rowIndex+size(fila, 1)-1, :) = fila; % Asignar fila a la tabla prealocada
% %     rowIndex = rowIndex + size(fila, 1); % Actualizar el índice de fila
%  end
% % Asignar nombres de columnas
% InputData.Properties.VariableNames = {
%     'Time','Unix_Time_ns','ToA','FoA','AoA_H', 'SAT_Position_ecef','SAT_Velocity_ecef','SAT_ID' ...
%     'airplane_Unix_timestamp','airplane_ICAO','airplane_callsign','airplane_lat','airplane_lon','airplane_alt','airplane_vx','airplane_vy','airplane_vz'};
% end



function InputData = generate_measurements(aircraft_data, sat_pos_all, sat_vel_all, isDetected, cfg, squitter)
%GENERATE_MEASUREMENTS Generate TOA, FOA, AOA for visible satellites
%
% One row per (satellite, message) pair

c0 = physconst('LightSpeed');

% === Número total de filas ===
numRows = sum(isDetected(:));
if numRows == 0
    InputData = table();
    return
end

% Convertir a posixtime
aricraft_time = posixtime(aircraft_data.t);
aircraft_data.t.TimeZone = '';

% === Prealocación ===
Time              = datetime.empty(numRows,0);
Unix_Time_ns      = zeros(numRows,1,'int64');
ToA               = zeros(numRows,1);
FoA               = zeros(numRows,1);
AoA_H             = zeros(numRows,1);

SAT_Position_ecef = zeros(numRows,3);
SAT_Velocity_ecef = zeros(numRows,3);
SAT_ID            = zeros(numRows,1,'int32');

airplane_Unix_timestamp = zeros(numRows,1,'int64');
airplane_ICAO           = strings(numRows,1);
airplane_callsign       = strings(numRows,1);
airplane_lat            = zeros(numRows,1);
airplane_lon            = zeros(numRows,1);
airplane_alt            = zeros(numRows,1);
airplane_vx             = zeros(numRows,1);
airplane_vy             = zeros(numRows,1);
airplane_vz             = zeros(numRows,1);

rowIndex = 1;

wgs84 = wgs84Ellipsoid('meter');

% === Bucle temporal ===
for k = 1:numel(aircraft_data.t)

    if ~any(isDetected(:,k))
        continue
    end

    % Tiempo de emisión (POSIX)
    t_emit = aricraft_time(k);

    % Satélites detectados
    SAT_ID_k = find(isDetected(:,k));
    SAT_pos  = squeeze(sat_pos_all(:,k,SAT_ID_k))';
    SAT_vel  = squeeze(sat_vel_all(:,k,SAT_ID_k))';
    Ns       = size(SAT_pos,1);

    idx = rowIndex:(rowIndex+Ns-1);

    % === TOA ===
    R_emit = vecnorm(SAT_pos - aircraft_data.pos_ecef(k,:), 2, 2);
     %    R = sqrt( (SAT_pos(:,1) - aircraft_data.pos_ecef(k,1)).^2 + ... 
     % (SAT_pos(:,2) - aircraft_data.pos_ecef(k,2)).^2 + ... 
     % (SAT_pos(:,3) - aircraft_data.pos_ecef(k,3)).^2 ... 
     % ); 

    TOA_k  = R_emit / c0 + cfg.sigma.TOA * randn(Ns,1);

    % === FOA ===
    los_vec  = SAT_pos - aircraft_data.pos_ecef(k,:);
    los_unit = los_vec ./ vecnorm(los_vec,2,2);
    rel_vel  = SAT_vel - aircraft_data.vel_ecef(k,:);
    FOA_k    = -cfg.link.fADSB_Hz * sum(rel_vel .* los_unit, 2) / c0 ...
               + cfg.sigma.FOA * randn(Ns,1);
    % vRel = dot((SAT_pos - aircraft_data.pos_ecef(k,:)), (aircraft_data.vel_ecef(k,:) - SAT_vel), 2) ./ R; 
    % foa = cfg.link.fADSB_Hz .* vRel ./ c0 + + cfg.sigma.FOA * randn(Ns,1); 

    % === AOA (pseudo-horizontal ECEF) ===
    % dx = aircraft_data.pos_ecef(k,1) - SAT_pos(:,1);
    % dy = aircraft_data.pos_ecef(k,2) - SAT_pos(:,2);
    % AOA_k_aux = atan2(dy, dx) + cfg.sigma.AOA * randn(Ns,1);

    % === AOA horizontal (NED en el satélite) ===    
    
    lla_sat = ecef2lla(SAT_pos, 'WGS84');
    
    [xNorth, yEast, ~] = ecef2ned(aircraft_data.pos_ecef(k,1), aircraft_data.pos_ecef(k,2),aircraft_data.pos_ecef(k,3), ...
        lla_sat(:,1), lla_sat(:,2), lla_sat(:,3), wgs84);
    
    AOA_k = atan2(yEast, xNorth) + cfg.sigma.AOA * randn(Ns,1);

    % === Tiempo de recepción ===
    Time(idx,1)         = aircraft_data.t(k) + seconds(TOA_k); 
    Unix_Time_ns(idx) = int64((t_emit + TOA_k) * 1e9);

    % === Medidas ===
    ToA(idx)   = TOA_k;
    FoA(idx)   = FOA_k;
    AoA_H(idx) = AOA_k;

    % === Satélite ===
    SAT_Position_ecef(idx,:) = SAT_pos;
    SAT_Velocity_ecef(idx,:) = SAT_vel;
    SAT_ID(idx)              = SAT_ID_k;

    % === Aeronave (repetido por satélite) ===
    airplane_Unix_timestamp(idx) = int64(squitter.time(k) * 1e9);
    airplane_ICAO(idx)           = squitter.icao(k);
    airplane_callsign(idx)       = squitter.callsign(k);
    airplane_lat(idx)            = squitter.lat(k);
    airplane_lon(idx)            = squitter.lon(k);
    airplane_alt(idx)            = squitter.alt(k);
    airplane_vx(idx)             = squitter.vx(k);
    airplane_vy(idx)             = squitter.vy(k);
    airplane_vz(idx)             = squitter.vz(k);

    rowIndex = rowIndex + Ns;
end

% === Construcción final de la tabla ===
InputData = table( ...
    Time, Unix_Time_ns, ToA, FoA, AoA_H, ...
    SAT_Position_ecef, SAT_Velocity_ecef, SAT_ID, ...
    airplane_Unix_timestamp, airplane_ICAO, airplane_callsign, ...
    airplane_lat, airplane_lon, airplane_alt, ...
    airplane_vx, airplane_vy, airplane_vz );
end