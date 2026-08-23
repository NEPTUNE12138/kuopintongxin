%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% WUWNET'26 Independent Tracking Trajectory Generator (Deep-Sea 45km, SNR=-8dB)
% Generates Ensemble Averaged Tracking Error under Extreme Deep Fading
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clc; clear; close all;

fprintf('========================================================================\n');
fprintf('  WUWNET''26 极值追踪测试: 深海 45km (3000次系综平均)\n');
fprintf('========================================================================\n');

% ==================== 参数设定 ====================
MONTE_CARLO_ITERS = 3000;
currentFile = mfilename('fullpath');
[currentPath, ~, ~] = fileparts(currentFile);
addpath(genpath(fullfile(currentPath, '../lib')));
addpath(genpath(fullfile(currentPath, '../data')));
addpath(genpath(fullfile(currentPath, '../Bellhop2YS')));

plot_save_dir = fullfile(currentPath, '../results_plots/WUWNET');
if ~exist(plot_save_dir, 'dir'), mkdir(plot_save_dir); end

%% 1. 数据初始化与调制
fs = 48e3; f0 = 5e3; fh = 7e3; fl = 3e3; N_pn = 6;
load mseq.mat; mseq = mseq{2,1}; mseq(mseq==0) = -1; len_SS = length(mseq);

NumTotalSymbol_Short = 120; % 数据帧长
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

%% 2. 加载深海 45km 信道
ch_filename = 'channel_100m_45km_110m.mat';
ch_desc = '深海 45km';
fprintf('>>> 加载信道: %s\n', ch_filename);

bellhop = load(['../Bellhop2YS/', ch_filename]);
delay_samples = round(bellhop.delay_clean * fs);
delay_samples = delay_samples - min(delay_samples) + 1;
h = zeros(1, max(delay_samples) + 100);
for i = 1:length(delay_samples)
    h(delay_samples(i)) = h(delay_samples(i)) + bellhop.amp_norm(i);
end
h = h / norm(h); % 能量归一化
signal_channel = filter(h, 1, SignalSend);
mseq_ref = rectpulse(mseq, N_pn);

%% 3. 执行蒙特卡洛系综追踪测试
SNR = -8;
fprintf('>>> 开始执行 %d 次蒙特卡洛迭代 (SNR = %d dB)...\n', MONTE_CARLO_ITERS, SNR);

% 用于累积追踪误差
sum_trk_err_a = zeros(1, length(BinaryData1_Short));
sum_trk_err_b = zeros(1, length(BinaryData1_Short));
sum_trk_err_c = zeros(1, length(BinaryData1_Short));
sum_trk_err_d = zeros(1, length(BinaryData1_Short));
valid_iters = 0;

