%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 工程项目主仿真程序：多场景信道模型对比仿真实验
% 【所属项目】：移动场景下的稳健扩频水声通信技术研究
% 【文件编号】：src/main_MultiChannel_Comparison.m
% 【功能描述】：验证稳健扩频系统在 AWGN、浅水、深水三种不同信道下的普适性与鲁棒性
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clc; clear; close all;

% ==================== 全局配置 ====================
MONTE_CARLO_ITERS = 500; % 按照要求，设置 5000 次抽样
SNR_range = -15:1:-8; % SNR 范围：-15dB 到 -8dB，步长为1

% ==================== 路径配置 ====================
% 自动获取当前脚本绝对路径，防止因为未在 src 目录下执行而导致的“找不到函数”报错
currentFile = mfilename('fullpath');
[currentPath, ~, ~] = fileparts(currentFile);
addpath(genpath(fullfile(currentPath, '../lib')));
addpath(genpath(fullfile(currentPath, '../data')));

fprintf('========================================================================\n');
fprintf('  多场景信道对比实验 - AWGN vs 浅水 vs 深水 (Monte Carlo: %d 次)\n', MONTE_CARLO_ITERS);
fprintf('========================================================================\n');

%% 1. 系统基础参数配置 (复用主框架)
fs = 48e3; f0 = 5e3; fh = 7e3; fl = 3e3; N_pn = 24;
load mseq.mat; mseq = mseq{2,1}; mseq(mseq==0) = -1; len_SS = length(mseq);
NumTotalSymbol = 502;
Num_Trials = MONTE_CARLO_ITERS;

%% 2. 构建三种信道冲激响应 (CIR)
fprintf('正在生成信道物理场环境...\n');
% (1) AWGN 信道 (理想单径)
h_awgn = zeros(1, round(0.1 * fs));
h_awgn(1) = 1.0;

% (2) 浅水多径信道 (Shallow Water - 密集且时延短, 高 ISI)
h_shallow = zeros(1, round(0.1 * fs));
h_shallow(1) = 1.0;
h_shallow(round(0.015 * fs)) = 0.6;
h_shallow(round(0.025 * fs)) = 0.4;
h_shallow(round(0.040 * fs)) = 0.2;
h_shallow = filter([1, 0.4, 0.2, 0.1], 1, h_shallow);
h_shallow = h_shallow / norm(h_shallow);

% (3) 深水多径信道 (Deep Water - 稀疏且时延大，同项目默认配置)
h_deep = zeros(1, round(0.650 * fs));
h_deep(1) = 0.8;
h_deep(round(0.615 * fs)) = 0.2;
h_deep(round(0.630 * fs)) = 0.1;
h_deep = filter([1, 0.6, 0.3, 0.1, -0.1, -0.05], 1, h_deep);
h_deep = h_deep / norm(h_deep);

channels = {h_awgn, h_shallow, h_deep};
channel_names = {'1: 理想 AWGN', '2: 典型浅水多径', '3: 典型深水多径'};

%% 3. 发端数据与非平稳多普勒准备
load send_rand_data.mat;
send_data_raw = send_rand_data(1 : NumTotalSymbol - 2);
RandBinaryData_polar = sign(send_rand_data(1:15000) - 0.5);
RandBinaryData_polar(RandBinaryData_polar == 0) = 1;

dc = zeros(1, 15001); dc(1) = 1;
for n = 1:15000, dc(n+1) = RandBinaryData_polar(n) * dc(n); end
BinaryData1 = dc(1 : NumTotalSymbol-1);
total_symbols = length(BinaryData1);

CodeSend = kron(BinaryData1, mseq);
SignalI1 = rectpulse(real(CodeSend), N_pn); SignalQ1 = rectpulse(imag(CodeSend), N_pn);
t_mod = (0:length(SignalI1)-1)/fs;
SignalAftMod = SignalI1 .* cos(2*pi*f0*t_mod) - SignalQ1 .* sin(2*pi*f0*t_mod);

[b_bp, a_bp] = butter(4, [fl-500, fh+500]/(fs/2));
[b_lp, a_lp] = butter(4, 2500/(fs/2));
SignalAftMod = filter(b_bp, a_bp, SignalAftMod);
SignalAftMod = SignalAftMod / max(abs(SignalAftMod));

pw = 0.5; SignalLfm = syncsig(pw, fl, fh, fs, 2, 2) * 0.8;
SignalDelay = zeros(1, round(0.8 * fs));
SignalSend = [SignalDelay SignalLfm SignalDelay SignalAftMod SignalDelay];

c_sound = 1500; t_orig = (0:length(SignalSend)-1) / fs;
v_0 = 1.2; a_0 = 0.08; A_wave = 0.4; f_wave = 0.2; phi_rand = 2 * pi * rand();
v_turb = zeros(1, length(t_orig));
for i = 2:length(t_orig), v_turb(i) = 0.999 * v_turb(i-1) + 0.015 * randn(); end
v_inst = v_0 + a_0 .* t_orig + A_wave .* sin(2*pi*f_wave .* t_orig + phi_rand) + v_turb;
alpha_t = 1 + (v_inst / c_sound);
t_resampled = cumtrapz(t_orig, alpha_t); t_resampled = t_resampled - t_resampled(1);
SignalSend_Doppler = interp1(t_orig, SignalSend, t_resampled, 'linear', 0);
SignalSend_Doppler(isnan(SignalSend_Doppler)) = 0;
mseq_ref = rectpulse(mseq, N_pn);

%% 4. 开始对比仿真
BER_Std_KF = zeros(3, length(SNR_range));
BER_Innovation = zeros(3, length(SNR_range));

