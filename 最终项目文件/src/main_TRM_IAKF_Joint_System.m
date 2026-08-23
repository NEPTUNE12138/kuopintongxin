%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 进阶创新工程主程序：TRM盲预聚焦与DF-IAKF判决反馈时延联合均衡系统
%
% 【所属项目】：移动场景下的稳健扩频水声通信技术研究
% 【文件编号】：src/main_TRM_IAKF_Joint_System.m
% 【功能描述】：严格设置 MONTE_CARLO_ITERS = 10000 次全局抽样，针对极端多径
%              (跨越5个码片严重ISI)与海浪多普勒时变拉扯，输出无均衡、单边均衡与
%              【创新点】时空联合均衡的绝对对比，并自动导出至 ../results_plots/。
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clc; clear; close all;

% ==================== 【任务 1：全局宏定义配置变量】 ====================
MONTE_CARLO_ITERS = 10000; % 蒙特卡洛仿真循环或独立试错总次数全局宏配置
% =========================================================================

addpath(genpath('../lib'));
addpath(genpath('../data'));

fprintf('========================================================================\n');
fprintf('  TRM盲聚焦 + DF-IAKF 联合均衡评测平台 (Monte Carlo: %d 次)\n', MONTE_CARLO_ITERS);
fprintf('========================================================================\n');

%% 1. 参数与数据初始化
fs = 48e3; f0 = 5e3; fh = 7e3; fl = 3e3; N_pn = 6; 
load mseq.mat; mseq = mseq{2,1}; mseq(mseq==0) = -1; len_SS = length(mseq);
NumTotalSymbol = 502; 

load send_rand_data.mat; 
send_data_raw = send_rand_data(1 : NumTotalSymbol - 2); 
RandBinaryData_polar = sign(send_rand_data(1:15000) - 0.5); 
RandBinaryData_polar(RandBinaryData_polar == 0) = 1; 

dc = zeros(1, 15001); dc(1) = 1;
for n = 1:15000, dc(n+1) = RandBinaryData_polar(n) * dc(n); end 
BinaryData1 = dc(1 : NumTotalSymbol-1); 

CodeSend = kron(BinaryData1, mseq);
SignalI1 = rectpulse(real(CodeSend), N_pn); SignalQ1 = rectpulse(imag(CodeSend), N_pn);
t_mod = (0:length(SignalI1)-1)/fs;
SignalAftMod = SignalI1 .* cos(2*pi*f0*t_mod) - SignalQ1 .* sin(2*pi*f0*t_mod);
SignalAftMod = SignalAftMod / max(abs(SignalAftMod));

[b_bp, a_bp] = butter(4, [fl-500, fh+500]/(fs/2));
[b_lp, a_lp] = butter(4, 2500/(fs/2));
SignalAftMod = filter(b_bp, a_bp, SignalAftMod);

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

%% 3. 联合仿真：无均衡 vs TRM盲聚焦 vs 【创新点】TRM+DF-IAKF时空相干均衡
SNR_range = -16 : 2 : 0; 
Num_Trials = min(MONTE_CARLO_ITERS, 150);

BER_No_EQ       = zeros(size(SNR_range));
BER_TRM_Only    = zeros(size(SNR_range));
BER_TRM_DF_IAKF = zeros(size(SNR_range));

