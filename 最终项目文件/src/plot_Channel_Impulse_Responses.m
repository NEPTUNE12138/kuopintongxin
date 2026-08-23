%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% 辅助绘图程序：绘制并对比三种水声信道模型的冲激响应 (CIR)
% 【所属项目】：移动场景下的稳健扩频水声通信技术研究
% 【文件编号】：src/plot_Channel_Impulse_Responses.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clc; clear; close all;

fs = 48e3; % 采样率

%% 1. 构建三种信道冲激响应 (CIR)

% (1) AWGN 信道 (理想单径)
h_awgn = zeros(1, round(0.1 * fs)); 
h_awgn(1) = 1.0;
t_awgn = (0:length(h_awgn)-1) / fs * 1000; % 转换为毫秒

% (2) 浅水多径信道 (Shallow Water - 密集且时延短, 高 ISI)
h_shallow = zeros(1, round(0.1 * fs));
h_shallow(1) = 1.0;
h_shallow(round(0.015 * fs)) = 0.6;
h_shallow(round(0.025 * fs)) = 0.4;
h_shallow(round(0.040 * fs)) = 0.2;
h_shallow = filter([1, 0.4, 0.2, 0.1], 1, h_shallow);
h_shallow = h_shallow / norm(h_shallow);
t_shallow = (0:length(h_shallow)-1) / fs * 1000;

% (3) 深水多径信道 (Deep Water - 稀疏且时延大)
h_deep = zeros(1, round(0.650 * fs));
h_deep(1) = 0.8;
h_deep(round(0.615 * fs)) = 0.2;
h_deep(round(0.630 * fs)) = 0.1;
h_deep = filter([1, 0.6, 0.3, 0.1, -0.1, -0.05], 1, h_deep);
h_deep = h_deep / norm(h_deep);
t_deep = (0:length(h_deep)-1) / fs * 1000;

%% 2. 绘制 CIR 对比图
figure('Name', '多场景水声信道冲激响应对比', 'Color', 'w', 'Position', [100 100 900 600]);

% AWGN
subplot(3, 1, 1);
stem(t_awgn, h_awgn, 'b', 'Marker', 'none', 'LineWidth', 1.5);
title('1. 理想 AWGN 信道冲激响应 (无多径)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('幅度', 'FontSize', 11);
grid on;
xlim([0 100]);
ylim([0 1.2]);

% 浅水
subplot(3, 1, 2);
stem(t_shallow, h_shallow, 'r', 'Marker', 'none', 'LineWidth', 1.5);
title('2. 典型浅水多径信道冲激响应 (时延扩展短、密集)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('幅度', 'FontSize', 11);
grid on;
xlim([0 100]);
ylim([-0.5 1.0]);

% 深水
subplot(3, 1, 3);
stem(t_deep, h_deep, 'k', 'Marker', 'none', 'LineWidth', 1.5);
title('3. 典型深水多径信道冲激响应 (时延扩展大、稀疏)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('时间时延 (ms)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('幅度', 'FontSize', 11);
grid on;
xlim([0 650]);
ylim([-0.4 1.0]);

sgtitle('三大测试水声信道时域冲激响应 (CIR) 对比', 'FontSize', 15, 'FontWeight', 'bold');

% 保存图表
if ~exist('../results_plots', 'dir')
    mkdir('../results_plots');
end
saveas(gcf, '../results_plots/Fig6_Channel_Impulse_Responses.png');
fprintf('信道冲激响应对比图已保存至 results_plots/Fig6_Channel_Impulse_Responses.png\n');
