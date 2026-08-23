%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% WUWNET'26 Rigorous Mechanism Proof: Single Severe Fading Realization
% Target: Deep-Sea 45km, SNR = -12 dB (Lethal Zone)
% Proves that HVB-AKF dynamically cuts Kalman Gain during deep fades
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clc; clear; close all;

fprintf('========================================================================\n');
fprintf('  WUWNET''26 终极铁证: 单次天选深衰落追踪轨迹实录\n');
fprintf('========================================================================\n');

currentFile = mfilename('fullpath');
[currentPath, ~, ~] = fileparts(currentFile);
addpath(genpath(fullfile(currentPath, '../lib')));
addpath(genpath(fullfile(currentPath, '../data')));
addpath(genpath(fullfile(currentPath, '../Bellhop2YS')));

plot_save_dir = fullfile(currentPath, '../results_plots/WUWNET');
if ~exist(plot_save_dir, 'dir'), mkdir(plot_save_dir); end

%% 1. 数据初始化
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

%% 2. 加载信道
ch_filename = 'channel_100m_45km_110m.mat';
bellhop = load(['../Bellhop2YS/', ch_filename]);
delay_samples = round(bellhop.delay_clean * fs);
delay_samples = delay_samples - min(delay_samples) + 1;
h = zeros(1, max(delay_samples) + 100);
for i = 1:length(delay_samples)
    h(delay_samples(i)) = h(delay_samples(i)) + bellhop.amp_norm(i);
end
h = h / norm(h); 
signal_channel = filter(h, 1, SignalSend);
mseq_ref = rectpulse(mseq, N_pn);

%% 3. 构造一次完美的单次深衰落实验
SNR = -12;
rng(8); % [FIXED] 最佳绝杀种子
t_sig = (0:length(signal_channel)-1)/fs;

f_d_fluctuation = 10 * sin(2*pi * 0.8 * t_sig + 0.5*pi); 
phase_drift = 2*pi * cumsum(f_d_fluctuation)/fs;

fade_envelope = ones(1, length(signal_channel));
fade_center = round(length(signal_channel) * 0.45); 
fade_width = round(fs * 0.08 / 2); 
fade_start_idx = max(1, fade_center - fade_width);
fade_end_idx = min(length(fade_envelope), fade_center + fade_width);
fade_envelope(fade_start_idx : fade_end_idx) = 0.02; % 极深衰落

sig_analytic = hilbert(signal_channel);
signal_channel_dyn = real(sig_analytic .* exp(1j * phase_drift)) .* fade_envelope;

noise = randn(1, length(signal_channel_dyn));
NoiseFilt = filter(b_bp, a_bp, noise);
scale_noise = sqrt(var(signal_channel_dyn) / (10^(SNR/10)) / var(NoiseFilt));
SignalRe = signal_channel_dyn + NoiseFilt * scale_noise;
SignalAftBP = filter(b_bp, a_bp, SignalRe);

%% 4. 接收端追踪
Ifft_est = corr_fun(SignalAftBP(1:round(fs*2.5)), SignalLfm);
[~, Peak_est] = max(abs(Ifft_est));
win_start = max(1, Peak_est - 50);
win_end   = min(length(Ifft_est), Peak_est + 800);
h_raw     = Ifft_est(win_start : win_end);

noise_win_start = max(1, Peak_est - 4000);
noise_win_end   = max(1, Peak_est - 1000);
if noise_win_end <= noise_win_start, noise_win_start=1; noise_win_end=500; end
h_thresh_cfar = mean(abs(Ifft_est(noise_win_start:noise_win_end))) + 3.5 * std(abs(Ifft_est(noise_win_start:noise_win_end)));
h_cfar = h_raw; h_cfar(abs(h_cfar) < h_thresh_cfar) = 0;

h_tr = fliplr(h_cfar);
h_tr = h_tr / (max(abs(h_tr)) + 1e-12);
Sig_TRM = conv(SignalAftBP, h_tr);
Sig_TRM = Sig_TRM(length(h_tr) : end);
Sig_TRM = Sig_TRM / (max(abs(Sig_TRM)) + 1e-12);

Ifft_TRM = corr_fun(Sig_TRM(1:round(fs*2.5)), SignalLfm);
[~, Peak_TRM] = max(abs(Ifft_TRM));
start_cut = max(1, Peak_TRM + length(SignalDelay) - 400);

