% =========================================================================
% 生成所有三个信道的独立精修 BER 对比图
% =========================================================================
clc; clear; close all;

currentFile = mfilename('fullpath');
[currentPath, ~, ~] = fileparts(currentFile);
base_dir = fullfile(currentPath, '../results_plots/WUWNET');

% 3 个信道的子文件夹名称及论文中的规范命名
channels = {
    'channel_100m_45km_110m', 'Deep-Sea (45 km, SOFAR)';
    'channel_15m_20km_34m',   'Shallow-Water (20 km, Flat)';
    'channel_15m_20km_3467m', 'Shallow-Water (20 km, Slope)'
};

% 出版级图表全局参数
font_name = 'Times New Roman';
font_size_label = 13;
font_size_legend = 11;
font_size_title = 14;
font_size_tick = 11;
line_width_thick = 2.5;
line_width_thin = 1.5;

% 高级学术配色
color_A = [0.2, 0.2, 0.2];
color_B = [0.850, 0.325, 0.098];
color_C = [0.000, 0.447, 0.741];
color_D = [0.850, 0.1, 0.1];

for i = 1:size(channels, 1)
    ch_dir = channels{i, 1};
    ch_title = channels{i, 2};
    
    ber_data_path = fullfile(base_dir, ch_dir, 'WUWNET_BER_Data.mat');
    if exist(ber_data_path, 'file')
        load(ber_data_path);
        
        fig = figure('Name', ['BER Comparison - ' ch_title], 'Position', [100+i*50, 100+i*50, 650, 500], 'Color', 'w');
        
        semilogy(SNR_range, max(BER_A, 1e-6), '-s', 'LineWidth', line_width_thin, 'Color', color_A, 'MarkerSize', 8, 'MarkerFaceColor', 'w'); hold on;
        semilogy(SNR_range, max(BER_B, 1e-6), '-d', 'LineWidth', line_width_thin, 'Color', color_B, 'MarkerSize', 8, 'MarkerFaceColor', 'w');
        semilogy(SNR_range, max(BER_C, 1e-6), '-^', 'LineWidth', line_width_thin, 'Color', color_C, 'MarkerSize', 8, 'MarkerFaceColor', 'w');
        semilogy(SNR_range, max(BER_D, 1e-6), '-p', 'LineWidth', line_width_thick, 'Color', color_D, 'MarkerSize', 10, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', color_D);
        
        grid on; set(gca, 'YMinorGrid', 'on', 'XMinorGrid', 'on', 'GridAlpha', 0.4, 'GridLineStyle', ':', 'FontSize', font_size_tick, 'FontName', font_name);
        set(gca, 'TickDir', 'in', 'YScale', 'log');
        
        % 根据您的要求，不添加 target reference line
        
        title(['BER Performance in ' ch_title], 'FontSize', font_size_title, 'FontWeight', 'bold', 'FontName', font_name);
        xlabel('Signal-to-Noise Ratio (dB)', 'FontSize', font_size_label, 'FontWeight', 'bold', 'FontName', font_name);
        ylabel('Bit Error Rate', 'FontSize', font_size_label, 'FontWeight', 'bold', 'FontName', font_name);
        
        lgd = legend({'No TRM + Std AKF', 'TRM + Std AKF', 'TRM + IAE-AKF (Heuristic)', 'Proposed TRM + HVB-AKF'}, 'Location', 'southwest');
        set(lgd, 'FontName', font_name, 'FontSize', font_size_legend, 'EdgeColor', 'none', 'Color', 'none');
        ylim([1e-4, 1.0]); xlim([min(SNR_range), max(SNR_range)]);
        
        % 添加高 SNR 区域 Bypass 的注释
        text(-2, 2e-4, '\downarrow Bypass Activated: Error Floor Eliminated', 'Color', color_D, 'FontSize', 12, 'FontWeight', 'bold', 'FontName', font_name, 'HorizontalAlignment', 'center');

        % [ADDED] 审稿人要求的 -9 dB 垂直虚线（仅针对 Deep-Sea 子图）
        if i == 1
            xline(-9, '--', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.5);
            text(-9.3, 1e-1, 'Bypass Activated \rightarrow', 'Color', [0.4 0.4 0.4], 'FontSize', 12, 'FontWeight', 'bold', 'FontName', font_name, 'HorizontalAlignment', 'right', 'Rotation', 90);
        end
        
        out_name = sprintf('Fig_BER_Refined_%d.png', i);
        out_path = fullfile(base_dir, 'publication_figures', out_name);
        
        exportgraphics(fig, out_path, 'Resolution', 300);
        close(fig);
        fprintf('Saved %s\n', out_name);
    else
        fprintf('Data not found for %s\n', ch_dir);
    end
end
