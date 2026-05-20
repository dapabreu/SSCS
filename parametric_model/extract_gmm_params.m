function extract_gmm_params(data_directory)
% Batch processes empirical CSV datasets to calculate 3D GMM arrays.
% Includes fallbacks for highly-lossy scenarios where GMM cannot converge.

    if nargin < 1
        data_directory = './csv_data/';
    end

    pl_base = [4, 25, 125, 225];
    gs_base = [1, 3, 5];
    fr_base = ["nominal", "weak", "light", "moderate", "severe"];
    
    % Initialize the 3D arrays (3 x 4 x 5):
    gmm_mu1_matrix = zeros(length(gs_base), length(pl_base), length(fr_base));
    gmm_sig1_matrix = zeros(length(gs_base), length(pl_base), length(fr_base));
    gmm_mu2_matrix = zeros(length(gs_base), length(pl_base), length(fr_base));
    gmm_sig2_matrix = zeros(length(gs_base), length(pl_base), length(fr_base));
    gmm_p1_matrix = zeros(length(gs_base), length(pl_base), length(fr_base));

    for k = 1:length(fr_base)
        for i = 1:length(gs_base)
            for j = 1:length(pl_base)
                gs = gs_base(i);
                pl = pl_base(j);
                fr = fr_base(k);
                
                filename = fullfile(data_directory, sprintf('%dgs-%dpl-%s_data.csv', gs, pl, fr));
                if ~isfile(filename)
                    warning('File not found: %s. Leaving zeros.', filename);
                    continue;
                end
                
                fprintf('Processing %d GS, %d Planes, %s FR...', gs, pl, fr);
                
                % Load and filter data:
                data = readtable(filename);
                if isnumeric(data.Status)
                    rx_mask = (data.Status == 0);
                else
                    rx_mask = strcmp(string(data.Status), 'Received') | strcmp(string(data.Status), '0');
                end
                latencies = data.Latency_ms(rx_mask);
                
                % Fallback for insufficient data:
                if length(latencies) < 5
                    fprintf(' INSUFFICIENT DATA (%d pkts). Using fallback mean.\n', length(latencies));
                    fallback_mu = mean(latencies, 'omitnan');
                    if isnan(fallback_mu), fallback_mu = 25.0; end
                    fallback_sig = std(latencies, 'omitnan');
                    if isnan(fallback_sig) || fallback_sig == 0, fallback_sig = 1.0; end
                    
                    gmm_mu1_matrix(i, j, k) = fallback_mu;
                    gmm_mu2_matrix(i, j, k) = fallback_mu;
                    gmm_sig1_matrix(i, j, k) = fallback_sig;
                    gmm_sig2_matrix(i, j, k) = fallback_sig;
                    gmm_p1_matrix(i, j, k) = 1.0;
                    continue;
                end
                
                % Fit the 2-component GMM:
                options = statset('MaxIter', 1000, 'TolFun', 1e-5);
                try
                    gmm_fit = fitgmdist(latencies, 2, 'Options', options, 'Replicates', 3, 'RegularizationValue', 0.001);
                    [sorted_mus, sort_idx] = sort(gmm_fit.mu);
                    sigmas = sqrt(squeeze(gmm_fit.Sigma));
                    weights = gmm_fit.ComponentProportion;
                    
                    gmm_mu1_matrix(i, j, k) = sorted_mus(1);
                    gmm_mu2_matrix(i, j, k) = sorted_mus(2);
                    gmm_sig1_matrix(i, j, k) = sigmas(sort_idx(1));
                    gmm_sig2_matrix(i, j, k) = sigmas(sort_idx(2));
                    gmm_p1_matrix(i, j, k) = weights(sort_idx(1));
                    fprintf(' Success!\n');
                    
                catch ME
                    % Ultimate failsafe if it still crashes:
                    fprintf(' FAILED TO CONVERGE (%s). Using fallback mean.\n', ME.message);
                    fallback_mu = mean(latencies, 'omitnan');
                    fallback_sig = std(latencies, 'omitnan');
                    if isnan(fallback_sig) || fallback_sig == 0, fallback_sig = 1.0; end
                    
                    gmm_mu1_matrix(i, j, k) = fallback_mu;
                    gmm_mu2_matrix(i, j, k) = fallback_mu;
                    gmm_sig1_matrix(i, j, k) = fallback_sig;
                    gmm_sig2_matrix(i, j, k) = fallback_sig;
                    gmm_p1_matrix(i, j, k) = 1.0;
                end
            end
        end
    end

    % Print output:
    print_3d_matrix('gmm_mu1', gmm_mu1_matrix);
    print_3d_matrix('gmm_sig1', gmm_sig1_matrix);
    print_3d_matrix('gmm_mu2', gmm_mu2_matrix);
    print_3d_matrix('gmm_sig2', gmm_sig2_matrix);
    print_3d_matrix('gmm_w1', gmm_p1_matrix);

end

function print_3d_matrix(name, mat)
    fprintf('%s = zeros(%d, %d, %d);\n', name, size(mat, 1), size(mat, 2), size(mat, 3));
    for k = 1:size(mat, 3)
        fprintf('%s(:,:,%d) = [\n', name, k);
        for r = 1:size(mat, 1)
            fprintf('    ');
            for c = 1:size(mat, 2)
                fprintf('%.4f', mat(r, c, k));
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