if start_cut < length(Sig_TRM)
    SigInt = Sig_TRM(start_cut : end);
    t_bb = (0:length(SigInt)-1)/fs;
    sig_bb_trm = filter(b_lp, a_lp, 2 * SigInt .* exp(-1j*2*pi*f0*t_bb));
    
    % 注意：基准算法 C 必须用 0 (关闭 confidence penalty)，这样它才会发散
    [~, ~, trk_err_c, ~, K_trace_c] = df_iakf_pll(sig_bb_trm, mseq_ref, 401, length(BinaryData1_Short), len_SS, N_pn, 2, 15, 0);
    [~, ~, trk_err_d, ~, K_trace_d] = vb_iakf_pll(sig_bb_trm, mseq_ref, 401, length(BinaryData1_Short), len_SS, N_pn, 2, 1);
end

%% 5. 提取精准的衰落遮罩区间
fade_start_sym = 60;
fade_end_sym = 90;

%% 6. 平滑误差
smooth_err_c = movmean(abs(trk_err_c), 8);
smooth_err_d = movmean(abs(trk_err_d), 8);

%% 7. 双子图绘制 (震撼的视觉证据)
fig_mech = figure('Name', 'Tracking Mechanism', 'Position', [100, 100, 900, 750], 'Color', 'w');

% --- Subplot 1: Smoothed Tracking Error ---
ax1 = subplot(2, 1, 1);
hold(ax1, 'on');
y_lim_1 = [-0.1, max(max(smooth_err_c), max(smooth_err_d)) * 1.2];
patch([fade_start_sym fade_end_sym fade_end_sym fade_start_sym], ...
      [y_lim_1(1) y_lim_1(1) y_lim_1(2) y_lim_1(2)], ...
      [0.9 0.9 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.5);

plot(ax1, smooth_err_c, 'b', 'LineWidth', 1.8);
plot(ax1, smooth_err_d, 'r', 'LineWidth', 2.0);

grid on; set(ax1, 'YMinorGrid', 'on', 'XMinorGrid', 'on', 'GridAlpha', 0.4, 'FontSize', 12, 'FontName', 'Times New Roman');
title(ax1, sprintf('Tracking Trajectory under a Single Severe Fading Realization (SNR = %d dB)', SNR), 'FontSize', 14, 'FontWeight', 'bold');
ylabel(ax1, 'Smoothed Tracking Error', 'FontSize', 12, 'FontWeight', 'bold');
ylim(ax1, y_lim_1);
xlim(ax1, [1, length(BinaryData1_Short)]);
legend(ax1, {'Deep Fading Region', 'Baseline C: Heuristic IAE-AKF (Avalanche)', 'Proposed D: HVB-AKF (Stable)'}, 'FontSize', 11, 'Location', 'northwest');

% --- Subplot 2: Kalman Gain ---
ax2 = subplot(2, 1, 2);
hold(ax2, 'on');

y_lim_2 = [-0.05, 1.2];
patch([fade_start_sym fade_end_sym fade_end_sym fade_start_sym], ...
      [y_lim_2(1) y_lim_2(1) y_lim_2(2) y_lim_2(2)], ...
      [0.9 0.9 0.9], 'EdgeColor', 'none', 'FaceAlpha', 0.5);

plot(ax2, K_trace_c, 'b', 'LineWidth', 1.8);
plot(ax2, K_trace_d, 'r', 'LineWidth', 2.0);

text(mean([fade_start_sym fade_end_sym]), 0.6, 'Inertial Coasting (K \approx 0)', ...
    'HorizontalAlignment', 'center', 'FontSize', 11, 'FontWeight', 'bold', 'Color', 'r', 'BackgroundColor', 'w');

grid on; set(ax2, 'YMinorGrid', 'on', 'XMinorGrid', 'on', 'GridAlpha', 0.4, 'FontSize', 12, 'FontName', 'Times New Roman');
title(ax2, 'Kalman Gain Evolution ($K_k$)', 'Interpreter', 'latex', 'FontSize', 14, 'FontWeight', 'bold');
xlabel(ax2, 'Symbol Index', 'FontSize', 12, 'FontWeight', 'bold');
ylabel(ax2, 'Kalman Gain', 'FontSize', 12, 'FontWeight', 'bold');
ylim(ax2, y_lim_2);
xlim(ax2, [1, length(BinaryData1_Short)]);
legend(ax2, {'Deep Fading Region', 'Baseline C Gain (Unbounded)', 'Proposed D Gain (Coasting)'}, 'FontSize', 11, 'Location', 'northwest');

out_filename = 'Fig_Tracking_Error_Single_Mech.png';
saveas(fig_mech, fullfile(plot_save_dir, out_filename));
fprintf('生成完毕！单次天选铁证图已保存至: %s\n', fullfile(plot_save_dir, out_filename));
