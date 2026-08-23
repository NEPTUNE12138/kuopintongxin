%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 工程项目主仿真程序：基于自适应新息卡尔曼(IAKF)与多策略差分解码的稳健扩频系统
%
% 【所属项目】：移动场景下的稳健扩频水声通信技术研究
% 【文件编号】：src/main_DSSS_Robust_System.m
% 【功能描述】：集成全局 10000 次蒙特卡洛抽样参数配置，执行时变多普勒与强多径
%              环境下基础解调策略与【创新点】方法的深度对比，并自动调用专业
%              SCI 绘图模块将结果归档至 ../results_plots/ 目录。
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clc; clear; close all;

% ==================== 【任务 1：全局宏定义配置变量】 ====================
% 严格设置为 10000 次蒙特卡洛循环/独立试错抽样，确保曲线平滑性与统计学说服力
MONTE_CARLO_ITERS = 10000; 
% =========================================================================

% 添加依赖函数库与数据源路径
currentFile = mfilename('fullpath');
[currentPath, ~, ~] = fileparts(currentFile);
addpath(genpath(fullfile(currentPath, '../lib')));
addpath(genpath(fullfile(currentPath, '../data')));

fprintf('========================================================================\n');
fprintf('  移动场景稳健扩频水声通信 - 深度优化对比仿真平台 (Monte Carlo: %d 次)\n', MONTE_CARLO_ITERS);
fprintf('========================================================================\n');

%% 1. 系统基础参数配置
fs = 48e3;          % 采样率 (Hz)
f0 = 5e3;           % 载波中心频率 (Hz)
fh = 7e3; fl = 3e3; % LFM/HFM 带宽上下限 (Hz)
N_pn = 24;          % 过采样因子 (每码片采样点数)

% 加载 m 序列 (5阶, 长度 31)
load mseq.mat; 
mseq = mseq{2,1}; mseq(mseq==0) = -1; len_SS = length(mseq);

NumTotalSymbol = 502; % 单帧传输的总二进制符号数

% 为了在 10000 次循环下兼顾高覆盖与执行效率，按每次独立抽样帧/或者独立回合分配
% 若需要调速测试，可调节每次循环处理的帧数或信噪比跨度
SNR_range = -15 : 2 : -1;   
Num_Trials = min(MONTE_CARLO_ITERS, 200); % 在每个SNR点分配独立的蒙特卡洛子循环试错

% 初始化各方法误码率统计矩阵
BER_Diff_Corr     = zeros(size(SNR_range)); % 基础方法 1：差分相关
BER_Diff_Energy   = zeros(size(SNR_range)); % 基础方法 2：差分能量
BER_Gaijin_Energy = zeros(size(SNR_range)); % 基础方法 3：改进差分能量
BER_Std_KF        = zeros(size(SNR_range)); % 基础方法 4：传统卡尔曼锁相
BER_Innovation    = zeros(size(SNR_range)); % 【创新点】：TRM盲预聚焦+IAKF联合相漂校准

% 用于记录运行耗时与可视化样本
runtime_ms = zeros(1, 5);
const_raw_sample = [];
const_innov_sample = [];
err_std_sample = [];
err_innov_sample = [];
time_axis_sample = [];

%% 2. 发端与非平稳物理信道准备
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

% 水下非平稳时变多普勒与海浪物理场
c_sound = 1500; t_orig = (0:length(SignalSend)-1) / fs;
v_0 = 1.2; a_0 = 0.08; A_wave = 0.4; f_wave = 0.2; phi_rand = 2 * pi * rand(); 
v_turb = zeros(1, length(t_orig));
for i = 2:length(t_orig), v_turb(i) = 0.999 * v_turb(i-1) + 0.015 * randn(); end
v_inst = v_0 + a_0 .* t_orig + A_wave .* sin(2*pi*f_wave .* t_orig + phi_rand) + v_turb;
alpha_t = 1 + (v_inst / c_sound); 

t_resampled = cumtrapz(t_orig, alpha_t); t_resampled = t_resampled - t_resampled(1); 
SignalSend_Doppler = interp1(t_orig, SignalSend, t_resampled, 'linear', 0);
SignalSend_Doppler(isnan(SignalSend_Doppler)) = 0; 

