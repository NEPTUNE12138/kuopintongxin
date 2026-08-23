function plot_sensitivity_c2(mode)
% WUWNET Paper 2 Sensitivity Analysis for c2
    if nargin < 1
        mode = 'quick';
    end

    clc; close all;
    addpath('../lib');
    addpath('../config');

    cfg = paper2_config(mode);
    num_trials = cfg.mc_trials_sens;

    c2_range = logspace(-3, 1, 10); % e.g., 1e-3 to 10
    snr_range = [0, 15];
    doppler_severity = [0.1, 0.5]; 

    ch_file = cfg.channels{1, 1};
    [h_chan, ~] = load_bellhop_cir(ch_file, cfg.fs);

    res_rmse = zeros(length(snr_range), length(c2_range));
    res_std = zeros(length(snr_range), length(c2_range));

    fprintf('\n--- Running c2 Sensitivity Analysis (%s) ---\n', upper(mode));
    
    out_dir = 'results_plots';
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    csv_file = fullfile(out_dir, sprintf('paper2_c2_sensitivity_%s_%s.csv', mode, timestamp));
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'SNR_dB,c2,Mean_RMSE,Std_RMSE\n');

    for si = 1:length(snr_range)
        snr_db = snr_range(si);
        fprintf('SNR = %d dB\n', snr_db);
        for ci = 1:length(c2_range)
            c2 = c2_range(ci);
            fprintf('  c2 = %.4f ', c2);
            
            cfg.c2 = c2;
            trial_errs = NaN(1, num_trials);
            
            for trial = 1:num_trials
                if mod(trial, 20) == 0, fprintf('.'); end
                
                % Deterministic seed
                rng_seed = cfg.master_seed + trial + si*10000 + ci*100000;
                rng(rng_seed, 'twister');
                
                [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
                rx_clean = filter(h_chan, 1, tx_pb);
                
                % Apply Doppler Phase (Simplified warp for fast testing)
                t = (0:length(rx_clean)-1) / cfg.fs;
                d_amp = doppler_severity(si); 
                
                % We need exact epsilon_true_samples.
                % v(t) = d_amp * cos(2pi*0.2*t)*2pi*0.2 / 1500 ?
                % For simplicity, just use the warp function directly.
                % delay(t) = (t - t_src) * fs
                % t_src = t + d_amp * sin(2*pi*0.2*t)/1500;
                t_src = t + d_amp * sin(2*pi*0.2*t)/1500;
                rx_clean = interp1(t, rx_clean, t_src, 'linear', 0);
                epsilon_true_samples = (t - t_src) * cfg.fs;
                
                % Add noise
                sig_pwr = norm(rx_clean)^2 / length(rx_clean);
                noise_power = sig_pwr / (10^(snr_db/10));
                noise = sqrt(noise_power / 2) * (randn(size(rx_clean)) + 1j*randn(size(rx_clean)));
                rx_noisy = rx_clean + noise;
                
                try
                    [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_noisy, preamble, cfg);
                    sync_meta.peak_idx = peak_idx;
                    sync_meta.preamble_start = p_start;
                    sync_meta.payload_start = pay_start;
                    sync_meta.mf = mf;
                    
                    [~, ~, meta] = run_paper2_receiver_variant(rx_noisy, preamble, mseq_os, sync_meta, cfg, 'E');
                    if strcmp(meta.status, 'SUCCESS')
                        eps_est_rel = meta.delay_est_samples - meta.delay_est_samples(1);
                        
                        sym_centers = pay_start + (0:cfg.num_diff_symbols-1) * cfg.symbol_samples + round(cfg.symbol_samples/2);
                        sym_centers = min(length(epsilon_true_samples), max(1, sym_centers));
                        eps_true_per_symbol = epsilon_true_samples(sym_centers);
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
            res_rmse(si, ci) = mean(valid_errs);
            res_std(si, ci)  = std(valid_errs) / sqrt(max(1, length(valid_errs)));
            fprintf(' RMSE = %.3f\n', res_rmse(si, ci));
            
            fprintf(fid, '%d,%.6f,%.6f,%.6f\n', snr_db, c2, res_rmse(si, ci), res_std(si, ci));
        end
    end
    fclose(fid);

    % Plotting
    fig = figure('Position', [200, 200, 600, 450], 'Color', 'w');
    font_name = 'Times New Roman';
    colors = {'b', 'r'};

    for si = 1:length(snr_range)
        errorbar(c2_range, res_rmse(si, :), res_std(si, :), ...
            [colors{si} '-s'], 'LineWidth', 1.5, 'MarkerFaceColor', 'w'); hold on;
    end
    set(gca, 'XScale', 'log');
    grid on; set(gca, 'GridAlpha', 0.3, 'FontName', font_name);
    xlabel('Hyperparameter c_2', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('Tracking RMSE (Samples)', 'FontSize', 12, 'FontWeight', 'bold');
    legend(arrayfun(@(s) sprintf('SNR = %d dB', s), snr_range, 'UniformOutput', false), 'Location', 'best');
    title('Sensitivity of HVB-AKF Tracking to c_2', 'FontSize', 13);

    % Draw marker for chosen c2
    c2_chosen = paper2_config('quick').c2;
    xline(c2_chosen, '--', sprintf('Chosen c_2 = 1/%.0f', 1/c2_chosen), 'LabelVerticalAlignment', 'bottom', ...
          'Color', [0.4 0.4 0.4], 'LineWidth', 1.5, 'FontName', font_name);

    exportgraphics(fig, fullfile(out_dir, 'Fig_Sensitivity_c2.png'), 'Resolution', 300);
    fprintf('\nSensitivity plot and CSV saved to %s.\n', out_dir);
end
