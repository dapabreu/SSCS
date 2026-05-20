%% Load reference trajectories and take only the part of one region

load("ground_truth_resampled.mat")
load("cfg.mat")

figure('Name','Resampled Aircraft Trajectories','NumberTitle','off');
geobasemap streets;    
hold on;
cmap = turbo(numel(ground_truth_resampled));
legend_entries = strings(1,numel(ground_truth_resampled));

for kk = 1:numel(ground_truth_resampled)

    lla_gt = ecef2lla(ground_truth_resampled(kk).pos_ecef,'WGS84');    
    geoplot(lla_gt(:,1), lla_gt(:,2),'.','Color', cmap(kk,:), 'DisplayName', char(ground_truth_resampled(kk).icao));
    hold on
    legend_entries(kk) =  char(ground_truth_resampled(kk).icao);
    
end
legend(legend_entries(legend_entries~=""), 'Location','bestoutside');
title('Reference Aircraft Trajectories');
hold off

% % Flight Information Regions (FIRs):
% === X = longitude, Y = latitude ===
% Shanwick
FIR.Shanwick.X = [-15 -15 -8 -8 -30 -30 -10 -10];
FIR.Shanwick.Y = [54 51 51 45 45 61 61 54.566666666666666];
% Santa Maria
FIR.Santa_Maria.X = [-17.4166666 -20 -25 -25 -37.5 -40 -40 -13 -13 -15 -15 -17.75 -18.333];
FIR.Santa_Maria.Y = [31.65 30 30 24 17 22.3 45 45 43 42 36.5 34.25 33]; % último punto es parte de un arco
% New York
FIR.New_York.X = [-40 -40 -45 -61.5 -60 -60 -67 -67 -60 -53];
FIR.New_York.Y = [45 22.3 18 18 20 39 39 41.8666666 43.6 45];
% Gander
FIR.Gander.X = [-30 -51 -51 -54 -59 -63 -63 -60 -57.75 -55.6666 -50 -43 -39 -30];
FIR.Gander.Y = [45 45 49 53 57 61 64 65 65 63.5 58.5 58.5 63.5 61];
% Reykjavik
FIR.Reykjavik.X = [-39 -30 0 0 -20 -20];
FIR.Reykjavik.Y = [63.5 61 61 73 73 70];
% Small Greenland
FIR.Small_Greenland.X = [-39 -43 -50 -55.66666];
FIR.Small_Greenland.Y = [63.5 58.5 58.5 63.5];
% Big Greenland
FIR.Big_Greenland.X = [-55.6666 -39 -20 -20 0 0 30 30 -60 -60 -75 -76 -63.33333 -57.75];
FIR.Big_Greenland.Y = [63.5 63.5 70 73 73 82 82 89 89 82 78 76 70 65];
% Bodo
FIR.Bodo.X = [0 30 30 28 25 18 15 7 4 0];
FIR.Bodo.Y = [82 82 71 71.33 71.33 70.47 70 65.75 63 63];
% Canarias
FIR.Canarias.X = [-15.75 -12.5 -13.15 -11.23 -14 -16.95 -17 -17.04 -17.05 -17.07 -17.05 -17.06 -19 -20 -25 -25 -20 -17.416 -16.45];
FIR.Canarias.Y = [31.5 30 27.666 27.666 21.33 21.33 21.15 21.05 20.98 20.91 20.8 20.78 19 20 24 30 30 31.65 31.4];
% Sal
FIR.Sal.X = [-25 -20 -20 -21.366 -37.5];
FIR.Sal.Y = [24 20 15 13 17];
% Dakar
FIR.Dakar.X = [-21.366 -7.333 -3 -3 -10 -10 -16 -35 -37.5 -37.5];
FIR.Dakar.Y = [13 0 -1.85 -9.55 -12 -6.366 -6.366 7.666 13.5 17];
% Atlantic
FIR.Atlantic.X  = [-35 -16 -10 -10 -10 -50 -43.75 -38.15 -39.3777 -37.67 -39 -38.05 -37.612 -33.82 -31.8 -32.12 -40.78 -48 -40];
FIR.Atlantic.Y = [7.666 -6.366 -6.366 -12 -34 -34 -26.75 -22.45 -21.19 -18.86 -18.43 -16.73 -15.21 -8.43 -4.05 -3.27 0.93 5 5];
% Recife
FIR.Recife.X = [-39.3777 -37.67 -39 -38.05 -37.612 -33.82 -31.8 -32.12 -40.78 -48 -42.5 -43.15 -43.4 -44.2 -44.8 -45.78 -46.67 -47.69 -46.89 -45.6 -44.58 -44.095 -42.825 -42.678 -41.715 -41.923 -42.52 -42.448 -42.5 -42.48 -42.595 -42.32 -42 -41.05 -40.82 -40.5675 -40.25 -39.679];
FIR.Recife.Y = [-21.19 -18.86 -18.43 -16.73 -15.21 -8.43 -4.05 -3.27 0.93 5 -4.2 -4.5 -4.7 -5.94 -6.3 -8.15 -8.86 -10.3 -12.02 -13.32 -14.785 -15.627 -16.3745 -16.41 -17.013 -17.5866 -18.618 -18.758 -19.08 -19.46 -20.46 -20.55 -20.62 -20.42 -20.695 -20.9 -20.95 -20.88];

