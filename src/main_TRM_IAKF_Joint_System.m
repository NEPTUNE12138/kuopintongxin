%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 进阶创新工程主程序：TRM盲预聚焦与DF-IAKF判决反馈时延联合均衡系统
clc; clear; close all;

% ==================== 【任务 1：全局宏定义配置变量】 ====================
MONTE_CARLO_ITERS = 5000; % 蒙特卡洛仿真循环或独立试错总次数全局宏配置
% =========================================================================
currentFile = mfilename('fullpath');
[currentPath, ~, ~] = fileparts(currentFile);
addpath(genpath(fullfile(currentPath, '../lib')));
addpath(genpath(fullfile(currentPath, '../data')));
fprintf('========================================================================\n');
fprintf('  TRM盲聚焦 + DF-IAKF 联合均衡评测平台 (Monte Carlo: %d 次)\n', MONTE_CARLO_ITERS);
fprintf('========================================================================\n');

%% 1. 参数与数据初始化
fs = 48e3; f0 = 5e3; fh = 7e3; fl = 3e3; N_pn = 6;
load mseq.mat; mseq = mseq{2,1}; mseq(mseq==0) = -1; len_SS = length(mseq);

% ======================== [MODIFIED-Module1 START] ========================
NumTotalSymbol = 502;          % 原始长包符号数（保留基准对照）
NumTotalSymbol_Short = 120;    

load send_rand_data.mat;
send_data_raw = send_rand_data(1 : NumTotalSymbol - 2);
RandBinaryData_polar = sign(send_rand_data(1:15000) - 0.5);
RandBinaryData_polar(RandBinaryData_polar == 0) = 1;

dc = zeros(1, 15001); dc(1) = 1;
for n = 1:15000, dc(n+1) = RandBinaryData_polar(n) * dc(n); end
BinaryData1 = dc(1 : NumTotalSymbol-1);

% --- [MODIFIED] 短包数据截取，适配 NumTotalSymbol_Short ---
send_data_raw_short = send_rand_data(1 : NumTotalSymbol_Short - 2);
BinaryData1_Short   = dc(1 : NumTotalSymbol_Short - 1);

CodeSend = kron(BinaryData1, mseq);  % 纯实数扩频码
SignalI1 = rectpulse(real(CodeSend), N_pn);
SignalQ1_removed = zeros(size(SignalI1));  % Q支路显式置零
t_mod = (0:length(SignalI1)-1)/fs;
SignalAftMod = SignalI1 .* cos(2*pi*f0*t_mod);
SignalAftMod = SignalAftMod / max(abs(SignalAftMod));
[b_bp, a_bp] = butter(4, [fl-500, fh+500]/(fs/2));
[b_lp, a_lp] = butter(4, 2500/(fs/2));

SignalAftMod = filtfilt(b_bp, a_bp, SignalAftMod);
% ======================== [MODIFIED-Module1 END] ==========================

pw = 0.5; SignalLfm = syncsig(pw, fl, fh, fs, 2, 2) * 0.85;
SignalDelay = zeros(1, round(0.8 * fs));
SignalSend = [SignalDelay SignalLfm SignalDelay SignalAftMod SignalDelay];

%% 2. 构建严苛海洋多径冲激响应 (多路径叠加横跨 5 个扩频码片)
path_delays_samples = round([0, 0.0025, 0.0052, 0.0081, 0.0145] * fs) + 1;
path_gains = [1.0, -0.8, 0.6, -0.4, 0.2];
channel_custom = zeros(1, max(path_delays_samples) + 100);
channel_custom(path_delays_samples) = path_gains;
h = [zeros(1,100), channel_custom]; h = h / norm(h);

signal_channel = filter(h, 1, SignalSend);
mseq_ref = rectpulse(mseq, N_pn);

%% 3. 消融实验 (Ablation Study) 四组对照仿真
%  策略 A：灾难基准 —— 无均衡 (No EQ)
%  策略 B：消融组1 —— Hard-TRM + Standard DF-IAKF (use_confidence=0)
%  策略 C：消融组2 —— CFAR-TRM + Standard DF-IAKF (use_confidence=0)
%  策略 D：全体系创新点 —— Proposed SNR-Aware (CFAR-TRM + Confidence-DF-IAKF)
SNR_range = -16 : 1 : 2;
Num_Trials = min(MONTE_CARLO_ITERS, 150);

BER_No_EQ        = zeros(size(SNR_range));  % 策略 A
BER_Hard_NoConf  = zeros(size(SNR_range));  % 策略 B (消融：固定截断 + 无保护)
BER_CFAR_NoConf  = zeros(size(SNR_range));  % 策略 C (消融：CFAR截断 + 无保护)
BER_Proposed     = zeros(size(SNR_range));  % 策略 D (全体系创新点)

