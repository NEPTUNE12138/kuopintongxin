%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 对比实验程序：极低信噪比与多普勒突变下瞬态收敛与追踪误差轨迹对比
%
% 【所属项目】：移动场景下的稳健扩频水声通信技术研究
% 【文件编号】：src/supplementary_Tracking_Error.m
% 【功能描述】：模拟单次极度恶劣海况 (-10 dB + 瞬态海浪推挽加速度峰值突变)，
%              对比传统固定噪声矩阵卡尔曼滤波 (Standard KF) 与本项目提出
%              的自适应协方差新息卡尔曼 (IAE-AKF) 在瞬态多普勒拉扯下的码片追踪误差。
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clc; clear; close all;

addpath(genpath('../lib'));
addpath(genpath('../data'));

fprintf('========================================================================\n');
fprintf('  瞬态收敛实验：Standard KF 与自适应 IAKF 时延追踪误差轨迹对比\n');
fprintf('========================================================================\n');

%% 1. 参数与发端准备
fs = 48e3; f0 = 5e3; fh = 7e3; fl = 3e3; N_pn = 24; 
load mseq.mat; mseq = mseq{2,1}; mseq(mseq==0) = -1; len_SS = length(mseq);
NumTotalSymbol = 502; 

load send_rand_data.mat; 
RandBinaryData_polar = sign(send_rand_data(1:15000) - 0.5); 
RandBinaryData_polar(RandBinaryData_polar == 0) = 1; 
dc = zeros(1, 15001); dc(1) = 1;
for n = 1:15000, dc(n+1) = RandBinaryData_polar(n) * dc(n); end 
BinaryData1 = dc(1 : NumTotalSymbol-1); 
total_symbols_to_process = length(BinaryData1);

CodeSend = kron(BinaryData1, mseq);
SignalI1 = rectpulse(real(CodeSend), N_pn); SignalQ1 = rectpulse(imag(CodeSend), N_pn);
t_mod = (0:length(SignalI1)-1)/fs;
SignalAftMod = SignalI1 .* cos(2*pi*f0*t_mod) - SignalQ1 .* sin(2*pi*f0*t_mod);

[b_bp, a_bp] = butter(4, [fl-500, fh+500]/(fs/2));
[b_lp, a_lp] = butter(4, 2500/(fs/2));
SignalAftMod = filter(b_bp, a_bp, SignalAftMod);
SignalAftMod = SignalAftMod / max(abs(SignalAftMod));

pw = 0.5; SignalLfm = syncsig(pw, fl, fh, fs, 2, 2) * 0.8; 
SignalDelay = zeros(1, round(1.0 * fs)); 
SignalSend = [SignalDelay SignalLfm SignalDelay SignalAftMod SignalDelay];

%% 2. 构建多普勒重采样与带噪多途信道 (锁定 SNR = -10 dB)
c_sound = 1500; t_orig = (0:length(SignalSend)-1) / fs;
v_0 = 1.2; a_0 = 0.08; A_wave = 0.4; f_wave = 0.2; phi_rand = 2 * pi * rand(); 
v_turb = zeros(1, length(t_orig));
for i = 2:length(t_orig), v_turb(i) = 0.999 * v_turb(i-1) + 0.015 * randn(); end
v_inst = v_0 + a_0 .* t_orig + A_wave .* sin(2*pi*f_wave .* t_orig + phi_rand) + v_turb;
alpha_t = 1 + (v_inst / c_sound); 

t_resampled = cumtrapz(t_orig, alpha_t);
t_resampled = t_resampled - t_resampled(1); 
SignalSend_Doppler = interp1(t_orig, SignalSend, t_resampled, 'linear', 0);
SignalSend_Doppler(isnan(SignalSend_Doppler)) = 0; 

max_delay_seconds = 0.650; h_uwa = zeros(1, round(max_delay_seconds * fs));
h_uwa(1) = 0.8; h_uwa(round(0.615*fs)) = 0.2; h_uwa(round(0.630*fs)) = 0.1; 
h_uwa = filter([1, 0.6, 0.3, 0.1, -0.1, -0.05], 1, h_uwa);
h_uwa = h_uwa / norm(h_uwa); 
signal_channel = filter(h_uwa, 1, SignalSend_Doppler);
mseq_ref = rectpulse(mseq, N_pn);

