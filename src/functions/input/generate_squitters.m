% function squitters = generate_squitters(ground_truth,cfg)
% %UNTITLED Summary of this function goes here
% %   Detailed explanation goes here
%     ntracks = numel(ground_truth);
%     squitters = cell(ntracks,1);
% 
%     for i = 1:ntracks
% 
%         rows_time = ground_truth(i).t; 
%         Ns = numel(rows_time); % number of squitters
%         rows_icao = repmat(ground_truth(i).icao, Ns, 1); 
%         rows_callsign = repmat(ground_truth(i).callsign, Ns, 1); 
% 
%         pos_noise = cfg.adsb.sigma_pos * randn(Ns,3);
%         vel_noise = cfg.adsb.sigma_vel * randn(Ns,3);
% 
%         pos_ecef_noisy = ground_truth(i).pos_ecef + pos_noise;
%         lla = ecef2lla(pos_ecef_noisy);   
% 
%         vel_ecef_noisy = ground_truth(i).vel_ecef + vel_noise;
% 
%         T = table(rows_time, rows_icao, rows_callsign, lla(:,1), lla(:,2), lla(:,3),vel_ecef_noisy(:,1),vel_ecef_noisy(:,2),vel_ecef_noisy(:,3), ...
%             'VariableNames', {'time','icao','callsign','lat','lon','alt', 'vx', 'vy','vz'});
%         squitters{i} = T;
% 
%     end
% 
% 
% end


function squitters = generate_squitters(ground_truth, cfg)
% GENERATE_SQUITTERS
% Añade ruido a las trayectorias para simular squitters ADS-B.
% - El ruido de posición se añade en el marco local ENU:
%   * E y N ~ N(0, sigma_pos^2)
%   * U ~ N(0, sigma_pos_u^2)  -> normalmente 0 para HPA
% - El ruido de velocidad puede añadirse en ENU (horizontal) o en ECEF según cfg.
%
% Requisitos:
% - ground_truth(i).pos_ecef : [Ns x 3] en metros (ECEF)
% - ground_truth(i).vel_ecef : [Ns x 3] en m/s (ECEF)
% - ground_truth(i).t        : [Ns x 1]
% - ground_truth(i).icao, .callsign
%
% - cfg.adsb.sigma_pos   : sigma horizontal (m), p.ej. 12.3
% - cfg.adsb.sigma_pos_u : sigma vertical (m), p.ej. 0 (opcional, default 0)
% - cfg.adsb.sigma_vel   : sigma de velocidad (m/s) si se usa ruido en E,N (y opcional U)

    ntracks = numel(ground_truth);
    squitters = cell(ntracks,1);

    % Defaults seguros
    if ~isfield(cfg, 'adsb'), cfg.adsb = struct(); end
    if ~isfield(cfg.adsb, 'sigma_pos_m'), error('cfg.adsb.sigma_pos_m es obligatorio'); end
    if ~isfield(cfg.adsb, 'sigma_pos_u'), cfg.adsb.sigma_pos_u = 0.0; end
    if ~isfield(cfg.adsb, 'sigma_vel'), cfg.adsb.sigma_vel = 0.0; end  % 0 => sin ruido

    sigma_xy = cfg.adsb.sigma_pos_m;       % m
    sigma_u  = cfg.adsb.sigma_pos_u;     % m (0 para error sólo en horizontal)

    for i = 1:ntracks

        rows_time     = posixtime(ground_truth(i).t);
        Ns            = numel(rows_time);
        rows_icao     = repmat(ground_truth(i).icao, Ns, 1);
        rows_callsign = repmat(ground_truth(i).callsign, Ns, 1);

        pos_ecef_gt = ground_truth(i).pos_ecef;  % [Ns x 3]

        % --- Posición: ruido sólo horizontal en ENU ---
        pos_ecef_noisy = zeros(Ns,3);
        %lla_noisy      = zeros(Ns,3);  % lat(rad), lon(rad), alt(m)

        % Usamos la base local en el propio punto (lat/lon) de la posición GT
        % Si no tienes lat/lon GT, puedes obtenerlo con ecef2lla(pos_ecef_gt)
        lla_gt = ecef2lla(pos_ecef_gt,'WGS84');   % [lat(rad), lon(rad), alt(m)]
        %lla_gt = [ground_truth(i).lat, ground_truth(i).lon, ground_truth(i).alt];

        for k = 1:Ns
            lat = lla_gt(k,1);
            lon = lla_gt(k,2);

            % Matriz de rotación ECEF->ENU en (lat, lon)
            R_ecef2enu = [ ...
                -sin(lon),               cos(lon),                0;
                -sin(lat)*cos(lon),     -sin(lat)*sin(lon),      cos(lat);
                 cos(lat)*cos(lon),      cos(lat)*sin(lon),      sin(lat) ];
            R_enu2ecef = R_ecef2enu.';  % inversa (ortonormal) para pasar de ENU a ECEF el error

            % Ruido en ENU (E,N,U)
            n_enu = [sigma_xy*randn; sigma_xy*randn; sigma_u*randn];

            % Proyectar ruido a ECEF y sumar
            n_ecef = R_enu2ecef * n_enu;
            pos_ecef_noisy(k,:) = pos_ecef_gt(k,:) + n_ecef';

        end

        % Convertimos posición ruidosa a LLA para salida
        lla_noisy = ecef2lla(pos_ecef_noisy);   % [lat(rad), lon(rad), alt(m)]

        % Velocidad
        vel_ecef_noisy = ground_truth(i).vel_ecef + cfg.adsb.sigma_vel*rand(Ns,3);

        % --- Tabla de salida ---
        lat_deg = lla_noisy(:,1);
        lon_deg = lla_noisy(:,2);
        alt_m   = lla_noisy(:,3);

        T = table(rows_time, rows_icao, rows_callsign, ...
                  lat_deg, lon_deg, alt_m, ...
                  vel_ecef_noisy(:,1), vel_ecef_noisy(:,2), vel_ecef_noisy(:,3), ...
            'VariableNames', {'time','icao','callsign','lat','lon','alt','vx','vy','vz'});

        squitters{i} = T;
    end
end