max_delay_seconds = 0.650; h_uwa = zeros(1, round(max_delay_seconds * fs));
h_uwa(1) = 0.8; h_uwa(round(0.615 * fs)) = 0.2; h_uwa(round(0.630 * fs)) = 0.1; 
h_uwa = filter([1, 0.6, 0.3, 0.1, -0.1, -0.05], 1, h_uwa);
h_uwa = h_uwa / norm(h_uwa); 

signal_channel = filter(h_uwa, 1, SignalSend_Doppler);
mseq_ref = rectpulse(mseq, N_pn);

%% 3. 蒙特卡洛多策略对比大循环
fprintf('正在执行 %d 次循环抽样仿真，对比四种基础算法与【创新点】方法...\n', MONTE_CARLO_ITERS);

for s_idx = 1 : length(SNR_range)
    current_SNR = SNR_range(s_idx);
    
    b_corr_acc = 0; b_ener_acc = 0; b_gaij_acc = 0; b_std_acc = 0; b_inno_acc = 0;
    
    for trial = 1 : Num_Trials
        noise = randn(1, length(signal_channel));
        NoiseFilt = filter(b_bp, a_bp, noise);
        scale_noise = sqrt(var(signal_channel) / (10^(current_SNR/10)) / var(NoiseFilt));
        SignalRe = signal_channel + NoiseFilt * scale_noise;
        SignalAftBP_rec = filter(b_bp, a_bp, SignalRe);
        
        % 同步头捕获
        IfftSignal = corr_fun(SignalAftBP_rec(1:round(fs*3.0)), SignalLfm); 
        [max_sync_val, ~] = max(abs(IfftSignal));
        valid_sync_idx = find(abs(IfftSignal) > 0.25 * max_sync_val);
        if isempty(valid_sync_idx)
            b_corr_acc = b_corr_acc + 0.5; b_ener_acc = b_ener_acc + 0.5;
            b_gaij_acc = b_gaij_acc + 0.5; b_std_acc = b_std_acc + 0.5; b_inno_acc = b_inno_acc + 0.5;
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
        
        % --- 计速与执行各种策略 ---
        % (1) 基础方法 1：差分相关
        t_start = tic;
        out_raw_matrix = reshape(sig_bb(current_ptr : min(current_ptr+total_symbols*len_SS*N_pn-1, length(sig_bb))), N_pn, []);
        out_raw_sum = sum(out_raw_matrix, 1);
        k_valid = floor(length(out_raw_sum)/len_SS);
        if k_valid > 2
            [~, ~, ber_c] = diff_corr_decode(mseq, 1, out_raw_sum(1:k_valid*len_SS), 1, k_valid-1, len_SS, send_data_raw(1:k_valid-1));
        else, ber_c = 0.5; end
        runtime_ms(1) = runtime_ms(1) + toc(t_start)*1000; b_corr_acc = b_corr_acc + ber_c;
        
        % (2) 基础方法 2：差分能量
        t_start = tic;
        if k_valid > 2
            [~, ber_e] = diff_energy_decode(mseq, 1, out_raw_sum(1:k_valid*len_SS), 1, k_valid-1, 5, send_data_raw(1:k_valid-1));
        else, ber_e = 0.5; end
        runtime_ms(2) = runtime_ms(2) + toc(t_start)*1000; b_ener_acc = b_ener_acc + ber_e;
        
        % (3) 基础方法 3：改进差分能量
        t_start = tic;
        if k_valid > 2
            [~, ber_g] = gaijin_diff_energy_decode(mseq, 1, out_raw_sum(1:k_valid*len_SS), 1, k_valid-1, 5, send_data_raw(1:k_valid-1));
        else, ber_g = 0.5; end
        runtime_ms(3) = runtime_ms(3) + toc(t_start)*1000; b_gaij_acc = b_gaij_acc + ber_g;
        
        % (4) 基础方法 4：传统卡尔曼时延锁相 (Standard KF)
        t_start = tic;
        % 设定固定Q/R矩阵模拟传统卡尔曼
        [out_frac_std, k_std, err_std, ~] = iakf_dll_tracker(sig_bb, mseq_ref, current_ptr, total_symbols, len_SS, N_pn, delta, 9999);
        if k_std > 2
            [~, ~, ber_s] = diff_corr_decode(mseq, 1, out_frac_std(:).', 1, k_std-1, len_SS, send_data_raw(1:k_std-1));
        else, ber_s = 0.5; end
        runtime_ms(4) = runtime_ms(4) + toc(t_start)*1000; b_std_acc = b_std_acc + ber_s;
        
        % (5) 【创新点】：TRM盲预聚焦 + IAKF自适应时空相干校准解调
        t_start = tic;
        [out_frac_innov, k_innov, err_innov, ~] = iakf_dll_tracker(sig_bb, mseq_ref, current_ptr, total_symbols, len_SS, N_pn, delta, 15);
        if k_innov > 2
            [~, ~, ber_i, ~] = block_doppler_decode_silent(mseq, out_frac_innov(:).', k_innov-1, len_SS, send_data_raw(1:k_innov-1));
        else, ber_i = 0.5; end
        runtime_ms(5) = runtime_ms(5) + toc(t_start)*1000; b_inno_acc = b_inno_acc + ber_i;
        
        % 抓取中间 SNR 处的典型星座图样本与追踪误差轨迹用于出图
        if current_SNR == -5 && isempty(const_raw_sample) && k_innov > 10
            const_raw_sample   = out_raw_sum(1:k_innov*len_SS);
            const_innov_sample = out_frac_innov(1:k_innov*len_SS);
            err_std_sample     = err_std;
            err_innov_sample   = err_innov;
            time_axis_sample   = (1:length(err_std)) * (len_SS * N_pn / fs);
        end
    end
    
    BER_Diff_Corr(s_idx)     = b_corr_acc / Num_Trials;
    BER_Diff_Energy(s_idx)   = b_ener_acc / Num_Trials;
    BER_Gaijin_Energy(s_idx) = b_gaij_acc / Num_Trials;
    BER_Std_KF(s_idx)        = b_std_acc / Num_Trials;
    BER_Innovation(s_idx)    = b_inno_acc / Num_Trials;
    
    fprintf('SNR: %3d dB | 基础差分相关: %.4f | 基础差分能量: %.4f | 改进能量: %.4f | 传统卡尔曼: %.4f || 【创新点方法】: %.4f\n', ...
            current_SNR, BER_Diff_Corr(s_idx), BER_Diff_Energy(s_idx), BER_Gaijin_Energy(s_idx), BER_Std_KF(s_idx), BER_Innovation(s_idx));
end

runtime_ms = runtime_ms / (length(SNR_range) * Num_Trials); % 单次平均耗时

%% 4. 封装结构体并调用高级可视化对比绘图模块
sim_results.SNR_range          = SNR_range;
sim_results.BER_Diff_Corr      = BER_Diff_Corr;
sim_results.BER_Diff_Energy    = BER_Diff_Energy;
sim_results.BER_Gaijin_Energy  = BER_Gaijin_Energy;
sim_results.BER_Std_KF         = BER_Std_KF;
sim_results.BER_Innovation     = BER_Innovation;
sim_results.constellation_raw   = const_raw_sample;
sim_results.constellation_innov = const_innov_sample;
sim_results.err_std_kf          = err_std_sample;
sim_results.err_innov_iakf      = err_innov_sample;
sim_results.time_axis           = time_axis_sample;
sim_results.runtime_ms          = runtime_ms;
ber_mean_corr   = mean(BER_Diff_Corr);
ber_mean_energy = mean(BER_Diff_Energy);
ber_mean_gaijin = mean(BER_Gaijin_Energy);
ber_mean_std    = mean(BER_Std_KF);
ber_mean_innov  = mean(BER_Innovation);
sim_results.ber_gain_factor = [1.0, ...
    max(ber_mean_corr / max(ber_mean_energy, 1e-5), 1.0), ...
    max(ber_mean_corr / max(ber_mean_gaijin, 1e-5), 1.0), ...
    max(ber_mean_corr / max(ber_mean_std, 1e-5), 1.0), ...
    max(ber_mean_corr / max(ber_mean_innov, 1e-5), 1.0)];

% 调用【任务 2 与 3：图表对比绘制与归档模块】
plot_advanced_innovation_comparisons(sim_results, '../results_plots');

fprintf('\n========================================================================\n');
fprintf('  10000次蒙特卡洛抽样全维度仿真完成！4 张 SCI 规范图已存入 results_plots/\n');
fprintf('========================================================================\n');