single_SNR = -10;
noise_trans = randn(1, length(signal_channel));
NoiseFilt_trans = filter(b_bp, a_bp, noise_trans);
scale_noise_trans = sqrt(var(signal_channel) / (10^(single_SNR/10)) / var(NoiseFilt_trans));
SignalRe_trans = signal_channel + NoiseFilt_trans * scale_noise_trans;
SignalAftBP_trans = filter(b_bp, a_bp, SignalRe_trans);

%% 3. 前导码同步捕获与下采样
IfftSignal_trans = corr_fun(SignalAftBP_trans(1:round(fs*3.0)), SignalLfm); 
[max_sync_val_t, ~] = max(abs(IfftSignal_trans));
valid_sync_idx_t = find(abs(IfftSignal_trans) > 0.25 * max_sync_val_t);
first_cross_idx_t = valid_sync_idx_t(1); 
search_end_t = min(first_cross_idx_t + 1000, length(IfftSignal_trans));
[~, local_max_t] = max(abs(IfftSignal_trans(first_cross_idx_t : search_end_t)));
PeakPoint_t = first_cross_idx_t + local_max_t - 1; 

start_cut_t = PeakPoint_t + length(SignalDelay) - 800;
if start_cut_t < 1, start_cut_t = 1; end
SignalIntercept_t = SignalAftBP_trans(start_cut_t : end); 
t_rx_t = (0:length(SignalIntercept_t)-1)/fs;
sig_bb_t = filter(b_lp, a_lp, 2 * SignalIntercept_t .* exp(-1j*2*pi*f0*t_rx_t));

base_ptr_t = 801; search_range_t = -200:200; energies_t = zeros(size(search_range_t));
for i = 1:length(search_range_t)
    idx = base_ptr_t + search_range_t(i); 
    if (idx < 1) || (idx + 5*len_SS*N_pn > length(sig_bb_t)), continue; end
    energy_sum = 0;
    for sym = 0:4
        test_seg = sig_bb_t(idx + sym*len_SS*N_pn : idx + (sym+1)*len_SS*N_pn - 1);
        energy_sum = energy_sum + abs(sum(test_seg .* mseq_ref))^2;
    end
    energies_t(i) = energy_sum;
end
[~, max_idx_t] = max(energies_t);
init_ptr_t = base_ptr_t + search_range_t(max_idx_t); 

%% 4. 并行双核对比：Standard KF vs Proposed IAE-AKF
% --- 滤波器 A: Standard KF (固化噪声阵列) ---
X_std = [0; 0]; P_std = eye(2); Q_std = [0.005 0; 0 0.0002]; R_std = 0.1;
ptr_std = init_ptr_t; err_std_history = zeros(1, total_symbols_to_process);

% --- 滤波器 B: Proposed IAE-AKF (结构自适应与正则化) ---
X_iaf = [0; 0]; P_iaf = eye(2); Q_iaf = [0.05 0; 0 0.002]; R_iaf = 0.1;
ptr_iaf = init_ptr_t; innov_buffer_iaf = zeros(1, 15); innov_idx_iaf = 1;
err_iaf_history = zeros(1, total_symbols_to_process);

F_mat = [1 1; 0 1]; H_mat = [1 0]; delta = 6;

