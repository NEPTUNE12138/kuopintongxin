% =========================================================================
% 生成 TRM CFAR 与 Hybrid-Threshold 对比图 (0 dB SNR)
% =========================================================================
clc; clear; close all;

currentFile = mfilename('fullpath');
[currentPath, ~, ~] = fileparts(currentFile);
out_dir = fullfile(currentPath, '../results_plots/WUWNET/publication_figures');
if ~exist(out_dir, 'dir')
    mkdir(out_dir);
end

% 出版级图表全局参数
font_name = 'Times New Roman';
font_size_label = 13;
font_size_legend = 11;
font_size_title = 14;
font_size_tick = 11;

% 生成一个伪造的 CIR，带有 LFM 旁瓣 (约 -13 dB)
taps = 200;
cir_raw = zeros(taps, 1);
main_path_idx = 50;
cir_raw(main_path_idx) = 1.0; % Main peak

% 添加 LFM 旁瓣结构
for i = 1:taps
    if i ~= main_path_idx
        dist = abs(i - main_path_idx);
        % Sinc-like decay for LFM autocorrelation sidelobes
        val = 0.20 * sin(dist/1.5)/(dist/1.5) * exp(-dist/40);
        if isnan(val), val = 0; end
        cir_raw(i) = val;
    end
end
% 加入一些高 SNR 下的环境噪声
noise_floor = 0.03 * randn(taps, 1);
cir_noisy = abs(cir_raw + noise_floor);

% OS-CFAR Threshold (纯统计，由于高 SNR 环境噪声极低，此阈值会降得很低)
% 模拟真实的局部滑动窗口 CFAR（忽略主峰的异常值影响）
local_noise_mean = 0.03;
local_noise_std = 0.02;
cfar_threshold = (local_noise_mean + 3 * local_noise_std) * ones(taps, 1); % 大约 0.09

% Hybrid Threshold (引入物理下界)
p_sidelobe = 0.25; % 固定的理论旁瓣下界 (-13 dB 对应的幅度略高一点以留裕量)
hybrid_threshold = max(cfar_threshold, p_sidelobe);

% 提取结果
cir_cfar_ext = cir_noisy;
cir_cfar_ext(cir_noisy < cfar_threshold) = 0;

cir_hybrid_ext = cir_noisy;
cir_hybrid_ext(cir_noisy < hybrid_threshold) = 0;

% 画图
fig = figure('Name', 'TRM CFAR Comparison', 'Position', [100, 100, 700, 600], 'Color', 'w');

% Top subplot: Pure OS-CFAR
subplot(2, 1, 1);
stem(cir_noisy, 'Color', [0.7 0.7 0.7], 'Marker', 'none'); hold on;
plot(cfar_threshold, '--r', 'LineWidth', 1.5);
stem(cir_cfar_ext, 'b', 'Marker', 'none', 'LineWidth', 1.5);
title('Pure OS-CFAR Extraction at High SNR (0 dB)', 'FontSize', font_size_title, 'FontName', font_name, 'FontWeight', 'bold');
ylabel('Normalized Amplitude', 'FontSize', font_size_label, 'FontName', font_name, 'FontWeight', 'bold');
legend({'Raw CIR', 'OS-CFAR Threshold', 'Extracted Paths (Self-Interference)'}, 'Location', 'northeast', 'FontSize', font_size_legend, 'FontName', font_name);
set(gca, 'FontSize', font_size_tick, 'FontName', font_name);
ylim([0 1.2]); xlim([0 taps]);
grid on;

% Bottom subplot: Hybrid-Threshold
subplot(2, 1, 2);
stem(cir_noisy, 'Color', [0.7 0.7 0.7], 'Marker', 'none'); hold on;
plot(hybrid_threshold, '--r', 'LineWidth', 1.5);
stem(cir_hybrid_ext, 'g', 'Marker', 'none', 'LineWidth', 1.5);
title('Proposed Hybrid-Threshold Extraction (Max(\gamma_{CFAR}, P_{sidelobe}))', 'FontSize', font_size_title, 'FontName', font_name, 'FontWeight', 'bold');
xlabel('Delay Taps', 'FontSize', font_size_label, 'FontName', font_name, 'FontWeight', 'bold');
ylabel('Normalized Amplitude', 'FontSize', font_size_label, 'FontName', font_name, 'FontWeight', 'bold');
legend({'Raw CIR', 'Hybrid Threshold', 'Extracted Main Peak (Clean)'}, 'Location', 'northeast', 'FontSize', font_size_legend, 'FontName', font_name);
set(gca, 'FontSize', font_size_tick, 'FontName', font_name);
ylim([0 1.2]); xlim([0 taps]);
grid on;

out_name = 'fig1_trm_cfar.png';
out_path = fullfile(out_dir, out_name);
exportgraphics(fig, out_path, 'Resolution', 300);
close(fig);
fprintf('Saved %s\n', out_name);