for trial = 1 : MONTE_CARLO_ITERS
    % --- 物理场深衰落与非平稳多普勒注入 ---
    t_sig = (0:length(signal_channel)-1)/fs;
    % 正弦多普勒随机游走
    f_d_fluctuation = 10 * sin(2*pi * (0.5 + 0.5*rand()) * t_sig + rand()*2*pi); 
    phase_drift = 2*pi * cumsum(f_d_fluctuation)/fs;
    
    % 包内突发深衰落 (模拟信号瞬时被遮挡，达 -20dB)
    fade_envelope = ones(1, length(signal_channel));
    fade_center = round(length(signal_channel) * (0.3 + 0.4*rand())); 
    fade_width = round(fs * 0.05 / 2); % 50 ms 衰落
    fade_start_idx = max(1, fade_center - fade_width);
    fade_end_idx = min(length(fade_envelope), fade_center + fade_width);
    fade_envelope(fade_start_idx : fade_end_idx) = 0.1;
    
    % 施加物理失真
    sig_analytic = hilbert(signal_channel);
    signal_channel_dyn = real(sig_analytic .* exp(1j * phase_drift)) .* fade_envelope;
    
    % 加噪声
    noise = randn(1, length(signal_channel_dyn));
    NoiseFilt = filter(b_bp, a_bp, noise);
    scale_noise = sqrt(var(signal_channel_dyn) / (10^(SNR/10)) / var(NoiseFilt));
    SignalRe = signal_channel_dyn + NoiseFilt * scale_noise;
    SignalAftBP = filter(b_bp, a_bp, SignalRe);
    
    % CIR 估计
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
    
    % Baseline A (No TRM)
    if Peak_est + length(SignalDelay) <= length(SignalAftBP)
        Sig_a = SignalAftBP(Peak_est + length(SignalDelay) : end);
        t1 = (0:length(Sig_a)-1)/fs;
        sig_bb_a = filter(b_lp, a_lp, 2 * Sig_a .* exp(-1j*2*pi*f0*t1));
        [~, ~, trk_err_a, ~] = df_iakf_pll(sig_bb_a, mseq_ref, 401, length(BinaryData1_Short), len_SS, N_pn, 2, 15, 0);
    else
        trk_err_a = ones(1, length(BinaryData1_Short)); % Penalty
    end

    % CFAR-TRM 预聚焦
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
        
        % Baseline B: TRM + Std AKF
        [~, ~, trk_err_b, ~] = df_iakf_pll(sig_bb_trm, mseq_ref, 401, length(BinaryData1_Short), len_SS, N_pn, 2, 15, 0);
        % Baseline C: TRM + IAE-AKF
        [~, ~, trk_err_c, ~] = df_iakf_pll(sig_bb_trm, mseq_ref, 401, length(BinaryData1_Short), len_SS, N_pn, 2, 15, 1);
        % Proposed D: TRM + VB-AKF
        [~, ~, trk_err_d, ~] = vb_iakf_pll(sig_bb_trm, mseq_ref, 401, length(BinaryData1_Short), len_SS, N_pn, 2, 1);
        
        % 累积误差绝对值
        if length(trk_err_a) == length(sum_trk_err_a) && length(trk_err_b) == length(sum_trk_err_a) && length(trk_err_c) == length(sum_trk_err_a) && length(trk_err_d) == length(sum_trk_err_a)
            sum_trk_err_a = sum_trk_err_a + abs(trk_err_a);
            sum_trk_err_b = sum_trk_err_b + abs(trk_err_b);
            sum_trk_err_c = sum_trk_err_c + abs(trk_err_c);
            sum_trk_err_d = sum_trk_err_d + abs(trk_err_d);
            valid_iters = valid_iters + 1;
        end
    end
    
    if mod(trial, 100) == 0
        fprintf('已完成 %d / %d 次迭代...\n', trial, MONTE_CARLO_ITERS);
    end
end

% 计算系综平均
avg_trk_err_a = sum_trk_err_a / valid_iters;
avg_trk_err_b = sum_trk_err_b / valid_iters;
avg_trk_err_c = sum_trk_err_c / valid_iters;
avg_trk_err_d = sum_trk_err_d / valid_iters;

%% 4. 出图
fig_trk = figure('Name', '系综平均追踪误差', 'Position', [300, 300, 850, 450], 'Color', 'w');
plot(avg_trk_err_a, 'k', 'LineWidth', 1.5); hold on;
plot(avg_trk_err_b, 'm', 'LineWidth', 1.5);
plot(avg_trk_err_c, 'b', 'LineWidth', 1.5);
plot(avg_trk_err_d, 'r', 'LineWidth', 2.0);
grid on; set(gca, 'YMinorGrid', 'on', 'XMinorGrid', 'on', 'GridAlpha', 0.4, 'FontSize', 12, 'FontName', 'Times New Roman');
title(sprintf('Ensemble Averaged Tracking Error (%s, SNR = %d dB, %d Trials)', ch_desc, SNR, valid_iters), 'FontSize', 14, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
xlabel('Symbol Index', 'FontSize', 13, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
ylabel('Mean Absolute Tracking Error', 'FontSize', 13, 'FontWeight', 'bold', 'FontName', 'Times New Roman');
legend({'Baseline A: No TRM + Std AKF', 'Baseline B: TRM + Std AKF', 'Baseline C: TRM + IAE-AKF (Heuristic)', 'Proposed: TRM + HVB-AKF'}, 'FontSize', 11, 'Location', 'best');

% 保存结果
out_filename = 'Fig_Tracking_Error_DeepSea_Ensemble.png';
saveas(fig_trk, fullfile(plot_save_dir, out_filename));
close(fig_trk);
fprintf('========================================================================\n');
fprintf('生成完毕！超高置信度轨迹图已保存至: %s\n', fullfile(plot_save_dir, out_filename));
fprintf('========================================================================\n');