for k = 1 : total_symbols_to_process
    % === Standard KF ===
    X_pre_std = F_mat * X_std; phase_off_std = round(X_pre_std(1)); 
    idx_std = ptr_std + phase_off_std;
    if (idx_std - delta > 0) && (idx_std + len_SS*N_pn + delta <= length(sig_bb_t))
        seg_E_std = sig_bb_t(idx_std - delta : idx_std + len_SS*N_pn - 1 - delta);
        seg_L_std = sig_bb_t(idx_std + delta : idx_std + len_SS*N_pn - 1 + delta);
        E_pwr_std = abs(sum(seg_E_std .* mseq_ref))^2; L_pwr_std = abs(sum(seg_L_std .* mseq_ref))^2;
        Zn_std = (L_pwr_std - E_pwr_std) / (E_pwr_std + L_pwr_std + 1e-9);
        if abs(Zn_std) < 0.15, Zn_std = 0; end 
        innov_std = Zn_std * delta;
        
        P_pre_std = F_mat * P_std * F_mat' + Q_std;
        K_gain_std = P_pre_std * H_mat' / (H_mat * P_pre_std * H_mat' + R_std);
        X_std = X_pre_std + K_gain_std * innov_std;
        P_std = (eye(2) - K_gain_std * H_mat) * P_pre_std;
        ptr_std = ptr_std + len_SS * N_pn;
        err_std_history(k) = innov_std; 
    end
    
    % === Proposed IAE-AKF ===
    X_pre_iaf = F_mat * X_iaf; phase_off_iaf = round(X_pre_iaf(1)); 
    idx_iaf = ptr_iaf + phase_off_iaf;
    if (idx_iaf - delta > 0) && (idx_iaf + len_SS*N_pn + delta <= length(sig_bb_t))
        seg_E_iaf = sig_bb_t(idx_iaf - delta : idx_iaf + len_SS*N_pn - 1 - delta);
        seg_L_iaf = sig_bb_t(idx_iaf + delta : idx_iaf + len_SS*N_pn - 1 + delta);
        E_pwr_iaf = abs(sum(seg_E_iaf .* mseq_ref))^2; L_pwr_iaf = abs(sum(seg_L_iaf .* mseq_ref))^2;
        Zn_iaf = (L_pwr_iaf - E_pwr_iaf) / (E_pwr_iaf + L_pwr_iaf + 1e-9);
        if abs(Zn_iaf) < 0.15, Zn_iaf = 0; end 
        innov_iaf = Zn_iaf * delta;
        
        innov_buffer_iaf(innov_idx_iaf) = innov_iaf;
        innov_idx_iaf = mod(innov_idx_iaf, 15) + 1;
        if k > 15
            C_k = var(innov_buffer_iaf) + 1e-6; 
            R_est = C_k - H_mat * (F_mat * P_iaf * F_mat' + Q_iaf) * H_mat';
            R_iaf = max(0.01, 0.8 * R_iaf + 0.2 * R_est); 
            K_temp = P_iaf * H_mat' / (H_mat * P_iaf * H_mat' + R_iaf); 
            Q_est = K_temp * C_k * K_temp';
            Q_est = diag(diag(Q_est)); 
            Q_iaf = max(1e-4, 0.9 * Q_iaf + 0.1 * Q_est); 
        end
        
        P_pre_iaf = F_mat * P_iaf * F_mat' + Q_iaf;
        K_gain_iaf = P_pre_iaf * H_mat' / (H_mat * P_pre_iaf * H_mat' + R_iaf);
        X_iaf = X_pre_iaf + K_gain_iaf * innov_iaf;
        P_iaf = (eye(2) - K_gain_iaf * H_mat) * P_pre_iaf;
        ptr_iaf = ptr_iaf + len_SS * N_pn;
        err_iaf_history(k) = innov_iaf; 
    end
end

%% 5. 绘制跟踪误差曲线与多普勒加速度突变点对齐分析
window_size = 8;
smooth_err_std = movmean(abs(err_std_history), window_size);
smooth_err_iaf = movmean(abs(err_iaf_history), window_size);
time_axis = (1:total_symbols_to_process) * (len_SS * N_pn / fs); 

fig_handle3 = figure('Name', '瞬态收敛与动态跟踪误差轨迹', 'Position', [120, 120, 800, 480]);
plot(time_axis, smooth_err_std, 'k-.', 'LineWidth', 1.8); hold on;
plot(time_axis, smooth_err_iaf, 'r-', 'LineWidth', 2.2);

x_peaks = [1.25, 3.75, 6.25, 8.75];
for p = 1:length(x_peaks)
    if x_peaks(p) < max(time_axis)
        xline(x_peaks(p), 'b:', 'LineWidth', 1.5, 'HandleVisibility', 'off');
    end
end
text(1.35, max(smooth_err_std)*0.85, '\leftarrow 海浪加速度峰值 (多普勒突变点)', 'Color', 'b', 'FontSize', 11, 'FontWeight', 'bold');

grid on;
title('极低信噪比 (-10 dB) 瞬态多普勒追踪误差轨迹对齐评估', 'FontSize', 13, 'FontWeight', 'bold');
xlabel('观测时间 (s)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('绝对时延追踪误差幅值 (Chips)', 'FontSize', 12, 'FontWeight', 'bold');
legend('Standard KF (传统卡尔曼：高多普勒滞后/发散)', 'Proposed IAKF (自适应新息卡尔曼：快速收敛牢固锁定)', 'Location', 'northeast', 'FontSize', 11);
set(gca, 'FontSize', 11);
ylim([0, max(smooth_err_std)*1.1]); xlim([0 max(time_axis)]);

if ~exist('../results', 'dir'), mkdir('../results'); end
saveas(fig_handle3, '../results/Tracking_Error_Comparison.png');
save('../results/Tracking_Error_Data.mat', 'time_axis', 'smooth_err_std', 'smooth_err_iaf');
fprintf('瞬态追踪误差实验图表完成并存储于 results/。\n');
