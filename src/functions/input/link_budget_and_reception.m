function [SNR_dB, Pr_dBm, isDetected] = link_budget_and_reception(AIR_ecef, SAT_ecef, isVisible, cfg)
%==========================================================================
% SATERA - Link Budget and Reception Evaluation
%==========================================================================
%
%   Calculates received power, SNR and detectability of aircraft ADS-B
%   signals at each satellite across time.
%
%   INPUTS:
%       AIR_ecef   - [N_t x 3] aircraft trajectory in ECEF [m]
%       SAT_ecef   - [3 x N_t x N_sat] satellite positions (ECEF, m)
%       isVisible  - [N_sat x N_t] logical visibility matrix
%       cfg        - struct with fields:
%                       .fADSB_Hz   (ADS-B frequency)
%                       .Ptx_dBm   (transmit power)
%                       .Gtx_dBi    (aircraft antenna gain)
%                       .Grx_dBi    (satellite antenna gain)
%                       .LT_dB    (tx losses)
%                       .NF_dB    (noise figure)
%                       .BW_Hz    (receiver bandwidth)
%                       .sens_dBm (receiver sensitivity)
%
%   OUTPUTS:
%       SNR_dB     - [N_sat x N_t] SNR per satellite and time [dB]
%       Pr_dBm     - [N_sat x N_t] received power [dBm]
%       isDetected - [N_sat x N_t] logical detection mask
%==========================================================================

if ~isfield(cfg, 'fADSB_Hz'),cfg.freqHz   = 1090e6; end
if ~isfield(cfg, 'Ptx_dBm'), cfg.Ptx_dBm  = 10*log10(125) + 30; end
if ~isfield(cfg, 'Gtx_dBi'), cfg.Gtx_dBi  = 3; end
if ~isfield(cfg, 'Grx_dBi'), cfg.Grx_dBi  = 12; end
if ~isfield(cfg, 'LT_dB'),   cfg.LT_dB    = 3; end
if ~isfield(cfg, 'NF_dB'),   cfg.NF_dB    = 2; end
if ~isfield(cfg, 'BW_Hz'),   cfg.BW_Hz    = 8e6; end
if ~isfield(cfg, 'sens_dBm'),cfg.sens_dBm = -97; end


% Constants
c0 = physconst("Lightspeed");
lambda = c0 / cfg.fADSB_Hz;
k = 1.38e-23;
T0 = 290;

% Dimensions
N_t = size(AIR_ecef, 1);
N_sat = size(SAT_ecef, 3);

% Initialize outputs
SNR_dB = nan(N_sat, N_t);
Pr_dBm = nan(N_sat, N_t);
isDetected = false(N_sat, N_t);

% Diagrama isotropico, ganancia fija
% for kt = 1:N_t
%     r_air = AIR_ecef(kt, :);                 % [1x3]
%     r_sat_all = squeeze(SAT_ecef(:, kt, :))'; % [N_sat x 3]
% 
%     % Compute distances for all visible satellites
%     d = vecnorm(r_sat_all - r_air, 2, 2);
% 
%     % Free-space path loss (dB)
%     Lp = 20*log10(4*pi*d/lambda);
% 
%     % Received power (dBm)
%     Pr_tmp = cfg.Ptx_dBm + cfg.Gtx_dBi + cfg.Grx_dBi - Lp - cfg.LT_dB;
% 
%     % Noise power (dBm)
%     N0_dBm = 10*log10(k*T0*cfg.BW_Hz) + cfg.NF_dB + 30;
% 
%     % SNR
%     SNR_tmp = Pr_tmp - N0_dBm;
% 
%     % Mask by visibility
%     visible_idx = isVisible(:, kt);
% 
%     % Store only for visible satellites
%     Pr_dBm(visible_idx, kt) = Pr_tmp(visible_idx);
%     SNR_dB(visible_idx, kt) = SNR_tmp(visible_idx);
%     isDetected(visible_idx, kt) = Pr_tmp(visible_idx) >= cfg.sens_dBm;
% end

% Cargar datos CST y construir la función interpolada
[f_gain_CST] = build_gain_function_from_CST('13a_4x4_pyramid_6_faces.txt');


