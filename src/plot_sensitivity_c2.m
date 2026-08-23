function plot_sensitivity_c2(mode)
% PLOT_SENSITIVITY_C2 Minimax robust C2 selection using factorial design.

    if nargin < 1, mode = 'quick'; end
    
    this_file = mfilename('fullpath');
    src_dir = fileparts(this_file);
    project_root = fileparts(src_dir);
    addpath(fullfile(project_root, 'lib'));
    addpath(fullfile(project_root, 'config'));
    
    cfg = paper2_config(mode);
    if strcmp(mode, 'quick')
        num_mc = 5;
    else
        num_mc = 20; % Use 20 MC for selection
    end
    
    % We will test the E-CAL candidate because the assumption is it passed the gate.
    % If it didn't pass the gate, this script will still run on E-CAL but the pipeline will be stopped anyway.
    variant = 'E-CAL';
    
    % Broad grid for c2
    c2_grid = unique(sort([0.005 0.01 0.02 0.05 0.1 0.2 0.5 1 2 5]));
    
    snr_db_list = [0, 15];
    vel_amp_list = [0.5, 1.5]; % m/s
    
    ch_file = cfg.channels{1, 1}; % Profile 1
    [h_chan, ~] = select_bellhop_local_cluster(ch_file, cfg);
    
    out_dir = fullfile(project_root, 'results', 'diagnostic');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    csv_file = fullfile(out_dir, sprintf('c2_factorial_sensitivity_%s_%s.csv', mode, datestr(now, 'yyyymmdd_HHMMSS')));
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'SNR_dB,VelAmp_mps,C2,RMSE_Median\n');
    
    fprintf('\n--- Running c2 Factorial Sensitivity Analysis (%s) ---\n', upper(mode));
    
    rmse_matrix = zeros(length(snr_db_list) * length(vel_amp_list), length(c2_grid));
    cond_idx = 1;
    
    for s_idx = 1:length(snr_db_list)
        snr_db = snr_db_list(s_idx);
        for v_idx = 1:length(vel_amp_list)
            vel_amp = vel_amp_list(v_idx);
            
            fprintf('\nCondition: SNR = %d dB, VelAmp = %.1f m/s\n', snr_db, vel_amp);
            
            warp_cfg.v0_mps = 0.5;
            warp_cfg.velocity_amp_mps = vel_amp;
            warp_cfg.velocity_freq_hz = 0.2;
            warp_cfg.phase_rad = 0;
            
            for c_idx = 1:length(c2_grid)
                c2_val = c2_grid(c_idx);
                
                cfg_test = cfg;
                cfg_test.c2 = c2_val;
                
                err_mc = NaN(1, num_mc);
                
                for mc = 1:num_mc
                    rng_seed = cfg.master_seed + 2000000 + s_idx*1000 + v_idx*100 + c_idx*10 + mc;
                    rng(rng_seed, 'twister');
                    
                    [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg_test);
                    
                    % Full convolution
                    rx_clean = conv(tx_pb, h_chan, 'full');
                    
                    [rx_warp, warp_meta] = apply_paper2_time_warp(rx_clean, cfg_test, warp_cfg);
                    
                    rx_power = norm(rx_warp)^2 / length(rx_warp);
                    noise_power = rx_power / (10^(snr_db / 10));
                    noise = sqrt(noise_power/2) * (randn(size(rx_warp)) + 1j * randn(size(rx_warp)));
                    rx_final = rx_warp + noise;
                    
                    try
                        [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_final, preamble, cfg_test);
                        sync_meta.peak_idx = peak_idx;
                        sync_meta.preamble_start = p_start;
                        sync_meta.payload_start = pay_start;
                        sync_meta.mf = mf;
                        
                        sym_centers = pay_start + (0:cfg_test.num_diff_symbols-1) * cfg_test.symbol_samples + round(cfg_test.symbol_samples/2);
                        sym_centers = min(length(rx_warp), max(1, sym_centers));
                        eps_true_per_symbol = warp_meta.epsilon_true_samples(sym_centers);
                        eps_true_rel = eps_true_per_symbol - eps_true_per_symbol(1);
                        
                        [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_final, preamble, mseq_os, sync_meta, cfg_test, variant);
                        
                        if strcmp(meta.status, 'SUCCESS')
                            eps_est_rel = meta.delay_est_samples - meta.delay_est_samples(1);
                            err = eps_est_rel - eps_true_rel;
                            err_mc(mc) = sqrt(mean(err.^2));
                        end
                    catch ME
                        if ~strcmp(ME.identifier, 'Paper2:SyncFail')
                            rethrow(ME);
                        end
                    end
                end
                
                med_rmse = median(err_mc, 'omitnan');
                rmse_matrix(cond_idx, c_idx) = med_rmse;
                
                fprintf('  c2 = %.4f -> RMSE = %.3f\n', c2_val, med_rmse);
                fprintf(fid, '%d,%.1f,%.4f,%.6f\n', snr_db, vel_amp, c2_val, med_rmse);
            end
            cond_idx = cond_idx + 1;
        end
    end
    fclose(fid);
    
    fprintf('\n=== C2 Minimax Robust Selection ===\n');
    % Calculate normalized loss for each condition
    L_matrix = zeros(size(rmse_matrix));
    for j = 1:size(rmse_matrix, 1)
        min_rmse_j = min(rmse_matrix(j, :));
        if min_rmse_j > 0
            L_matrix(j, :) = rmse_matrix(j, :) / min_rmse_j;
        else
            L_matrix(j, :) = ones(1, size(rmse_matrix, 2));
        end
    end
    
    % J(c2) = max_j L_j(c2)
    J_c2 = max(L_matrix, [], 1);
    
    [min_J, best_idx] = min(J_c2);
    best_c2 = c2_grid(best_idx);
    
    fprintf('Minimax worst-case normalized loss J(c2):\n');
    for c_idx = 1:length(c2_grid)
        fprintf('  c2 = %.4f : J = %.3f\n', c2_grid(c_idx), J_c2(c_idx));
    end
    
    fprintf('\nOptimum minimax c2 = %.4f (J = %.3f)\n', best_c2, min_J);
    
    % Check if 1/50 (0.02) is within 10% of the optimum
    c2_50_idx = find(abs(c2_grid - 0.02) < 1e-6, 1);
    if isempty(c2_50_idx)
        error('c2=0.02 not found in grid.');
    end
    J_50 = J_c2(c2_50_idx);
    
    if J_50 <= 1.10 * min_J
        final_c2 = 0.02;
        fprintf('c2 = 1/50 (0.02) has J = %.3f, which is within 10%% of optimum %.3f.\n', J_50, min_J);
        fprintf('RETAINING c2 = 1/50 for simplicity.\n');
    else
        final_c2 = best_c2;
        fprintf('c2 = 1/50 (0.02) has J = %.3f, > 10%% worse than optimum %.3f.\n', J_50, min_J);
        fprintf('OVERRIDING to minimax optimum c2 = %.4f.\n', final_c2);
    end
    
    fprintf('Final C2 frozen before Pilot: %.4f\n', final_c2);
    fprintf('CSV saved to %s\n', out_dir);
    
    % Update config file directly to freeze the chosen c2 and E-CAL mode for subsequent tests
    % Wait, updating a MATLAB file from within MATLAB is tricky and might not take effect immediately due to caching.
    % It's safer to rely on the agent to edit `paper2_config.m` statically if needed, or just let this be an analytical step.
    % We will save the decision to a .mat file so the full pipeline can use it or verify it.
    save(fullfile(out_dir, 'c2_minimax_decision.mat'), 'c2_grid', 'rmse_matrix', 'J_c2', 'best_c2', 'final_c2');
end
