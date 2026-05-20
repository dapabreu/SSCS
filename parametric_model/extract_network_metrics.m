function extract_network_metrics(data_directory)
% Batch processes empirical CSV datasets to calculate 3D matrices for PLR, Mean Jitter, and Mean BER.

    if nargin < 1
        data_directory = './csv_data/';
    end

    pl_base = [4, 25, 125, 225];
    gs_base = [1, 3, 5];
    fr_base = ["nominal", "weak", "light", "moderate", "severe"];
    
    % Initialize the 3D arrays (3 x 4 x 5):
    plr_table = zeros(length(gs_base), length(pl_base), length(fr_base));
    jitter_mu_table = zeros(length(gs_base), length(pl_base), length(fr_base));
    ber_table = zeros(length(gs_base), length(pl_base), length(fr_base));
    ber_std_table = zeros(length(gs_base), length(pl_base), length(fr_base));

    % Loop grid:
    for k = 1:length(fr_base)
        for i = 1:length(gs_base)
            for j = 1:length(pl_base)
                gs = gs_base(i);
                pl = pl_base(j);
                fr = fr_base(k);
                
                filename = fullfile(data_directory, sprintf('%dgs-%dpl-%s_data.csv', gs, pl, fr));
                
                if ~isfile(filename)
                    warning('File not found: %s. Array coordinates left as zeros.', filename);
                    continue;
                end
                
                fprintf('Extracting Metrics for %d GS, %d Planes, %s FR... ', gs, pl, fr);
                
                % Load data:
                data = readtable(filename);
                total_packets = height(data);
                if total_packets == 0
                    fprintf('Empty file!\n');
                    continue;
                end
                
                % Create Received Mask (Supports both numeric mappings and string outputs):
                if isnumeric(data.Status)
                    rx_mask = (data.Status == 0);
                else
                    rx_mask = strcmp(string(data.Status), 'Received') | strcmp(string(data.Status), '0');
                end
                
                % Evaluate Packet Loss Ratio (PLR):
                rx_count = sum(rx_mask);
                plr_table(i, j, k) = (total_packets - rx_count) / total_packets;
                
                % Evaluate Mean Jitter for received packets:
                if any(rx_mask)
                    jitter_mu_table(i, j, k) = mean(data.Jitter_ms(rx_mask), 'omitnan');
                end
                
                % Evaluate Mean BER for received packets:
                if any(rx_mask)
                    ber_table(i, j, k) = mean(data.BER(rx_mask), 'omitnan');
                    ber_std_table(i, j, k) = std(data.BER(rx_mask), 'omitnan');
                end
                
                fprintf('Success! (PLR: %.2f%%)\n', plr_table(i,j,k) * 100);
            end
        end
    end

    % Print arrays in MATLAB syntax:
    print_3d_matrix('plr_table', plr_table);
    print_3d_matrix('jitter_mu_table', jitter_mu_table);
    print_3d_matrix('ber_table', ber_table);
    print_3d_matrix('ber_std_table', ber_std_table);
end

% Helper function to print 3D matrices cleanly:
function print_3d_matrix(name, mat)
    fprintf('%s = zeros(%d, %d, %d);\n', name, size(mat, 1), size(mat, 2), size(mat, 3));
    for k = 1:size(mat, 3)
        fprintf('%s(:,:,%d) = [\n', name, k);
        for r = 1:size(mat, 1)
            fprintf('    ');
            for c = 1:size(mat, 2)
                fprintf('%.6e', mat(r, c, k));
                if c < size(mat, 2)
                    fprintf(', ');
                end
            end
            if r < size(mat, 1)
                fprintf(';\n');
            else
                fprintf('\n];\n');
            end
        end
    end
    fprintf('\n');
end