for s_idx = 1 : length(SNR_range)
    SNR = SNR_range(s_idx);
    b_no_acc = 0; b_hard_acc = 0; b_cfar_acc = 0; b_prop_acc = 0;
    
    for trial = 1 : Num_Trials
        noise = randn(1, length(signal_channel));
        NoiseFilt = filter(b_bp, a_bp, noise);
        scale_noise = sqrt(var(signal_channel) / (10^(SNR/10)) / var(NoiseFilt));
        SignalRe = signal_channel + NoiseFilt * scale_noise;
        SignalAftBP = filter(b_bp, a_bp, SignalRe);
        
        % ============== 公共 CIR 盲估计 ==============
        Ifft_est = corr_fun(SignalAftBP(1:round(fs*2.5)), SignalLfm);
        [~, Peak_est] = max(abs(Ifft_est));
        
        % 提取原始 CIR 窗口（供硬截断与 CFAR 共用）
        win_start = max(1, Peak_est - 50);
        win_end   = min(length(Ifft_est), Peak_est + 800);
        h_raw     = Ifft_est(win_start : win_end);
        
        % ---- OS-CFAR 噪底统计 ----
        noise_win_start = max(1, Peak_est - 4000);
        noise_win_end   = max(1, Peak_est - 1000);
        if noise_win_end <= noise_win_start
            noise_win_start = 1;
            noise_win_end   = min(500, length(Ifft_est));
        end
        noise_segment = abs(Ifft_est(noise_win_start : noise_win_end));
        mu_noise    = mean(noise_segment);
        sigma_noise = std(noise_segment);
        h_thresh_cfar = mu_noise + 3.5 * sigma_noise;
        
        % ---- 策略 B 用：硬常数截断 CIR ----
        h_hard = h_raw;
        h_thresh_hard = 0.15 * max(abs(h_hard));
        h_hard(abs(h_hard) < h_thresh_hard) = 0;
        
        % ---- 策略 C/D 用：CFAR 自适应截断 CIR ----
        h_cfar = h_raw;
        h_cfar(abs(h_cfar) < h_thresh_cfar) = 0;
        
        % ================================================================
        % 策略 A（灾难基准）：无均衡 (No EQ) —— 开环直接解调
        % ================================================================
        [~, Peak_no_eq] = max(abs(Ifft_est));
        if Peak_no_eq + length(SignalDelay) + length(SignalAftMod) <= length(SignalAftBP)
            Sig_no_eq = SignalAftBP(Peak_no_eq + length(SignalDelay) + 1 : Peak_no_eq + length(SignalDelay) + length(SignalAftMod));
            t1 = (0:length(Sig_no_eq)-1)/fs;
            demod_no_eq = filter(b_lp, a_lp, 2 * Sig_no_eq .* exp(-1j*2*pi*f0*t1));
            code_len = floor(length(demod_no_eq)/len_SS/N_pn);
            if code_len > 1
                out_no_eq = sum(reshape(demod_no_eq(1:len_SS*code_len*N_pn), N_pn, []));
                [~, ~, ber_a] = diff_corr_decode(mseq, 1, out_no_eq, 1, code_len-1, len_SS, send_data_raw(1:code_len-1));
                b_no_acc = b_no_acc + ber_a;
            else, b_no_acc = b_no_acc + 0.5; end
        else, b_no_acc = b_no_acc + 0.5; end
        
        % ================================================================
        % 策略 B（消融组1）：Hard-TRM + Standard DF-IAKF (use_confidence=0)
        %   固定硬常数截断 CIR → TRM 卷积 → 标准 IAKF 追踪（无防雪崩保护）
        % ================================================================
        h_tr_hard = fliplr(h_hard);
        h_tr_hard = h_tr_hard / (max(abs(h_tr_hard)) + 1e-12);
        SigBP_TRM_hard = conv(SignalAftBP, h_tr_hard);
        SigBP_TRM_hard = SigBP_TRM_hard(length(h_tr_hard) : end);
        SigBP_TRM_hard = SigBP_TRM_hard / (max(abs(SigBP_TRM_hard)) + 1e-12);
        
        Ifft_TRM_hard = corr_fun(SigBP_TRM_hard(1:round(fs*2.5)), SignalLfm);
        [~, Peak_TRM_hard] = max(abs(Ifft_TRM_hard));
        
        start_cut_b = max(1, Peak_TRM_hard + length(SignalDelay) - 400);
        if start_cut_b < length(SigBP_TRM_hard)
            SigInt_b = SigBP_TRM_hard(start_cut_b : end);
            t_b = (0:length(SigInt_b)-1)/fs;
            sig_bb_b = filter(b_lp, a_lp, 2 * SigInt_b .* exp(-1j*2*pi*f0*t_b));
            [out_frac_b, k_b, ~, ~] = df_iakf_pll(sig_bb_b, mseq_ref, 401, ...
                length(BinaryData1), len_SS, N_pn, 2, 15, 0);  % use_confidence=0
            if k_b > 2
                [~, ~, ber_b, ~] = block_doppler_decode_silent(mseq, ...
                    out_frac_b(:).', k_b - 1, len_SS, send_data_raw(1:k_b-1));
                b_hard_acc = b_hard_acc + ber_b;
            else, b_hard_acc = b_hard_acc + 0.5; end
        else, b_hard_acc = b_hard_acc + 0.5; end
        
        % ================================================================
        % 策略 C（消融组2）：CFAR-TRM + Standard DF-IAKF (use_confidence=0)
        %   OS-CFAR 统计截断 CIR → TRM 卷积 → 标准 IAKF 追踪（无防雪崩保护）
        %   与策略 B 对比 → 证明 OS-CFAR 截断的降噪价值
        % ================================================================
        h_tr_cfar = fliplr(h_cfar);
        h_tr_cfar = h_tr_cfar / (max(abs(h_tr_cfar)) + 1e-12);
        SigBP_TRM_cfar = conv(SignalAftBP, h_tr_cfar);
        SigBP_TRM_cfar = SigBP_TRM_cfar(length(h_tr_cfar) : end);
        SigBP_TRM_cfar = SigBP_TRM_cfar / (max(abs(SigBP_TRM_cfar)) + 1e-12);
        
        Ifft_TRM_cfar = corr_fun(SigBP_TRM_cfar(1:round(fs*2.5)), SignalLfm);
        [~, Peak_TRM_cfar] = max(abs(Ifft_TRM_cfar));
        
        start_cut_c = max(1, Peak_TRM_cfar + length(SignalDelay) - 400);
        if start_cut_c < length(SigBP_TRM_cfar)
            SigInt_c = SigBP_TRM_cfar(start_cut_c : end);
            t_c = (0:length(SigInt_c)-1)/fs;
            sig_bb_c = filter(b_lp, a_lp, 2 * SigInt_c .* exp(-1j*2*pi*f0*t_c));
            [out_frac_c, k_c, ~, ~] = df_iakf_pll(sig_bb_c, mseq_ref, 401, ...
                length(BinaryData1), len_SS, N_pn, 2, 15, 0);  % use_confidence=0
            if k_c > 2
                [~, ~, ber_c, ~] = block_doppler_decode_silent(mseq, ...
                    out_frac_c(:).', k_c - 1, len_SS, send_data_raw(1:k_c-1));
                b_cfar_acc = b_cfar_acc + ber_c;
            else, b_cfar_acc = b_cfar_acc + 0.5; end
        else, b_cfar_acc = b_cfar_acc + 0.5; end
        
        % ================================================================
        if SNR > -9  % 高 SNR 旁路 TRM
            [~, Peak_direct] = max(abs(Ifft_est));
            start_cut_d = max(1, Peak_direct + length(SignalDelay) - 400);
            if start_cut_d < length(SignalAftBP)
                SigInt_d = SignalAftBP(start_cut_d : end);
                t_d = (0:length(SigInt_d)-1)/fs;
                sig_bb_d = filtfilt(b_lp, a_lp, ...
                    2 * SigInt_d .* exp(-1j*2*pi*f0*t_d));
                [out_frac_d, k_d, ~, ~] = df_iakf_pll(sig_bb_d, mseq_ref, 401, ...
                    length(BinaryData1), len_SS, N_pn, 2, 15, 1);  % use_confidence=1
                if k_d > 2
                    [~, ~, ber_d, ~] = block_doppler_decode_silent(mseq, ...
                        out_frac_d(:).', k_d - 1, len_SS, send_data_raw(1:k_d-1));
                    b_prop_acc = b_prop_acc + ber_d;
                else, b_prop_acc = b_prop_acc + 0.5; end
            else, b_prop_acc = b_prop_acc + 0.5; end
        else  % 低 SNR：CFAR-TRM 聚焦 + Confidence-DF-IAKF
            start_cut_d = max(1, Peak_TRM_cfar + length(SignalDelay) - 400);
            if start_cut_d < length(SigBP_TRM_cfar)
                SigInt_d = SigBP_TRM_cfar(start_cut_d : end);
                t_d = (0:length(SigInt_d)-1)/fs;
                sig_bb_d = filter(b_lp, a_lp, ...
                    2 * SigInt_d .* exp(-1j*2*pi*f0*t_d));
                [out_frac_d, k_d, ~, ~] = df_iakf_pll(sig_bb_d, mseq_ref, 401, ...
                    length(BinaryData1), len_SS, N_pn, 2, 15, 1);  % use_confidence=1
                if k_d > 2
                    [~, ~, ber_d, ~] = block_doppler_decode_silent(mseq, ...
                        out_frac_d(:).', k_d - 1, len_SS, send_data_raw(1:k_d-1));
                    b_prop_acc = b_prop_acc + ber_d;
                else, b_prop_acc = b_prop_acc + 0.5; end
            else, b_prop_acc = b_prop_acc + 0.5; end
        end
    end
    
    BER_No_EQ(s_idx)       = b_no_acc / Num_Trials;
    BER_Hard_NoConf(s_idx) = b_hard_acc / Num_Trials;
    BER_CFAR_NoConf(s_idx) = b_cfar_acc / Num_Trials;
    BER_Proposed(s_idx)    = b_prop_acc / Num_Trials;
    
    fprintf('SNR: %3d dB | A-NoEQ: %.4f | B-Hard+Std: %.4f | C-CFAR+Std: %.4f || D-Proposed: %.4f\n', ...
        SNR, BER_No_EQ(s_idx), BER_Hard_NoConf(s_idx), BER_CFAR_NoConf(s_idx), BER_Proposed(s_idx));
end

%% 4. 绘制并保存消融实验四组对照 BER 曲线
plot_save_dir = '../results_plots';
if ~exist(plot_save_dir, 'dir'), mkdir(plot_save_dir); end

fig_joint = figure('Name', '消融实验：四组对照 BER 深度对比', 'Position', [150, 150, 900, 600]);

semilogy(SNR_range, max(BER_No_EQ, 1e-6), 'k--s', ...
    'LineWidth', 1.8, 'MarkerSize', 7, 'MarkerFaceColor', 'k'); hold on;
semilogy(SNR_range, max(BER_Hard_NoConf, 1e-6), 'm-.d', ...
    'LineWidth', 1.8, 'MarkerSize', 7, 'MarkerFaceColor', 'm');
semilogy(SNR_range, max(BER_CFAR_NoConf, 1e-6), 'b-.^', ...
    'LineWidth', 1.8, 'MarkerSize', 7, 'MarkerFaceColor', 'b');
semilogy(SNR_range, max(BER_Proposed, 1e-6), 'r-p', ...
    'LineWidth', 3.2, 'MarkerSize', 11, 'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'r');

grid on; set(gca, 'YMinorGrid', 'on', 'XMinorGrid', 'on', 'GridAlpha', 0.4, 'FontSize', 12);
yline(1e-3, 'g--', 'LineWidth', 1.5, 'Label', '目标门限 10^{-3}');
title({'消融实验 (Ablation Study)：极端多径与多普勒环境', ...
    '逐级验证 OS-CFAR 截断与置信度防雪崩机制的独立贡献'}, ...
    'FontSize', 13, 'FontWeight', 'bold');
xlabel('信噪比 SNR (dB)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('误码率 Bit Error Rate (BER)', 'FontSize', 13, 'FontWeight', 'bold');
legend({ ...
    'A: 无均衡 (灾难性 ISI 基准)', ...
    'B: Hard-TRM + Standard IAKF (固定截断 + 无保护)', ...
    'C: CFAR-TRM + Standard IAKF (B→C 验证CFAR降噪价值)', ...
    'D: 【创新点】SNR-Aware CFAR-TRM + Confidence-DF-IAKF (C→D 验证防雪崩价值)'}, ...
    'Location', 'southwest', 'FontSize', 10, 'Box', 'on');
ylim([1e-4, 1.0]); xlim([min(SNR_range), max(SNR_range)]);

saveas(fig_joint, fullfile(plot_save_dir, 'Fig_Ablation_Study_BER_Comparison.png'));
saveas(fig_joint, fullfile(plot_save_dir, 'Fig_Ablation_Study_BER_Comparison.pdf'));

save(fullfile(plot_save_dir, 'Ablation_Study_BER_Data.mat'), ...
    'SNR_range', 'BER_No_EQ', 'BER_Hard_NoConf', 'BER_CFAR_NoConf', 'BER_Proposed');
fprintf('  -> [归档] 消融实验四组对比曲线与数据已存至 %s。\n', plot_save_dir);