% === Mapa base ===
figure('Color','w');
plotFir(FIR.Shanwick.X, FIR.Shanwick.Y, 'Shanwick', "#1f77b4", 1.8);
hold on 
% Basemap (elige el que prefieras):
% 'streets', 'satellite', 'topographic', 'darkwater', 'grayterrain', 'colorterrain', 'landcover', etc.
geobasemap('topographic');
% === Trazar cada FIR ===
plotFir(FIR.Santa_Maria.X, FIR.Santa_Maria.Y, 'Santa Maria',  "#ff7f0e", 1.8);
plotFir(FIR.New_York.X, FIR.New_York.Y, 'New York',     "#2ca02c", 1.8);
plotFir(FIR.Gander.X, FIR.Gander.Y, 'Gander',       "#d62728", 1.8);
plotFir(FIR.Reykjavik.X, FIR.Reykjavik.Y, 'Reykjavik',    "#9467bd", 1.8);
plotFir(FIR.Small_Greenland.X, FIR.Small_Greenland.Y, 'Greenland S',  "#8c564b", 1.8);
plotFir(FIR.Big_Greenland.X, FIR.Big_Greenland.Y, 'Greenland L',  "#e377c2", 1.8);
plotFir(FIR.Bodo.X, FIR.Bodo.Y, 'Bodo',         "#7f7f7f", 1.8);
plotFir(FIR.Canarias.X, FIR.Canarias.Y, 'Canarias',     "#bcbd22", 1.8);
plotFir(FIR.Sal.X, FIR.Sal.Y, 'Sal',          "#17becf", 1.8);
plotFir(FIR.Dakar.X, FIR.Dakar.Y, 'Dakar',        "#1f77b4", 1.8);
plotFir(FIR.Atlantic.X, FIR.Atlantic.Y, 'Atlantic',     "#ff7f0e", 1.8);
plotFir(FIR.Recife.X, FIR.Recife.Y, 'Recife',       "#2ca02c", 1.8);

legend('Location','bestoutside');
title('FIRs');

%% Take the New York FIR and cut the trajectories

% Margen alrededor del FIR de New York:
lat0 = mean(FIR.New_York.Y);
lon0 = mean(FIR.New_York.X);

% Conversión deg → metros (aprox local)
x = (FIR.New_York.X - lon0) .* cosd(lat0) * 111e3;
y = (FIR.New_York.Y - lat0) * 111e3;

% Buffer geométrico real (10 NM)
margin_nm = 10;
margin_m  = margin_nm * 1852;

pg = polyshape(x, y);
pg_buf = polybuffer(pg, margin_m);
margin_nm = 10;
margin_deg = margin_nm / 60;  % 1 deg ≈ 60 NM

[xb, yb] = boundary(pg_buf);

fir_lon_exp = xb / (111e3 * cosd(lat0)) + lon0;
fir_lat_exp = yb / 111e3 + lat0;

% Define the struct
gt_fir = struct('icao',[],'t',[],'pos_ecef',[],'vel_ecef',[],'callsign',[]);


% Representar y guardar la parte de la trayectoria que se selecciona
% === Mapa base ===
figure('Color','w');
geobasemap('topographic')
plotFir(FIR.New_York.X, FIR.New_York.Y, 'New York',"#2ca02c", 1);
hold on
plotFir(fir_lon_exp, fir_lat_exp, '',"#F32BA0", 1); % Representar el area alrededor
colors = turbo(numel(ground_truth_resampled));
id = 1;
for k = 1:numel(ground_truth_resampled)
    
    gt = ground_truth_resampled(k);
    lla = ecef2lla(gt.pos_ecef,'WGS84');

    % puntos dentro de la FIR
    [in, on] = inpolygon(lla(:,2), lla(:,1), fir_lon_exp, fir_lat_exp);
    idx = in | on;

    % si no cruza la FIR, descartamos
    if nnz(idx) < 2
        continue
    end

    % recortamos la trayectoria
    gt_f.icao     = gt.icao(1);
    gt_f.t        = gt.t(idx);
    gt_f.pos_ecef = gt.pos_ecef(idx,:);
    gt_f.vel_ecef = gt.vel_ecef(idx,:);
    gt_f.callsign = gt.callsign(1);

    gt_fir(id) = gt_f; 
    id = id +1;
    
    %geoplot(lla(idx,1), lla(idx,2),'LineWidth',1.8,'Color',colors(k,:), 'DisplayName',char(gt.icao))
    geoplot(lla(idx,1), lla(idx,2),'.','LineWidth',1.8,'Color',colors(k,:))
