function plot_sensitivity_c2(mode)
% PLOT_SENSITIVITY_C2 Factorial design sensitivity for c2
    
    if nargin < 1, mode = 'quick'; end
    
    this_file = mfilename('fullpath');
    src_dir = fileparts(this_file);
    project_root = fileparts(src_dir);
    addpath(fullfile(project_root, 'lib'));
    addpath(fullfile(project_root, 'config'));
    
    cfg = paper2_config(mode);
    num_trials = cfg.mc_trials_sens;
    
    snr_set = [0, 15];
    velocity_amp_set = [0.5, 1.5];
    c2_grid = unique(sort([logspace(-3, 1, 10), cfg.c2]));
    
    ch_file = cfg.channels{1, 1};
    [h_chan, ~] = load_bellhop_cir(ch_file, cfg.fs);
    
    fprintf('\n--- Running c2 Factorial Sensitivity Analysis (%s) ---\n', upper(mode));
    
    out_dir = fullfile(project_root, 'results', 'diagnostic');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    csv_file = fullfile(out_dir, sprintf('c2_factorial_sensitivity_%s_%s.csv', mode, timestamp));
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'SNR_dB,VelocityAmp_mps,c2,ValidTrials,MeanRMSE,MedianRMSE,StdError\n');
    
    results = struct();
    
    for si = 1:length(snr_set)
        snr_db = snr_set(si);
        for vi = 1:length(velocity_amp_set)
            v_amp = velocity_amp_set(vi);
            
            fprintf('\nCondition: SNR = %d dB, VelAmp = %.1f m/s\n', snr_db, v_amp);
            cond_key = sprintf('S%d_V%d', snr_db, round(v_amp*10));
            
            for ci = 1:length(c2_grid)
                c2 = c2_grid(ci);
                fprintf('  c2 = %.4f ', c2);
                
                cfg_local = cfg;
                cfg_local.c2 = c2;
                trial_errs = NaN(1, num_trials);
                
                for trial = 1:num_trials
                    if mod(trial, 20) == 0, fprintf('.'); end
                    
                    rng_seed = cfg_local.master_seed + trial + si*1000 + vi*10000 + ci*100000;
                    rng(rng_seed, 'twister');
                    
                    [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg_local);
                    rx_clean = filter(h_chan, 1, tx_pb);
                    
                    warp_cfg.v0_mps = 0.5;
                    warp_cfg.velocity_amp_mps = v_amp;
                    warp_cfg.velocity_freq_hz = 0.2;
                    warp_cfg.phase_rad = 0;
                    
                    [rx_warp, warp_meta] = apply_paper2_time_warp(rx_clean, cfg_local, warp_cfg);
                    
                    sig_pwr = norm(rx_warp)^2 / length(rx_warp);
                    noise_pwr = sig_pwr / (10^(snr_db/10));
                    noise = sqrt(noise_pwr/2) * (randn(size(rx_warp)) + 1j*randn(size(rx_warp)));
                    rx_noisy = rx_warp + noise;
                    
                    try
                        [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_noisy, preamble, cfg_local);
                        sync_meta.peak_idx = peak_idx;
                        sync_meta.preamble_start = p_start;
                        sync_meta.payload_start = pay_start;
                        sync_meta.mf = mf;
                        
                        [~, ~, meta] = run_paper2_receiver_variant(rx_noisy, preamble, mseq_os, sync_meta, cfg_local, 'E');
                        
                        if strcmp(meta.status, 'SUCCESS')
                            eps_est_rel = meta.delay_est_samples - meta.delay_est_samples(1);
                            
                            sym_centers = pay_start + (0:cfg_local.num_diff_symbols-1) * cfg_local.symbol_samples + round(cfg_local.symbol_samples/2);
                            sym_centers = min(length(warp_meta.epsilon_true_samples), max(1, sym_centers));
                            eps_true_per_symbol = warp_meta.epsilon_true_samples(sym_centers);
                            eps_true_rel = eps_true_per_symbol - eps_true_per_symbol(1);
                            
                            err = eps_est_rel - eps_true_rel;
                            trial_errs(trial) = sqrt(mean(err.^2));
                        end
                    catch ME
                        if ~strcmp(ME.identifier, 'Paper2:SyncFail')
                            rethrow(ME);
                        end
                    end
                end
                valid_errs = trial_errs(~isnan(trial_errs));
                valid_trials = length(valid_errs);
                m_rmse = mean(valid_errs);
                med_rmse = median(valid_errs);
                std_err = std(valid_errs) / sqrt(max(1, valid_trials));
                
                fprintf(' RMSE = %.3f\n', m_rmse);
                fprintf(fid, '%d,%.1f,%.6f,%d,%.6f,%.6f,%.6f\n', ...
                    snr_db, v_amp, c2, valid_trials, m_rmse, med_rmse, std_err);
                
                results.(cond_key).c2(ci) = c2;
                results.(cond_key).rmse(ci) = med_rmse;
            end
        end
    end
    fclose(fid);
    
    fprintf('\n=== C2 Factorial Summary ===\n');
    cur_c2 = cfg.c2;
    for si = 1:length(snr_set)
        for vi = 1:length(velocity_amp_set)
            cond_key = sprintf('S%d_V%d', snr_set(si), round(velocity_amp_set(vi)*10));
            rmses = results.(cond_key).rmse;
            
            [~, best_idx] = min(rmses);
            best_c2 = c2_grid(best_idx);
            
            % rank of current c2
            cur_idx = find(abs(c2_grid - cur_c2) < 1e-9, 1);
            
            % rank among all
            [~, sort_idx] = sort(rmses);
            rank = find(sort_idx == cur_idx);
            
            fprintf('SNR %d dB, Vel %.1f m/s:\n', snr_set(si), velocity_amp_set(vi));
            fprintf('  Best c2: %.4f\n', best_c2);
            fprintf('  Current c2 (%.4f) Rank: %d / %d\n', cur_c2, rank, length(c2_grid));
        end
    end
    fprintf('\nCSV saved to %s\n', out_dir);
end
