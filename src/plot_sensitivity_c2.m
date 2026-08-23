% plot_sensitivity_c2.m
% 敏感度分析: 探讨不同的 c2 值在不同多普勒抖动率下的边界收敛性
clear; clc; close all;
addpath('../lib');

% === 1. 基本参数 ===
fs = 48000;
fc = 5000;
fb = 1000; % 符号率
len_SS = 127; % 扩频码长
N_pn = fs / fb;
symbol_time = len_SS * N_pn / fs; % 每个扩频符号的持续时间
total_symbols = 200; % 增加符号数以更好地观察收敛性

% === 2. 仿真设置 ===
c2_candidates = [1/200, 1/150, 1/100, 1/80, 1/60, 1/50, 1/40, 1/30, 1/20, 1/10];
jitter_rates = [0.1, 0.5, 1.0]; % 多普勒抖动率 (Hz/s)
num_mc = 20; % 蒙特卡洛次数

% 预生成发射基带信号
load('../../mseq.mat'); 
mseq = mseq{2,1}; 
mseq(mseq==0) = -1; 
len_SS = length(mseq);
mseq_ref = rectpulse(mseq, N_pn);
tx_data = ones(1, total_symbols);
tx_bb = zeros(1, total_symbols * len_SS * N_pn);
for k = 1:total_symbols
    for m = 1:len_SS
        tx_bb((k-1)*len_SS*N_pn + (m-1)*N_pn + 1 : (k-1)*len_SS*N_pn + m*N_pn) = tx_data(k) * mseq(m);
    end
end
tx_bb = tx_bb + 1i * tx_bb; % QPSK 样式

% 记录误差方差
rmse_results = zeros(length(jitter_rates), length(c2_candidates));

for j_idx = 1:length(jitter_rates)
    jitter_rate = jitter_rates(j_idx);
    fprintf('Simulating Jitter Rate: %.2f Hz/s\n', jitter_rate);
    
    for c_idx = 1:length(c2_candidates)
        assignin('base', 'c2_override', c2_candidates(c_idx));
        
        err_mc = zeros(1, num_mc);
        for mc = 1:num_mc
            % 构造时变信道：人为制造一次深衰落 (Deep Fade)
            t_axis = (0:length(tx_bb)-1) / fs;
            fade_envelope = ones(size(t_axis));
            fade_start = round(0.4 * length(tx_bb));
            fade_end = round(0.6 * length(tx_bb));
            fade_envelope(fade_start:fade_end) = 0.05; % 深衰落至 5%
            
            % 引入多普勒和随机抖动
            phase_drift = cumsum(2 * pi * (0.5 * jitter_rate * t_axis) .* t_axis);
            
            % 添加噪声 (-8 dB SNR)
            snr = -8;
            rx_bb = tx_bb .* fade_envelope .* exp(1i * phase_drift);
            rx_bb = awgn(rx_bb, snr, 'measured');
            
            % 运行 HVB-AKF 跟踪
            current_ptr = 1;
            delta = 2;
            [~, k_actual, err_history, ~, ~] = vb_iakf_pll(rx_bb, mseq_ref, current_ptr, total_symbols, len_SS, N_pn, delta, 1);
            
            % 计算深衰落期间及之后的追踪误差方差 (RMSE)
            fade_sym_start = floor(0.4 * total_symbols);
            if k_actual > fade_sym_start
                err_mc(mc) = sqrt(mean(err_history(fade_sym_start:end).^2));
            else
                err_mc(mc) = 1.0; % 发散惩罚
            end
        end
        rmse_results(j_idx, c_idx) = mean(err_mc);
    end
end

% === 3. 绘图 ===
figure('Position', [100, 100, 600, 450]);
hold on; grid on;

colors = {'#0072BD', '#D95319', '#EDB120'};
markers = {'-o', '-s', '-^'};
for j_idx = 1:length(jitter_rates)
    plot(c2_candidates, rmse_results(j_idx, :), markers{j_idx}, 'LineWidth', 2, 'MarkerSize', 8, 'Color', colors{j_idx});
end

% 标记 c2 = 1/50 的位置
xline(1/50, '--r', 'Chosen Value (c_2 = 1/50)', 'LineWidth', 2, 'LabelOrientation', 'horizontal', 'LabelHorizontalAlignment', 'center', 'LabelVerticalAlignment', 'bottom');

set(gca, 'XDir', 'reverse'); % 翻转X轴，因为 c2 越小惩罚越大
xlabel('Penalty Ceiling Hyperparameter (c_2)');
ylabel('Tracking Error RMSE (Chips)');
title('Sensitivity Analysis of Heteroscedastic Penalty under Fading');
legend('Low Jitter (0.1 Hz/s)', 'Medium Jitter (0.5 Hz/s)', 'High Jitter (1.0 Hz/s)', 'Location', 'northwest');
set(gca, 'FontSize', 12, 'FontName', 'Times New Roman');
xlim([min(c2_candidates), max(c2_candidates)]);
ylim([0, max(rmse_results(:)) * 1.2]);

% 保存图片
if ~exist('../results_plots/WUWNET/publication_figures', 'dir')
    mkdir('../results_plots/WUWNET/publication_figures');
end
saveas(gcf, '../results_plots/WUWNET/publication_figures/Fig_Sensitivity_c2.png');
disp('Sensitivity plot saved as Fig_Sensitivity_c2.png');
