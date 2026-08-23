% plot_sensitivity_c2.m
% WUWNET Paper 2 Sensitivity Analysis for c2
clc; clear; close all;
addpath('../lib');
addpath('../config');

cfg = paper2_config('paper');
% For speed in typical runs, can reduce mc_trials here or rely on 'quick' config.
num_trials = 100; % Reduced for manageable standalone runtime, adjust up to 3000 for final paper.

c2_range = logspace(-3, 1, 10); % e.g., 1e-3 to 10
snr_range = [-10, -5];
doppler_severity = [0.1, 0.5]; % Amplitude of sinusoidal variation

ch_file = cfg.channels{1, 1};
ch_data = load(ch_file);
f_names = fieldnames(ch_data);
h_chan = ch_data.(f_names{1}); h_chan = h_chan(:).';

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
            [sig_bb_tx, ~, preamble, ~, mseq_ref] = generate_paper2_tx_signal(cfg);
            sig_rx = filter(h_chan, 1, sig_bb_tx);
            
            % Apply Doppler
            t = (0:length(sig_rx)-1) / cfg.fs;
            d_amp = doppler_severity(si); % Pair severity with SNR
            d_phase = d_amp * sin(2 * pi * 0.2 * t);
            sig_rx = sig_rx .* exp(1j * d_phase);
            
            % Add noise
            sig_pwr = var(sig_rx);
            noise = sqrt(sig_pwr / (2 * 10^(snr_db/10))) * (randn(size(sig_rx)) + 1j*randn(size(sig_rx)));
            sig_rx_noisy = sig_rx + noise;
            
            try
                [~, track_err, ~, ~] = run_paper2_receiver_variant(sig_rx_noisy, preamble, mseq_ref, cfg, 'E');
                trial_errs(trial) = sqrt(mean(track_err.^2));
            catch
                trial_errs(trial) = nan;
            end
        end
        trial_errs = trial_errs(~isnan(trial_errs));
        res_rmse(si, ci) = mean(trial_errs);
        res_std(si, ci)  = std(trial_errs) / sqrt(length(trial_errs));
        fprintf(' RMSE = %.3f\n', res_rmse(si, ci));
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
ylabel('Tracking RMSE (Chips)', 'FontSize', 12, 'FontWeight', 'bold');
legend(arrayfun(@(s) sprintf('SNR = %d dB', s), snr_range, 'UniformOutput', false), 'Location', 'best');
title('Sensitivity of HVB-AKF Tracking RMSE to c_2', 'FontSize', 13);

% Draw marker for chosen c2 (1/50)
xline(1/50, '--', 'Chosen c_2 = 1/50', 'LabelVerticalAlignment', 'bottom', ...
      'Color', [0.4 0.4 0.4], 'LineWidth', 1.5, 'FontName', font_name);

if ~exist(cfg.results_dir, 'dir'), mkdir(cfg.results_dir); end
exportgraphics(fig, fullfile(cfg.results_dir, 'Fig_Sensitivity_c2.png'), 'Resolution', 300);
fprintf('\nSensitivity plot saved.\n');