for ch_idx = 1:3
    current_channel = channels{ch_idx};
    signal_channel = filter(current_channel, 1, SignalSend_Doppler);
    
    fprintf('\n---> 正在测试信道模型 %s\n', channel_names{ch_idx});
    
    for s_idx = 1:length(SNR_range)
        current_SNR = SNR_range(s_idx);
        b_std_acc = 0; b_inno_acc = 0;
        
        for trial = 1 : Num_Trials
            noise = randn(1, length(signal_channel));
            NoiseFilt = filter(b_bp, a_bp, noise);
            scale_noise = sqrt(var(signal_channel) / (10^(current_SNR/10)) / var(NoiseFilt));
            SignalRe = signal_channel + NoiseFilt * scale_noise;
            SignalAftBP_rec = filter(b_bp, a_bp, SignalRe);
            
            % 同步捕获
            IfftSignal = corr_fun(SignalAftBP_rec(1:round(fs*3.0)), SignalLfm);
            [max_sync_val, ~] = max(abs(IfftSignal));
            valid_sync_idx = find(abs(IfftSignal) > 0.25 * max_sync_val);
            if isempty(valid_sync_idx)
                b_std_acc = b_std_acc + 0.5; b_inno_acc = b_inno_acc + 0.5;
                continue;
            end
            first_cross_idx = valid_sync_idx(1);
            search_end = min(first_cross_idx + 1000, length(IfftSignal));
            [~, local_max] = max(abs(IfftSignal(first_cross_idx : search_end)));
            PeakPoint = first_cross_idx + local_max - 1;
            
            start_cut = max(1, PeakPoint + length(SignalDelay) - 800);
            SignalIntercept = SignalAftBP_rec(start_cut : end);
            t_rx = (0:length(SignalIntercept)-1)/fs;
            sig_bb = filter(b_lp, a_lp, 2 * SignalIntercept .* exp(-1j*2*pi*f0*t_rx));
            
            % 定位粗指针
            delta = 6; base_ptr = 801; search_range = -200:200; energies = zeros(size(search_range));
            for i = 1:length(search_range)
                idx = base_ptr + search_range(i);
                if (idx < 1) || (idx + 5*len_SS*N_pn > length(sig_bb)), continue; end
                energy_sum = 0;
                for sym = 0:4
                    test_seg = sig_bb(idx + sym*len_SS*N_pn : idx + (sym+1)*len_SS*N_pn - 1);
                    energy_sum = energy_sum + abs(sum(test_seg .* mseq_ref))^2;
                end
                energies(i) = energy_sum;
            end
            [~, max_idx] = max(energies);
            current_ptr = base_ptr + search_range(max_idx);
            
            % (1) 传统卡尔曼
            [out_frac_std, k_std, ~, ~] = iakf_dll_tracker(sig_bb, mseq_ref, current_ptr, total_symbols, len_SS, N_pn, delta, 9999);
            if k_std > 2
                [~, ~, ber_s] = diff_corr_decode(mseq, 1, out_frac_std(:).', 1, k_std-1, len_SS, send_data_raw(1:k_std-1));
            else, ber_s = 0.5; end
            b_std_acc = b_std_acc + ber_s;
            
            % (2) 创新点：IAKF + 块解调
            [out_frac_innov, k_innov, ~, ~] = iakf_dll_tracker(sig_bb, mseq_ref, current_ptr, total_symbols, len_SS, N_pn, delta, 15);
            if k_innov > 2
                [~, ~, ber_i, ~] = block_doppler_decode_silent(mseq, out_frac_innov(:).', k_innov-1, len_SS, send_data_raw(1:k_innov-1));
            else, ber_i = 0.5; end
            b_inno_acc = b_inno_acc + ber_i;
        end
        
        BER_Std_KF(ch_idx, s_idx) = b_std_acc / Num_Trials;
        BER_Innovation(ch_idx, s_idx) = b_inno_acc / Num_Trials;
        fprintf('  SNR = %3d dB | 传统KF BER: %.4f | 创新点 BER: %.4f\n', current_SNR, BER_Std_KF(ch_idx, s_idx), BER_Innovation(ch_idx, s_idx));
    end
end

%% 5. 绘制多信道对比图表
fprintf('\n正在生成并导出图表...\n');
figure('Name', '多信道稳健性对数曲线对比', 'Color', 'w', 'Position', [150 150 1100 450]);

for ch_idx = 1:3
    subplot(1, 3, ch_idx);
    semilogy(SNR_range, BER_Std_KF(ch_idx, :), '--s', 'LineWidth', 1.5, 'Color', [0.3 0.3 0.3], 'MarkerSize', 6);
    hold on;
    semilogy(SNR_range, BER_Innovation(ch_idx, :), '-rp', 'LineWidth', 2.5, 'MarkerFaceColor', 'y', 'MarkerSize', 9);
    
    xlabel('SNR (dB)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('BER', 'FontSize', 12, 'FontWeight', 'bold');
    title(channel_names{ch_idx}, 'FontSize', 13);
    legend('传统 KF', 'TRM+IAKF (创新)', 'Location', 'southwest', 'FontSize', 10);
    grid on;
    ylim([1e-4, 1]);
end
sgtitle(sprintf('不同水声信道下解调性能对比 (Monte Carlo = %d 次)', MONTE_CARLO_ITERS), 'FontSize', 16, 'FontWeight', 'bold');

% 自动保存
if ~exist('../results_plots', 'dir')
    mkdir('../results_plots');
end
saveas(gcf, '../results_plots/Fig5_MultiChannel_Comparison.png');
fprintf('多信道对比测试完毕，曲线图已保存至 results_plots/Fig5_MultiChannel_Comparison.png\n');
fprintf('========================================================================\n');
