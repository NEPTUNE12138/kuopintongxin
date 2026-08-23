% generate_paper_trm_ablation.m
% Generates the TRM Hybrid CIR extraction ablation figure using genuine data.
clc; clear; close all;
addpath('../lib');
addpath('../config');

cfg = paper2_config('paper');
ch_file = cfg.channels{1, 1}; % First channel
load(ch_file);

f_names = fieldnames();
if exist('h', 'var'), h_chan = h; else, f_names=fieldnames(load(ch_file)); ch_data=load(ch_file); h_chan = ch_data.(f_names{1}); end
h_chan = h_chan(:).';

% 1. Transmitted HFM Preamble
fs = cfg.fs;
T_pre = 0.05;
t_pre = 0:1/fs:T_pre-1/fs;
f0 = cfg.preamble_band(1);
f1 = cfg.preamble_band(2);
K = (f1 - f0) / T_pre;
preamble = exp(1j * 2 * pi * (f0 * t_pre + 0.5 * K * t_pre.^2));

% 2. Channel Filtering
rx_preamble_clean = filter(h_chan, 1, preamble);

% 3. Controlled Noise (e.g. SNR = 0 dB for clear illustration)
snr_db = 0;
sig_pwr = var(rx_preamble_clean);
noise = sqrt(sig_pwr / (2 * 10^(snr_db/10))) * (randn(size(rx_preamble_clean)) + 1j*randn(size(rx_preamble_clean)));
rx_preamble = rx_preamble_clean + noise;

% 4. Matched Filtering
corr_out = xcorr(rx_preamble, preamble);
corr_out = corr_out(length(rx_preamble):end); % causal part
[~, peak_idx] = max(abs(corr_out));

win_start = max(1, peak_idx - 50);
win_end   = min(length(corr_out), peak_idx + 200);
g_win = corr_out(win_start:win_end);

% 5. Hybrid Extraction
[h_ext, gamma_os, gamma_acf, gamma_hybrid, mask, meta] = extract_cir_hybrid(g_win, preamble, cfg);

% 6. Equivalent CIR after TRM
q_filter = conj(fliplr(h_ext));
equiv_cir = conv(h_ext, q_filter);

%% Plotting
fig = figure('Position', [100, 100, 800, 600], 'Color', 'w');
t_axis = (0:length(g_win)-1) / fs * 1000; % ms

subplot(3, 1, 1);
plot(t_axis, abs(g_win), 'k', 'LineWidth', 1.2); hold on;
plot(t_axis, gamma_os, 'b--', 'LineWidth', 1.5);
plot(t_axis, gamma_hybrid, 'r-.', 'LineWidth', 1.5);
title('Candidate CIR & Extraction Thresholds');
ylabel('Magnitude');
legend('Raw Matched Filter Output', 'OS-CFAR Threshold', 'Hybrid Threshold', 'Location', 'northeast');
grid on;

subplot(3, 1, 2);
h_os = g_win; h_os(abs(g_win) < gamma_os) = 0;
stem(t_axis, abs(h_os), 'b', 'LineWidth', 1.2, 'Marker', 'none'); hold on;
stem(t_axis, abs(h_ext), 'r', 'LineWidth', 1.2, 'Marker', 'none');
title('Extracted Paths');
ylabel('Magnitude');
legend('Paths (Pure OS-CFAR)', 'Paths (Hybrid Threshold)', 'Location', 'northeast');
grid on;

subplot(3, 1, 3);
t_equiv = ((1:length(equiv_cir)) - length(h_ext)) / fs * 1000;
plot(t_equiv, abs(equiv_cir), 'r', 'LineWidth', 1.5);
title('Equivalent Channel Impulse Response (After Hybrid TRM)');
xlabel('Delay Time (ms)'); ylabel('Magnitude');
grid on;

if ~exist(cfg.results_dir, 'dir'), mkdir(cfg.results_dir); end
exportgraphics(fig, fullfile(cfg.results_dir, 'Fig_TRM_Ablation.png'), 'Resolution', 300);
fprintf('TRM Ablation plot saved to %s\n', cfg.results_dir);
