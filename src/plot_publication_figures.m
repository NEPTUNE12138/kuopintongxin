% =========================================================================
% 出版级绘图脚本 (Publication-Quality Figure Generation)
% 此脚本用于极速生成 WUWNET 会议所需的 4 张核心精修图片。
% 采用浅海平坦地形 (channel_15m_20km_34m.mat) 作为展示信道。
% =========================================================================

clc; clear; close all;

% --- 全局路径与参数配置 ---
currentFile = mfilename('fullpath');
[currentPath, ~, ~] = fileparts(currentFile);
addpath(genpath(fullfile(currentPath, '../lib')));
addpath(genpath(fullfile(currentPath, '../data')));
addpath(genpath(fullfile(currentPath, '../Bellhop2YS')));

plot_save_dir = fullfile(currentPath, '../results_plots/WUWNET/publication_figures');
if ~exist(plot_save_dir, 'dir'), mkdir(plot_save_dir); end

% 出版级图表全局参数
font_name = 'Times New Roman';
font_size_label = 13;
font_size_legend = 11;
font_size_title = 14;
font_size_tick = 11;
line_width_thick = 2.5;
line_width_thin = 1.5;

% 高级学术配色
color_A = [0.2, 0.2, 0.2]; % 黑色 (Baseline A)
color_B = [0.850, 0.325, 0.098]; % 橙红 (Baseline B)
color_C = [0.000, 0.447, 0.741]; % 深蓝 (Baseline C)
color_D = [0.850, 0.1, 0.1]; % 大红 (Proposed D) - 强调
color_Focus_Raw = [0.000, 0.447, 0.741];
color_Focus_TRM = [0.850, 0.1, 0.1];

fprintf('========================================================================\n');
fprintf('  开始生成 WUWNET 出版级精修图表...\n');
fprintf('========================================================================\n');