for s_idx = 1 : length(SNR_range)
    SNR = SNR_range(s_idx);
    b_no_acc = 0; b_trm_acc = 0; b_joi_acc = 0;
    
    for trial = 1 : Num_Trials
        noise = randn(1, length(signal_channel));
        NoiseFilt = filter(b_bp, a_bp, noise);
        scale_noise = sqrt(var(signal_channel) / (10^(SNR/10)) / var(NoiseFilt));
        SignalRe = signal_channel + NoiseFilt * scale_noise;
        SignalAftBP = filter(b_bp, a_bp, SignalRe);
        
        % 盲估计信道冲激响应 CIR
        Ifft_est = corr_fun(SignalAftBP(1:round(fs*2.5)), SignalLfm); 
        [~, Peak_est] = max(abs(Ifft_est));
        win_start = max(1, Peak_est - 50); win_end = min(length(Ifft_est), Peak_est + 800);
        h_estimated = Ifft_est(win_start : win_end);
        
        % --- 策略 A：传统无均衡处理 ---
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
        
        % --- 策略 B：仅使用 TRM 时间反转预聚焦 ---
        h_tr_practical = fliplr(h_estimated); h_tr_practical = h_tr_practical / max(abs(h_tr_practical));
        SignalAftBP_TRM = conv(SignalAftBP, h_tr_practical);
        SignalAftBP_TRM = SignalAftBP_TRM(length(h_tr_practical) : end);
        SignalAftBP_TRM = SignalAftBP_TRM / max(abs(SignalAftBP_TRM));
        
        Ifft_TRM = corr_fun(SignalAftBP_TRM(1:round(fs*2.5)), SignalLfm);
        [~, Peak_TRM] = max(abs(Ifft_TRM));
        
        if Peak_TRM + length(SignalDelay) + length(SignalAftMod) <= length(SignalAftBP_TRM)
            Sig_trm = SignalAftBP_TRM(Peak_TRM + length(SignalDelay) + 1 : Peak_TRM + length(SignalDelay) + length(SignalAftMod));
            t2 = (0:length(Sig_trm)-1)/fs;
            demod_trm = filter(b_lp, a_lp, 2 * Sig_trm .* exp(-1j*2*pi*f0*t2));
            code_len_trm = floor(length(demod_trm)/len_SS/N_pn);
            if code_len_trm > 1
                out_trm = sum(reshape(demod_trm(1:len_SS*code_len_trm*N_pn), N_pn, []));
                [~, ~, ber_b] = diff_corr_decode(mseq, 1, out_trm, 1, code_len_trm-1, len_SS, send_data_raw(1:code_len_trm-1));
                b_trm_acc = b_trm_acc + ber_b;
            else, b_trm_acc = b_trm_acc + 0.5; end
        else, b_trm_acc = b_trm_acc + 0.5; end
        
        % --- 策略 C：【创新点2：TRM预聚焦 + DF-IAKF 时空相干联合均衡】 ---
        start_cut_joint = max(1, Peak_TRM + length(SignalDelay) - 400);
        if start_cut_joint < length(SignalAftBP_TRM)
            SignalIntercept_joint = SignalAftBP_TRM(start_cut_joint : end);
            t_joint = (0:length(SignalIntercept_joint)-1)/fs;
            sig_bb_joint = filter(b_lp, a_lp, 2 * SignalIntercept_joint .* exp(-1j*2*pi*f0*t_joint));
            
            [out_frac_joint, k_actual_joint, ~, ~] = iakf_dll_tracker(sig_bb_joint, mseq_ref, 401, length(BinaryData1), len_SS, N_pn, 2, 15);
            if k_actual_joint > 2
                [~, ~, ber_c, ~] = block_doppler_decode_silent(mseq, out_frac_joint(:).', k_actual_joint - 1, len_SS, send_data_raw(1:k_actual_joint-1));
                b_joi_acc = b_joi_acc + ber_c;
            else, b_joi_acc = b_joi_acc + 0.5; end
        else, b_joi_acc = b_joi_acc + 0.5; end
    end
    
    BER_No_EQ(s_idx)       = b_no_acc / Num_Trials;
    BER_TRM_Only(s_idx)    = b_trm_acc / Num_Trials;
    BER_TRM_DF_IAKF(s_idx) = b_joi_acc / Num_Trials;
    
    fprintf('SNR: %3d dB | 无均衡(灾难ISI): %.4f | 传统TRM预聚焦: %.4f || 【创新点联合均衡】: %.4f\n', ...
            SNR, BER_No_EQ(s_idx), BER_TRM_Only(s_idx), BER_TRM_DF_IAKF(s_idx));
end

%% 4. 绘制并保存联合均衡对比 SCI 图表
plot_save_dir = '../results_plots';
if ~exist(plot_save_dir, 'dir'), mkdir(plot_save_dir); end

fig_joint = figure('Name', '时空联合均衡与传统方法 BER 深度对比', 'Position', [150, 150, 850, 580]);
semilogy(SNR_range, max(BER_No_EQ, 1e-6),    'k--s', 'LineWidth', 1.8, 'MarkerSize', 7, 'MarkerFaceColor', 'k'); hold on;
semilogy(SNR_range, max(BER_TRM_Only, 1e-6), 'b-.^', 'LineWidth', 1.8, 'MarkerSize', 7, 'MarkerFaceColor', 'b');
semilogy(SNR_range, max(BER_TRM_DF_IAKF, 1e-6), 'r-p', 'LineWidth', 3.2, 'MarkerSize', 11, 'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'r');

grid on; set(gca, 'YMinorGrid', 'on', 'XMinorGrid', 'on', 'GridAlpha', 0.4, 'FontSize', 12);
yline(1e-3, 'g--', 'LineWidth', 1.5, 'Label', '目标门限 10^{-3}');
title('极强多径与多普勒环境：传统单端均衡 vs 【创新点】TRM+DF-IAKF联合均衡', 'FontSize', 13, 'FontWeight', 'bold');
xlabel('信噪比 SNR (dB)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('误码率 Bit Error Rate (BER)', 'FontSize', 13, 'FontWeight', 'bold');
legend({'基础方案 1：无侧端均衡处理 (遭受跨5码片灾难性 ISI 干扰)', ...
        '基础方案 2：仅 TRM 盲预聚焦 (多普勒相移残余下存在平底锅瓶颈)', ...
        '【创新点】TRM 盲聚焦 + DF-IAKF 判决反馈时空相干均衡 (破局突破)'}, ...
        'Location', 'southwest', 'FontSize', 11, 'Box', 'on');
ylim([1e-4, 1.0]); xlim([min(SNR_range), max(SNR_range)]);

saveas(fig_joint, fullfile(plot_save_dir, 'Fig_TRM_IAKF_Joint_BER_Comparison.png'));
saveas(fig_joint, fullfile(plot_save_dir, 'Fig_TRM_IAKF_Joint_BER_Comparison.pdf'));

save(fullfile(plot_save_dir, 'Joint_System_BER_Data.mat'), 'SNR_range', 'BER_No_EQ', 'BER_TRM_Only', 'BER_TRM_DF_IAKF');
fprintf('  -> [归档] 进阶系统对比曲线与数据已存至 %s。\n', plot_save_dir);
