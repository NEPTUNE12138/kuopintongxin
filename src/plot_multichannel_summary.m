% =========================================================================
% 出版级绘图脚本 (Publication-Quality Plotting Script)
% 目标图表: Fig 4 - Macroscopic Generalization (跨物理场泛化鲁棒性)
% 数据来源: ../results_plots/WUWNET/Summary_MultiChannel_Data.mat
% =========================================================================

clc; clear; close all;

% --- 1. 配置路径与加载数据 ---
currentFile = mfilename('fullpath');
[currentPath, ~, ~] = fileparts(currentFile);
data_path = fullfile(currentPath, '../results_plots/WUWNET/Summary_MultiChannel_Data.mat');
save_path = fullfile(currentPath, '../results_plots/WUWNET/fig4_multichannel_robustness.png');

if ~exist(data_path, 'file')
    error('错误: 找不到汇总数据文件 %s。请先运行主验证脚本。', data_path);
end

load(data_path, 'SNR_range', 'bellhop_channels', 'all_channel_BER_D');

num_channels = size(bellhop_channels, 1);

% --- 2. 出版级图表全局参数设置 ---
% 遵循严谨的学术制图规范，避免花哨的颜色，使用对比度高的学术色系
% 色系提取自标准的 Nature/Science 绘图建议
color_deepsea = [0.000, 0.447, 0.741]; % 深蓝 (适合深海)
color_shallow_flat = [0.850, 0.325, 0.098]; % 橙红 (适合浅海平坦)
color_shallow_slope = [0.466, 0.674, 0.188]; % 森林绿 (适合浅海起伏)
colors = {color_deepsea, color_shallow_flat, color_shallow_slope};
markers = {'o', 's', '^'};

% 字体设置
font_name = 'Times New Roman'; % 英文期刊标准字体
font_size_label = 14;
font_size_legend = 12;
font_size_title = 15;
font_size_tick = 12;

% --- 3. 绘制图表 ---
fig = figure('Name', 'Macroscopic Generalization', 'Position', [100, 100, 650, 500], 'Color', 'w');

hold on;
for ch_idx = 1:num_channels
    % 确保 BER 不低于 1e-6，防止 log scale 绘图出错
    ber_data = max(all_channel_BER_D(ch_idx, :), 1e-6);
    
    % 获取当前分配的颜色和标记
    c_color = colors{mod(ch_idx-1, length(colors))+1};
    m_marker = markers{mod(ch_idx-1, length(markers))+1};
    
    % 绘制线条
    plot(SNR_range, ber_data, ...
        'LineStyle', '-', ...
        'LineWidth', 2.0, ...
        'Color', c_color, ...
        'Marker', m_marker, ...
        'MarkerSize', 8, ...
        'MarkerEdgeColor', c_color, ...
        'MarkerFaceColor', 'w'); % 空心标记更具学术感
end

% 移除了 10^-3 目标性能虚线

% --- 4. 坐标轴与网格设置 ---
set(gca, 'YScale', 'log');
grid on;
set(gca, 'GridLineStyle', ':', 'GridAlpha', 0.6, 'MinorGridAlpha', 0.3);
set(gca, 'XMinorTick', 'on', 'YMinorTick', 'on');
set(gca, 'FontName', font_name, 'FontSize', font_size_tick, 'LineWidth', 1.0);
set(gca, 'TickDir', 'in');

xlim([min(SNR_range), max(SNR_range)]);
ylim([1e-4, 1]);

% --- 5. 标签与图例 ---
xlabel('Signal-to-Noise Ratio (dB)', 'FontName', font_name, 'FontSize', font_size_label, 'FontWeight', 'bold');
ylabel('Bit Error Rate', 'FontName', font_name, 'FontSize', font_size_label, 'FontWeight', 'bold');
title('System-Level Generalization across Physical Channels', 'FontName', font_name, 'FontSize', font_size_title, 'FontWeight', 'bold');

% 重构图例名称，去除中文，使用全英文学术描述
leg_strs = cell(1, num_channels);
for ch_idx = 1 : num_channels
    desc = bellhop_channels{ch_idx, 2};
    if contains(desc, '深海')
        leg_strs{ch_idx} = 'Deep-Sea (45 km, SOFAR)';
    elseif contains(desc, '平坦') || contains(desc, '34m')
        leg_strs{ch_idx} = 'Shallow-Water (20 km, Flat)';
    elseif contains(desc, '起伏') || contains(desc, '斜坡')
        leg_strs{ch_idx} = 'Shallow-Water (20 km, Slope)';
    else
        leg_strs{ch_idx} = desc; % Fallback
    end
end

% 配置图例
lgd = legend(leg_strs, 'Location', 'southwest', 'Interpreter', 'latex');
set(lgd, 'FontName', font_name, 'FontSize', font_size_legend, 'EdgeColor', 'none', 'Color', 'none');

% --- 6. 图像输出 ---
% 导出为高分辨率的 PNG 图片，直接按照论文所需的格式命名
exportgraphics(fig, save_path, 'Resolution', 600);
fprintf('出版级精修图像已保存至:\n%s\n', save_path);