% =========================================================================
% 第 1 部分: 单信道 BER 横向对比图 (读取已存数据)
% =========================================================================
ber_data_path = fullfile(currentPath, '../results_plots/WUWNET/channel_15m_20km_34m/WUWNET_BER_Data.mat');
if exist(ber_data_path, 'file')
    fprintf('>>> 1. 正在生成 [Fig_BER_Comparison_Refined.png]...\n');
    load(ber_data_path);
    
    fig_ber = figure('Name', 'BER Comparison', 'Position', [100, 100, 650, 500], 'Color', 'w');
    semilogy(SNR_range, max(BER_A, 1e-6), '-s', 'LineWidth', line_width_thin, 'Color', color_A, 'MarkerSize', 8, 'MarkerFaceColor', 'w'); hold on;
    semilogy(SNR_range, max(BER_B, 1e-6), '-d', 'LineWidth', line_width_thin, 'Color', color_B, 'MarkerSize', 8, 'MarkerFaceColor', 'w');
    semilogy(SNR_range, max(BER_C, 1e-6), '-^', 'LineWidth', line_width_thin, 'Color', color_C, 'MarkerSize', 8, 'MarkerFaceColor', 'w');
    semilogy(SNR_range, max(BER_D, 1e-6), '-p', 'LineWidth', line_width_thick, 'Color', color_D, 'MarkerSize', 10, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', color_D);
    
    grid on; set(gca, 'YMinorGrid', 'on', 'XMinorGrid', 'on', 'GridAlpha', 0.4, 'GridLineStyle', ':', 'FontSize', font_size_tick, 'FontName', font_name);
    set(gca, 'TickDir', 'in', 'YScale', 'log');
    
    
    
    title('BER Performance in Shallow Water (20 km)', 'FontSize', font_size_title, 'FontWeight', 'bold', 'FontName', font_name);
    xlabel('Signal-to-Noise Ratio (dB)', 'FontSize', font_size_label, 'FontWeight', 'bold', 'FontName', font_name);
    ylabel('Bit Error Rate', 'FontSize', font_size_label, 'FontWeight', 'bold', 'FontName', font_name);
    
    lgd = legend({'No TRM + Std AKF', 'TRM + Std AKF', 'TRM + IAE-AKF (Heuristic)', 'Proposed TRM + HVB-AKF'}, 'Location', 'southwest');
    set(lgd, 'FontName', font_name, 'FontSize', font_size_legend, 'EdgeColor', 'none', 'Color', 'none');
    ylim([1e-4, 1.0]); xlim([min(SNR_range), max(SNR_range)]);
    
    exportgraphics(fig_ber, fullfile(plot_save_dir, 'Fig_BER_Comparison_Refined.png'), 'Resolution', 300);
    close(fig_ber);
else
    fprintf('未找到单信道 BER 数据 %s，跳过出图。\n', ber_data_path);
end

% =========================================================================
% 第 2 部分: 运行单次深度剖析仿真，获取底层数据 (空间聚焦、追踪误差、星座图)
% =========================================================================
fprintf('>>> 正在运行浅海环境单次深度剖析 (SNR = -8 dB) 以提取底层物理数据...\n');
% 信号初始化 (精简版)
fs = 48e3; f0 = 5e3; fh = 7e3; fl = 3e3; N_pn = 6;
load mseq.mat; mseq = mseq{2,1}; mseq(mseq==0) = -1; len_SS = length(mseq);
NumTotalSymbol_Short = 120;
load send_rand_data.mat;
send_data_raw_short = send_rand_data(1 : NumTotalSymbol_Short - 2);
RandBinaryData_polar = sign(send_rand_data(1:15000) - 0.5);
RandBinaryData_polar(RandBinaryData_polar == 0) = 1;
dc = zeros(1, 15001); dc(1) = 1;
for n = 1:15000, dc(n+1) = RandBinaryData_polar(n) * dc(n); end
BinaryData1_Short = dc(1 : NumTotalSymbol_Short - 1);
CodeSend = kron(BinaryData1_Short, mseq);
SignalI1 = rectpulse(real(CodeSend), N_pn);
t_mod = (0:length(SignalI1)-1)/fs;
SignalAftMod = SignalI1 .* cos(2*pi*f0*t_mod);
SignalAftMod = SignalAftMod / max(abs(SignalAftMod));
[b_bp, a_bp] = butter(4, [fl-500, fh+500]/(fs/2));
[b_lp, a_lp] = butter(4, 2500/(fs/2));
SignalAftMod = filtfilt(b_bp, a_bp, SignalAftMod);
pw = 0.5; SignalLfm = syncsig(pw, fl, fh, fs, 2, 2) * 0.85;
SignalDelay = zeros(1, round(0.8 * fs));
SignalSend = [SignalDelay SignalLfm SignalDelay SignalAftMod SignalDelay];

% 加载 Bellhop 信道
bellhop = load('../Bellhop2YS/channel_15m_20km_34m.mat');
delay_samples = round(bellhop.delay_clean * fs);
delay_samples = delay_samples - min(delay_samples) + 1;
h = zeros(1, max(delay_samples) + 100);
for i = 1:length(delay_samples)
    h(delay_samples(i)) = h(delay_samples(i)) + bellhop.amp_norm(i);
end
h = h / norm(h);
signal_channel = filter(h, 1, SignalSend);
mseq_ref = rectpulse(mseq, N_pn);

% 单次仿真参数
SNR_demo = -8;
noise_demo = randn(1, length(signal_channel));
NoiseFilt_demo = filter(b_bp, a_bp, noise_demo);
scale_noise_demo = sqrt(var(signal_channel) / (10^(SNR_demo/10)) / var(NoiseFilt_demo));
SignalRe_demo = signal_channel + NoiseFilt_demo * scale_noise_demo;
SignalAftBP_demo = filter(b_bp, a_bp, SignalRe_demo);

% 提取 CIR 并进行 CFAR
Ifft_est_demo = corr_fun(SignalAftBP_demo(1:round(fs*2.5)), SignalLfm);
[~, Peak_est_demo] = max(abs(Ifft_est_demo));
win_start_demo = max(1, Peak_est_demo - 50);
win_end_demo   = min(length(Ifft_est_demo), Peak_est_demo + 800);
h_raw_demo     = Ifft_est_demo(win_start_demo : win_end_demo);
noise_win_start_d = max(1, Peak_est_demo - 4000);
noise_win_end_d   = max(1, Peak_est_demo - 1000);
if noise_win_end_d <= noise_win_start_d, noise_win_start_d=1; noise_win_end_d=500; end
h_thresh_cfar_d = mean(abs(Ifft_est_demo(noise_win_start_d:noise_win_end_d))) + 3.5 * std(abs(Ifft_est_demo(noise_win_start_d:noise_win_end_d)));
h_cfar_demo = h_raw_demo; h_cfar_demo(abs(h_cfar_demo) < h_thresh_cfar_d) = 0;

h_tr_demo = fliplr(h_cfar_demo);
h_tr_demo = h_tr_demo / (max(abs(h_tr_demo)) + 1e-12);
h_equiv = conv(h_cfar_demo, h_tr_demo);

% --- 生成 TRM 空间聚焦图 ---
fprintf('>>> 2. 正在生成 [Fig_TRM_Focusing_Refined.png]...\n');
fig_trm = figure('Name', 'TRM Focusing', 'Position', [150, 150, 700, 500], 'Color', 'w');
subplot(2,1,1);
plot(abs(h_cfar_demo), 'Color', color_Focus_Raw, 'LineWidth', line_width_thin);
title('Estimated Multipath CIR (Shallow Water 20 km)', 'FontSize', font_size_title, 'FontWeight', 'bold', 'FontName', font_name);
grid on; ylabel('Amplitude', 'FontSize', font_size_label, 'FontName', font_name); 
set(gca, 'FontSize', font_size_tick, 'FontName', font_name, 'GridLineStyle', ':', 'GridAlpha', 0.6);

subplot(2,1,2);
plot(abs(h_equiv), 'Color', color_Focus_TRM, 'LineWidth', line_width_thin);
title('Equivalent CIR after TRM Spatial-Temporal Focusing', 'FontSize', font_size_title, 'FontWeight', 'bold', 'FontName', font_name);
grid on; ylabel('Amplitude', 'FontSize', font_size_label, 'FontName', font_name); 
xlabel('Tap Index', 'FontSize', font_size_label, 'FontName', font_name);
set(gca, 'FontSize', font_size_tick, 'FontName', font_name, 'GridLineStyle', ':', 'GridAlpha', 0.6);
exportgraphics(fig_trm, fullfile(plot_save_dir, 'Fig_TRM_Focusing_Refined.png'), 'Resolution', 300);
close(fig_trm);

% 运行 4 种解调算法
Sig_TRM_demo = conv(SignalAftBP_demo, h_tr_demo);
Sig_TRM_demo = Sig_TRM_demo(length(h_tr_demo) : end);
Sig_TRM_demo = Sig_TRM_demo / (max(abs(Sig_TRM_demo)) + 1e-12);
Ifft_TRM_d = corr_fun(Sig_TRM_demo(1:round(fs*2.5)), SignalLfm);
[~, Peak_TRM_d] = max(abs(Ifft_TRM_d));
start_cut_d = max(1, Peak_TRM_d + length(SignalDelay) - 400);
SigInt_d = Sig_TRM_demo(start_cut_d : end);
t_bb_d = (0:length(SigInt_d)-1)/fs;
sig_bb_trm_demo = filter(b_lp, a_lp, 2 * SigInt_d .* exp(-1j*2*pi*f0*t_bb_d));

if Peak_est_demo + length(SignalDelay) <= length(SignalAftBP_demo)
    Sig_a_demo = SignalAftBP_demo(Peak_est_demo + length(SignalDelay) : end);
    t1_demo = (0:length(Sig_a_demo)-1)/fs;
    sig_bb_a_demo = filter(b_lp, a_lp, 2 * Sig_a_demo .* exp(-1j*2*pi*f0*t1_demo));
    [out_frac_a_demo, ~, trk_err_a_demo, ~] = df_iakf_pll(sig_bb_a_demo, mseq_ref, 401, length(BinaryData1_Short), len_SS, N_pn, 2, 15, 0);
else
    out_frac_a_demo = ones(1, length(BinaryData1_Short)); trk_err_a_demo = zeros(1, length(BinaryData1_Short));
end

[out_frac_b_demo, ~, trk_err_b_demo, ~] = df_iakf_pll(sig_bb_trm_demo, mseq_ref, 401, length(BinaryData1_Short), len_SS, N_pn, 2, 15, 0);
[out_frac_c_demo, ~, trk_err_c_demo, ~] = df_iakf_pll(sig_bb_trm_demo, mseq_ref, 401, length(BinaryData1_Short), len_SS, N_pn, 2, 15, 1);
[out_frac_d_demo, ~, trk_err_d_demo, ~] = vb_iakf_pll(sig_bb_trm_demo, mseq_ref, 401, length(BinaryData1_Short), len_SS, N_pn, 2, 1);

% --- 生成动态追踪误差图 ---
fprintf('>>> 3. 正在生成 [Fig_Tracking_Error_Refined.png]...\n');
fig_trk = figure('Name', 'Tracking Error Trajectory', 'Position', [200, 200, 750, 450], 'Color', 'w');
plot(trk_err_a_demo, 'Color', color_A, 'LineWidth', line_width_thin); hold on;
plot(trk_err_b_demo, 'Color', color_B, 'LineWidth', line_width_thin);
plot(trk_err_c_demo, 'Color', color_C, 'LineWidth', line_width_thin);
plot(trk_err_d_demo, 'Color', color_D, 'LineWidth', line_width_thick); % 加粗凸显
grid on; set(gca, 'YMinorGrid', 'on', 'XMinorGrid', 'on', 'GridAlpha', 0.4, 'GridLineStyle', ':', 'FontSize', font_size_tick, 'FontName', font_name);
title(sprintf('Residual Tracking Error Trajectories (SNR = %d dB)', SNR_demo), 'FontSize', font_size_title, 'FontWeight', 'bold', 'FontName', font_name);
xlabel('Symbol Index', 'FontSize', font_size_label, 'FontWeight', 'bold', 'FontName', font_name);
ylabel('Tracking Error Estimate', 'FontSize', font_size_label, 'FontWeight', 'bold', 'FontName', font_name);
lgd_trk = legend({'No TRM + Std AKF', 'TRM + Std AKF', 'TRM + IAE-AKF (Heuristic)', 'Proposed TRM + HVB-AKF'}, 'FontSize', font_size_legend, 'Location', 'best');
set(lgd_trk, 'FontName', font_name, 'EdgeColor', 'none', 'Color', 'none');
exportgraphics(fig_trk, fullfile(plot_save_dir, 'Fig_Tracking_Error_Refined.png'), 'Resolution', 300);
close(fig_trk);

% --- 生成星座图 ---
fprintf('>>> 4. 正在生成 [Fig_Constellation_Refined.png]...\n');
diff_a = out_frac_a_demo(2:end) .* conj(out_frac_a_demo(1:end-1));
diff_b = out_frac_b_demo(2:end) .* conj(out_frac_b_demo(1:end-1));
diff_c = out_frac_c_demo(2:end) .* conj(out_frac_c_demo(1:end-1));
diff_d = out_frac_d_demo(2:end) .* conj(out_frac_d_demo(1:end-1));

fig_const = figure('Name', 'Soft Decision Constellations', 'Position', [250, 250, 1000, 280], 'Color', 'w');

subplot(1,4,1);
scatter(real(diff_a), imag(diff_a), 20, color_A, 'filled', 'MarkerFaceAlpha', 0.6);
grid on; title('No TRM + Std AKF', 'FontSize', font_size_legend, 'FontWeight', 'bold', 'FontName', font_name);
xlabel('I', 'FontName', font_name); ylabel('Q', 'FontName', font_name); axis square; set(gca, 'XLim', [-2 2], 'YLim', [-2 2], 'FontSize', 10, 'FontName', font_name, 'GridLineStyle', ':');

subplot(1,4,2);
scatter(real(diff_b), imag(diff_b), 20, color_B, 'filled', 'MarkerFaceAlpha', 0.6);
grid on; title('TRM + Std AKF', 'FontSize', font_size_legend, 'FontWeight', 'bold', 'FontName', font_name);
xlabel('I', 'FontName', font_name); ylabel('Q', 'FontName', font_name); axis square; set(gca, 'XLim', [-2 2], 'YLim', [-2 2], 'FontSize', 10, 'FontName', font_name, 'GridLineStyle', ':');

subplot(1,4,3);
scatter(real(diff_c), imag(diff_c), 20, color_C, 'filled', 'MarkerFaceAlpha', 0.6);
grid on; title('TRM + IAE-AKF', 'FontSize', font_size_legend, 'FontWeight', 'bold', 'FontName', font_name);
xlabel('I', 'FontName', font_name); ylabel('Q', 'FontName', font_name); axis square; set(gca, 'XLim', [-2 2], 'YLim', [-2 2], 'FontSize', 10, 'FontName', font_name, 'GridLineStyle', ':');

subplot(1,4,4);
scatter(real(diff_d), imag(diff_d), 20, color_D, 'filled', 'MarkerFaceAlpha', 0.6);
grid on; title('Proposed HVB-AKF', 'FontSize', font_size_legend, 'FontWeight', 'bold', 'FontName', font_name);
xlabel('I', 'FontName', font_name); ylabel('Q', 'FontName', font_name); axis square; set(gca, 'XLim', [-2 2], 'YLim', [-2 2], 'FontSize', 10, 'FontName', font_name, 'GridLineStyle', ':');

exportgraphics(fig_const, fullfile(plot_save_dir, 'Fig_Constellation_Refined.png'), 'Resolution', 300);
close(fig_const);

fprintf('========================================================================\n');
fprintf('  精修图表生成完毕！保存在: %s\n', plot_save_dir);
fprintf('========================================================================\n');