end
    %legend('Location','bestoutside')
    legend('FIR New York','FIR New York +10 NM')
    title('Ground truth trajectories inside New York FIR (+10 NM)')
    hold off;

function h = plotFir(lon, lat, name, colorHex, width)
    lon = lon(:)'; lat = lat(:)';
    % Cerrar el polígono para que el contorno quede continuo (opcional)
    if lon(1) ~= lon(end) || lat(1) ~= lat(end)
        lon = [lon lon(1)];
        lat = [lat lat(1)];
    end
    h = geoplot(lat, lon, 'Color', colorHex, 'LineWidth', width, ...
                'DisplayName', name);
    
    % === Centroide del polígono ===
    p = polyshape(lon, lat);
    [lon_c, lat_c] = centroid(p);
    
    % === Texto en el centro del FIR ===
    text(lat_c, lon_c, name, ...
        'FontSize', 9, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', ...
        'Color', colorHex);

end

%% Generate noisy squitters and Propagate constellation

% Generate ADS-B squitters based on the smoothed trajectories
squitters = generate_squitters(gt_fir, cfg);

% If we use the ground truth in any FIR we can change the start and stop
% times to decrease the computation time of the constellation propagator

t_min = inf;
t_max = -inf;
for ii=1:numel(squitters)
    t_i= squitters{ii}.time;
    if ~isempty(t_i)
        t_min = min(t_min, min(t_i));
        t_max = max(t_max, max(t_i));
    end     
end

% Convert from posixtime to datetime in UTC
cfg.sim.start_time_utc = datetime(t_min, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
cfg.sim.stop_time_utc  = datetime(t_max, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');



% Propagate satellite constellation between starTime and stopTime
PrecompData = satellite_constellation(cfg);

%%  Calculate the satellite positions and velocities at the specified time, check visibility, SNR, generate measurements and save the data

% ---------------- Parallel pool ----------------
% nCores = feature('numcores');
% % % Recomendación: no usar todos
% nWorkers = max(1, floor(0.6 * nCores));
% p = gcp('nocreate');
% if isempty(p) || p.NumWorkers ~= nWorkers
%     delete(gcp('nocreate'));
%     parpool('local', nWorkers);
% end

InputData_cell = cell(numel(squitters), 1);

for ac = 1:numel(squitters)
    
    % Query time (e.g., message timestamp)    
    t_msg = datetime(squitters{ac}.time, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
    %t_msg = gt_fir(ac).t; % Already in UTC
    
    % Get all satellites at all queries time
    
        % [pos_all, vel_all] = GetSatelliteState(PrecompData, t_msg); %
        % FlightAware data doesn't provide enough time accuracy (only seconds), so we can use the precomputed positions and velocities at those
        % intervals. Groud truth resampled comes at each second    

    t_query_s = seconds(t_msg - PrecompData.t0)+1; % +1 needed
    pos_all = PrecompData.pos_all(:,t_query_s,:);
    vel_all = PrecompData.vel_all(:,t_query_s,:);
    

    % Check visibility per aircraft trajectory
    isVisible = visibility_check(lla2ecef([squitters{ac}.lat squitters{ac}.lon squitters{ac}.alt],'WGS84'), pos_all, cfg.sat.mask_angle_deg);
    visible = find(isVisible);

    % Calculate SNR 
    [SNR_dB, Pr_dBm, isDetected] = link_budget_and_reception(lla2ecef([squitters{ac}.lat squitters{ac}.lon squitters{ac}.alt],'WGS84'), pos_all, isVisible, cfg.link);

    % Generate measurements and table with data
    InputData_cell{ac} = generate_measurements(gt_fir(ac), pos_all, vel_all, isDetected, cfg, squitters{ac});

end

InputData_ComNet = vertcat(InputData_cell{:});

%delete(gcp('nocreate'));

% Sort by time and save
InputData_ComNet = sortrows(InputData_ComNet, 'Unix_Time_ns');
save('InputData_ComNet_NY_17_07_2025.mat','InputData_ComNet'); % For variables larger than 2GB use MAT-file version 7.3 or later --> save('InputData_ComNet_NY_17_07_2025.mat','InputData_ComNet','-v7.3');
disp('Input data to ComNet generated.');