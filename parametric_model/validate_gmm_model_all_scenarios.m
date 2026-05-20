function validate_gmm_model_all_scenarios(data_directory)
% Generates a 3x4 subplot grid per failure rate, comparing synthetic GMM latencies against empirical datasets, outputting similarity metrics (KS-Stat and P99 Error).

    if nargin < 1, data_directory = './csv_data/'; end

    pl_base = [4, 25, 125, 225];
    gs_base = [1, 3, 5];
    frs = ["nominal", "weak", "light", "moderate", "severe"];
    pkts_per_sec_per_plane = 2;

    % From extract_gmm_params.m:
    gmm_mu1 = zeros(3, 4, 5);
    gmm_mu1(:,:,1) = [
        23.4445, 27.4711, 28.5847, 30.6464;
        20.1068, 22.6607, 23.6823, 24.1412;
        22.0072, 22.4080, 22.5642, 20.3168
    ];
    gmm_mu1(:,:,2) = [
        23.8862, 27.4989, 28.5094, 30.6513;
        19.7794, 22.9874, 23.7048, 23.9556;
        21.9227, 22.3713, 22.5642, 20.2951
    ];
    gmm_mu1(:,:,3) = [
        23.7316, 27.5523, 28.9750, 30.5788;
        20.4394, 22.9743, 23.5998, 23.4361;
        21.9300, 22.1486, 22.8717, 20.2734
    ];
    gmm_mu1(:,:,4) = [
        27.7251, 28.0189, 27.7328, 30.2864;
        19.9658, 22.7564, 24.4873, 24.6126;
        21.6617, 22.1605, 22.9066, 20.3607
    ];
    gmm_mu1(:,:,5) = [
        27.1750, 27.5868, 29.3207, 24.8893;
        21.7488, 23.4590, 23.3763, 24.0142;
        22.1292, 22.3268, 22.2036, 18.8018
    ];
    
    gmm_sig1 = zeros(3, 4, 5);
    gmm_sig1(:,:,1) = [
        3.2580, 6.3192, 7.3270, 8.6904;
        4.2035, 5.3043, 5.6902, 6.2880;
        5.6243, 6.1660, 5.9628, 5.7203
    ];
    gmm_sig1(:,:,2) = [
        3.5270, 6.3434, 7.2513, 8.7010;
        4.0570, 5.5857, 5.7189, 6.1445;
        5.4508, 6.1462, 5.9561, 5.7109
    ];
    gmm_sig1(:,:,3) = [
        3.4892, 6.5572, 7.9993, 8.6739;
        4.3886, 5.6086, 5.6928, 5.8631;
        5.5590, 5.8967, 6.2614, 5.6880
    ];
    gmm_sig1(:,:,4) = [
        5.8464, 6.8468, 6.6335, 8.5506;
        4.1761, 5.2938, 6.6319, 6.7855;
        5.3168, 6.0259, 6.3030, 5.8131
    ];
    gmm_sig1(:,:,5) = [
        5.2740, 6.5560, 8.9450, 5.4118;
        5.2531, 6.2810, 5.9343, 6.9074;
        7.0166, 6.2944, 6.5379, 4.4790
    ];
    
    gmm_mu2 = zeros(3, 4, 5);
    gmm_mu2(:,:,1) = [
        29.6967, 69.0274, 90.5752, 84.5464;
        26.7730, 33.3726, 55.3193, 44.7195;
        60.7173, 68.5118, 74.5547, 49.1466
    ];
    gmm_mu2(:,:,2) = [
        30.6360, 73.9804, 87.5127, 84.3915;
        25.5764, 56.2275, 56.3390, 38.4089;
        47.7639, 67.6488, 74.4771, 49.1120
    ];
    gmm_mu2(:,:,3) = [
        30.7762, 84.6286, 102.8869, 84.5483;
        26.2740, 47.8578, 54.8300, 48.8127;
        61.5187, 60.2920, 56.0951, 47.2043
    ];
    gmm_mu2(:,:,4) = [
        101.9318, 64.9428, 55.4303, 84.3891;
        26.1292, 31.6416, 80.4547, 55.2498;
        50.6625, 53.9462, 59.6326, 49.3023
    ];
    gmm_mu2(:,:,5) = [
        51.7164, 70.7558, 59.3715, 36.5481;
        36.9956, 47.6715, 51.5284, 61.5005;
        121.4153, 40.7738, 64.1192, 42.5007
    ];
    
    gmm_sig2 = zeros(3, 4, 5);
    gmm_sig2(:,:,1) = [
        5.5555, 26.4714, 22.9655, 3.9377;
        5.5631, 11.6764, 23.3376, 14.9405;
        31.5034, 31.5863, 29.2516, 16.9039
    ];
    gmm_sig2(:,:,2) = [
        5.4055, 25.4176, 25.3165, 3.9666;
        5.7236, 24.4696, 23.2307, 12.3756;
        21.0456, 32.0969, 29.4556, 16.9120
    ];
    gmm_sig2(:,:,3) = [
        5.5650, 35.3365, 13.0370, 3.9350;
        6.7604, 22.5347, 23.1187, 10.0768;
        29.4667, 29.1986, 24.4859, 16.6828
    ];
    gmm_sig2(:,:,4) = [
        1.4235, 23.7298, 24.8743, 1.1340;
        5.6182, 10.0149, 14.0355, 15.4786;
        18.0527, 23.7974, 24.5518, 16.8277
    ];
    gmm_sig2(:,:,5) = [
        17.0267, 24.9203, 26.1993, 10.7175;
        11.9999, 22.7335, 15.8686, 27.0686;
        15.6815, 14.0984, 26.7628, 15.7603
    ];
    
    gmm_w1 = zeros(3, 4, 5);
    gmm_w1(:,:,1) = [
        0.3775, 0.9903, 0.9622, 0.9848;
        0.7374, 0.9425, 0.9569, 0.9533;
        0.9416, 0.9538, 0.8678, 0.6974
    ];
    gmm_w1(:,:,2) = [
        0.4879, 0.9933, 0.9593, 0.9870;
        0.6496, 0.9947, 0.9591, 0.9293;
        0.9247, 0.9529, 0.8666, 0.6969
    ];
    gmm_w1(:,:,3) = [
        0.4666, 0.9938, 0.9717, 0.9847;
        0.7468, 0.9925, 0.9586, 0.9315;
        0.9465, 0.9455, 0.8356, 0.7071
    ];
    gmm_w1(:,:,4) = [
        0.9966, 0.9748, 0.8908, 0.9918;
        0.6909, 0.8738, 0.9736, 0.9724;
        0.9468, 0.9420, 0.9135, 0.6963
    ];
    gmm_w1(:,:,5) = [
        0.9000, 0.9510, 0.9680, 0.5021;
        0.8450, 0.9177, 0.8808, 0.9690;
        0.9777, 0.9044, 0.9012, 0.5766
    ];

    overall_p99_error = [];
    overall_ks_stat = [];

    % Loop through Failure Rates:
    for k = 1:length(frs)
        fr = frs(k);
        
        % Setup the 3x4 figure for this specific FR:
        figure('Name', sprintf('GMM Validation - %s FR', fr), 'Position', [50, 50, 1600, 900]);
        t = tiledlayout(3, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
        title(t, sprintf('Latency Validation (Synthetic vs Empirical) - %s Failure Rate', fr), 'FontSize', 16, 'FontWeight', 'bold');

        for i = 1:length(gs_base)
            for j = 1:length(pl_base)
                gs = gs_base(i);
                pl = pl_base(j);
                
                % Sim time logic:
                if pl == 25 || pl == 4
                    sim_time_sec = 90 * 60;
                elseif pl == 125
                    sim_time_sec = 30 * 60;
                elseif pl == 225
                    sim_time_sec = 10 * 60;
                else
                    sim_time_sec = 60 * 60;
                end
                
                fprintf('Validating %d GS, %d Planes, %s FR... ', gs, pl, fr);
                
                % Handle filename format:
                filename = fullfile(data_directory, sprintf('%dgs-%dpl-%s_data.csv', gs, pl, fr));
                
                if ~isfile(filename)
                    fprintf('FILE NOT FOUND. Skipping.\n');
                    nexttile; title(sprintf('MISSING DATA: %dGS, %dPl, %s FR', gs, pl, fr));
                    continue;
                end
                
                emp_data = readtable(filename);
                if isnumeric(emp_data.Status)
                    emp_rx_mask = (emp_data.Status == 0);
                else
                    emp_rx_mask = strcmp(string(emp_data.Status), 'Received') | strcmp(string(emp_data.Status), '0');
                end
                emp_rx = emp_data.Latency_ms(emp_rx_mask);
                
                % Fetch parameters from the 3D matrices:
                mu1 = gmm_mu1(i, j, k);
                sig1 = gmm_sig1(i, j, k);
                mu2 = gmm_mu2(i, j, k);
                sig2 = gmm_sig2(i, j, k);
                w1 = gmm_w1(i, j, k);
                
                % Generate packets:
                num_received = min(length(emp_rx), pl * pkts_per_sec_per_plane * sim_time_sec);
                comp_choice = rand(num_received, 1) < w1;
                lat_comp1 = mu1 + sig1 * randn(num_received, 1);
                lat_comp2 = mu2 + sig2 * randn(num_received, 1);
                
                synth_rx = comp_choice .* lat_comp1 + (~comp_choice) .* lat_comp2;
                synth_rx = max(2.0, synth_rx);

                % Safety check for sparse data:
                if length(emp_rx) < 2 || length(synth_rx) < 2
                    fprintf('INSUFFICIENT DATA. Skipping stats.\n');
                    overall_p99_error(end+1) = NaN; 
                    overall_ks_stat(end+1) = NaN; 
                    
                    nexttile;
                    title(sprintf('%d GS, %d Planes', gs, pl), 'FontSize', 11);
                    text(0.5, 0.5, 'Insufficient Received Packets', ...
                        'HorizontalAlignment', 'center', 'FontSize', 10, 'Color', 'r');
                    set(gca, 'XTick', [], 'YTick', []);
                    continue;
                end
                
                % Calculate metrics:
                p99_emp = prctile(emp_rx, 99);
                p99_synth = prctile(synth_rx, 99);
                p99_err = abs(p99_emp - p99_synth);
                overall_p99_error(end+1) = p99_err; 
                
                [~, ~, ks_stat] = kstest2(emp_rx, synth_rx);
                overall_ks_stat(end+1) = ks_stat; 
                fprintf('Done! (P99 error: %.2f ms, KS: %.3f)\n', p99_err, ks_stat);

                % Plot:
                nexttile;
                histogram(emp_rx, 100, 'Normalization', 'pdf', 'FaceColor', 'red', 'FaceAlpha', 1.0, 'EdgeColor', 'none', 'DisplayName', 'Empirical');
                hold on;
                histogram(synth_rx, 100, 'Normalization', 'pdf', 'FaceColor', 'cyan', 'FaceAlpha', 0.5, 'EdgeColor', 'none', 'DisplayName', 'Synthetic GMM');
                title(sprintf('%d GS, %d Planes', gs, pl), 'FontSize', 11);
                xlabel('Latency (ms)');
                ylabel('PDF');
                
                metric_str = sprintf('KS-Stat: %.3f\nP99 error: %.2f ms', ks_stat, p99_err);
                text(0.55, 0.75, metric_str, 'Units', 'normalized', 'FontSize', 9, 'BackgroundColor', 'k', 'EdgeColor', 'w');
                if i == 1 && j == 1, legend('Location', 'northwest'); end
                grid on;
            end
        end
    end

    % Final report:
    fprintf('\n========== Overall Validation Summary ==========\n');
    fprintf('\tMean 99th percentile error: %.2f ms\n', mean(overall_p99_error));
    fprintf('\tMax 99th percentile error:  %.2f ms\n', max(overall_p99_error));
    fprintf('\tAverage KS statistic:       %.4f (Closer to 0 is better)\n', mean(overall_ks_stat));
end