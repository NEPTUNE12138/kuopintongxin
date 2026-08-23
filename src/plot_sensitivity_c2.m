% plot_sensitivity_c2.m
% WUWNET Paper 2 Sensitivity Analysis for c2
addpath('../lib');
addpath('../config');

cfg = paper2_config('paper');
num_trials = 10; % Kept small for testing, can be bumped to mc_trials

c2_range = logspace(-3, 1, 10); % e.g., 1e-3 to 10
snr_range = [0, 15];
doppler_severity = [0.1, 0.5]; 

ch_file = cfg.channels{1, 1};
[h_chan, ~] = load_bellhop_cir(ch_file, cfg.fs);

res_rmse = zeros(length(snr_range), length(c2_range));
res_std = zeros(length(snr_range), length(c2_range));

fprintf('\n--- Running c2 Sensitivity Analysis ---\n');
for si = 1:length(snr_range)
    snr_db = snr_range(si);
    fprintf('SNR = %d dB\n', snr_db);
    for ci = 1:length(c2_range)
        c2 = c2_range(ci);
        fprintf('  c2 = %.4f ', c2);
        
        cfg.c2 = c2;
        trial_errs = zeros(1, num_trials);
        
        for trial = 1:num_trials
            if mod(trial, 20) == 0, fprintf('.'); end
            
            [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
            rx_clean = filter(h_chan, 1, tx_pb);
            
            % Apply Doppler Phase (Simplified warp for fast testing)
            t = (0:length(rx_clean)-1) / cfg.fs;
            d_amp = doppler_severity(si); 
            rx_clean = interp1(t, rx_clean, t + d_amp * sin(2*pi*0.2*t)/1500, 'linear', 0);
            
            % Add noise
            sig_pwr = norm(rx_clean)^2 / length(rx_clean);
            noise = sqrt(sig_pwr / (2 * 10^(snr_db/10))) * (randn(size(rx_clean)) + 1j*randn(size(rx_clean)));
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
                    % We just approximate ground truth for this plot to see variation
                    % (exact true eps would require more boilerplate, this is just sensitivity)
                    % Let's use simple standard deviation as proxy for tracking jitter
                    trial_errs(trial) = std(diff(eps_est_rel));
                else
                    trial_errs(trial) = nan;
                end
            catch
                trial_errs(trial) = nan;
            end
        end
        trial_errs = trial_errs(~isnan(trial_errs));
        res_rmse(si, ci) = mean(trial_errs);
        res_std(si, ci)  = std(trial_errs) / sqrt(length(trial_errs));
        fprintf(' RMSE (jitter) = %.3f\n', res_rmse(si, ci));
    end
end

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
ylabel('Tracking Jitter (Samples)', 'FontSize', 12, 'FontWeight', 'bold');
legend(arrayfun(@(s) sprintf('SNR = %d dB', s), snr_range, 'UniformOutput', false), 'Location', 'best');
title('Sensitivity of HVB-AKF Tracking to c_2', 'FontSize', 13);

% Draw marker for chosen c2
c2_chosen = paper2_config('quick').c2;
xline(c2_chosen, '--', sprintf('Chosen c_2 = 1/%.0f', 1/c2_chosen), 'LabelVerticalAlignment', 'bottom', ...
      'Color', [0.4 0.4 0.4], 'LineWidth', 1.5, 'FontName', font_name);

if ~exist('results_plots', 'dir'), mkdir('results_plots'); end
exportgraphics(fig, fullfile('results_plots', 'Fig_Sensitivity_c2.png'), 'Resolution', 300);
fprintf('\nSensitivity plot saved.\n');