for kt = 1:N_t

    r_air = AIR_ecef(kt, :);                 
    r_sat_all = squeeze(SAT_ecef(:, kt, :))'; 

    d = vecnorm(r_sat_all - r_air, 2, 2);
    Lp = 20*log10(4*pi*d/lambda);  

    % --- Ganancia realista para cada satélite ---
    Grx_dBi_vec = nan(N_sat,1);

    for ks = 1:N_sat
        if ~isVisible(ks, kt), continue; end

        r_sat = r_sat_all(ks,:);
        los = (r_air - r_sat) / norm(r_air - r_sat);

        % Boresight hacia nadir
        nadir = -r_sat / norm(r_sat);

         % Ángulo respecto a nadir
        theta_nadir = acosd(dot(nadir, los));  % 0° = nadir, 90° = horizonte (dot: vector unitario)

        % Diagrama coseno elevado a n-esima potencia
        % % % Pico a 70° de nadir (20° down-tilt)
        % % theta_offaxis = abs(theta_nadir - 70);
        % % 
        % % % Patrón cos^n
        % % n = 53;
        % % Gmax = 16.2; % dBi
        % % 
        % % if cosd(theta_offaxis) > 0
        % %     Grx_dBi_vec(ks) = Gmax + 10*log10((cosd(theta_offaxis))^n);
        % % else
        % %     Grx_dBi_vec(ks) = -40; % enorme atenuación si pasa del 90°
        % % end

        % Fichero CST
        % Conversión de tus ángulos al sistema CST
        theta_CST = 180 - theta_nadir;   % recordemos: nadir=0° → CST=180°
        
        % Limitar por seguridad
        theta_CST = max(0, min(180, theta_CST));
        
        % Ganancia de la antena desde CST (dBi)
        Grx_dBi_vec(ks) = f_gain_CST(theta_CST);

       
    end

    % Comprobar angulos
    % % % Opciones
    % % R_earth = 6371e3;       % radio aproximado Tierra (m)
    % % marker_sat_size = 80;
    % % marker_air_size = 120;
    % % 
    % % % Selección: satélites con ganancia válida (no NaN)
    % % valid_idx = find(~isnan(Grx_dBi_vec));       % índices
    % % if isempty(valid_idx)
    % %     error('No hay satélites con Grx no-NaN en este instante.');
    % % end
    % % 
    % % % Datos para plot
    % % sat_plot = r_sat_all(valid_idx, :);          % Mx3
    % % g_plot = Grx_dBi_vec(valid_idx);             % Mx1
    % % 
    % % % Crear figura
    % % figure('Units','normalized','Position',[0.1 0.1 0.6 0.7]); hold on;
    % % % Tierra (wire/semiform)
    % % [Xe,Ye,Ze] = sphere(60);
    % % surf(R_earth*Xe, R_earth*Ye, R_earth*Ze, 'FaceAlpha',0.12, 'EdgeColor', [0.6 0.6 0.6], 'LineStyle','none');
    % % 
    % % % Plot satélites coloreados por ganancia
    % % scatter3(sat_plot(:,1), sat_plot(:,2), sat_plot(:,3), marker_sat_size, g_plot, 'filled');
    % % colormap(jet); cb = colorbar; cb.Label.String = 'Grx (dBi)';
    % % 
    % % % Plot avión
    % % scatter3(r_air(1), r_air(2), r_air(3), marker_air_size, 'ks', 'filled');
    % % text(r_air(1), r_air(2), r_air(3), '  Aircraft','FontWeight','bold');
    % % 
    % % % Trazar lineas LOS y etiquetas de ganancia
    % % for ii = 1:size(sat_plot,1)
    % %     s = sat_plot(ii,:);
    % %     plot3([s(1), r_air(1)], [s(2), r_air(2)], [s(3), r_air(3)], '--', 'Color', [0.5 0.5 0.5]);
    % %     % etiqueta junto al satélite con su ganancia
    % %     txt = sprintf('%.2f dBi', g_plot(ii));
    % %     text(s(1), s(2), s(3), ['  ' txt], 'FontSize', 9);
    % % end
    % % 
    % % % Ajustes visuales
    % % axis equal;
    % % xlabel('X (m)'); ylabel('Y (m)'); zlabel('Z (m)');
    % % title(sprintf('Geometry at time step %d — sats with valid Grx (N=%d)', kt, numel(valid_idx)));
    % % view(30,20);
    % % grid on;
    % % hold off;
    % % 
    % % % % % 3D
    % % lla_air= ecef2lla(r_air);
    % % lla_s= ecef2lla(sat_plot); 
    % % uif = uifigure;
    % % g = geoglobe(uif,'NextPlot','add');
    % % geoplot3(g, lla_s(:,1), lla_s(:,2), lla_s(:,3),'LineStyle','none','Marker','o','MarkerSize',1,'Color','yellow','LineWidth',5);
    % % hold(g,'on')
    % % geoplot3(g, lla_air(1), lla_air(2), lla_air(3),'LineStyle','none','Marker','o','MarkerSize',1,'Color','red','LineWidth',5);
    % % hold(g,'off')

    % Potencia recibida usando la ganancia real
    Pr_tmp = cfg.Ptx_dBm + cfg.Gtx_dBi + Grx_dBi_vec - Lp - cfg.LT_dB;

    % Noise power (dBm)
    N0_dBm = 10*log10(k*T0*cfg.BW_Hz) + cfg.NF_dB + 30;

    % SNR
    SNR_tmp = Pr_tmp - N0_dBm;

    % Mask by visibility
    visible_idx = isVisible(:, kt);

    % Store only for visible satellites
    Pr_dBm(visible_idx, kt) = Pr_tmp(visible_idx);
    SNR_dB(visible_idx, kt) = SNR_tmp(visible_idx);
    isDetected(visible_idx, kt) = Pr_tmp(visible_idx) >= cfg.sens_dBm;
end

% figure()
% stairs(sum(isDetected))

end

function f_gain = build_gain_function_from_CST(fname)

    raw = readmatrix(fname,'NumHeaderLines',2);

    theta_raw = raw(:,1);
    phi_raw   = raw(:,2);
    gain_raw  = raw(:,3);   

    % Normalizar a 0..360
    theta360 = theta_raw;
    theta360(theta360<0) = theta360(theta360<0) + 360;

    % Quedarse solo con phi=180
    mask = abs(phi_raw - 180) < 1e-3;
    theta = theta360(mask);
    gain  = gain_raw(mask);

    % Ordenar
    [theta, idx] = sort(theta);
    gain = gain(idx);

    % Solo 0..180
    mask2 = theta <= 180;
    theta = theta(mask2);
    gain  = gain(mask2);

    % Piso por seguridad
    gain_floor = -60;

    % Función interpolada
    f_gain = @(th) interp1(theta, gain, th, 'pchip', gain_floor);
end


