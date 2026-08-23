function generate_paper_trm_ablation(mode)
    if nargin < 1, mode = 'quick'; end
    
    this_file = mfilename('fullpath');
    src_dir = fileparts(this_file);
    project_root = fileparts(src_dir);
    addpath(fullfile(project_root, 'lib'));
    addpath(fullfile(project_root, 'config'));
    
    cfg = paper2_config(mode);
    ch_file = cfg.channels{1, 1}; % First channel
    [h_chan, ~] = select_bellhop_local_cluster(ch_file, cfg);

% 1. Transmitted HFM Preamble
preamble = generate_hfm_preamble(cfg);

% 2. Channel Filtering
rx_preamble_clean = conv(preamble, h_chan, 'full');

% 3. Controlled Noise (e.g. SNR = 0 dB for clear illustration)
snr_db = 0;
sig_pwr = norm(rx_preamble_clean)^2 / length(rx_preamble_clean);
noise = sqrt(sig_pwr / (2 * 10^(snr_db/10))) * (randn(size(rx_preamble_clean)) + 1j*randn(size(rx_preamble_clean)));
rx_preamble = rx_preamble_clean + noise;

% 4. Matched Filtering
[peak_idx, ~, ~, mf, ~] = coarse_sync_from_preamble(rx_preamble, preamble, cfg);

[g_win, win_start, win_end] = extract_mf_local_window(mf, peak_idx, 50, 200);

% 5. Hybrid Extraction
[h_ext, gamma_os, gamma_acf, gamma_hybrid, mask, meta] = extract_cir_hybrid(g_win, preamble, cfg);

% 6. Equivalent CIR after TRM
[q_filter, ~] = build_tr_filter(h_ext);
equiv_cir = filter(q_filter, 1, h_ext);

%% Plotting
fig = figure('Position', [100, 100, 800, 600], 'Color', 'w');
fs = cfg.fs;
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

if ~exist('results_plots', 'dir'), mkdir('results_plots'); end
exportgraphics(fig, fullfile('results_plots', 'Fig_TRM_Ablation.png'), 'Resolution', 300);
fprintf('TRM Ablation plot saved to results_plots\n');
end
