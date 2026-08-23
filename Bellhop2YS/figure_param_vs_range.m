function figure_param_vs_range(results)
% FIGURE_PARAM_VS_RANGE  信道参数随距离变化的趋势可视化 (论文出图版)
%
% 输入:
%   results - batch_range_sweep.m 输出的 results 结构体数组
%
% 包含经验公式拟合线的叠加
%
% JYZ 2026

    if isempty(results)
        error('输入结果为空');
    end
    
    ranges = [results.range_km];
    
    %% ===== 颜色定义 =====
    c1 = [0.890 0.101 0.109];  % 红
    c2 = [0.121 0.466 0.705];  % 蓝
    c3 = [0.200 0.627 0.172];  % 绿
    c4 = [0.580 0.404 0.741];  % 紫
    c5 = [1.000 0.498 0.055];  % 橙
    
    %% ===== 图1: 关键参数趋势 (2x2 紧凑版, 适合论文) =====
    figure('Position', [100, 100, 900, 700], 'Color', 'w');
    
    % (a) 有效路径数
    subplot(2, 2, 1);
    plot(ranges, [results.n_eff_paths], '-o', 'LineWidth', 2, 'MarkerSize', 7, ...
        'Color', c1, 'MarkerFaceColor', c1);
    % 线性拟合叠加
    if length(ranges) >= 3
        p = polyfit(ranges, [results.n_eff_paths], 1);
        hold on;
        plot(ranges, polyval(p, ranges), '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);
        text(0.05, 0.9, sprintf('k=%.3f/km', p(1)), 'Units', 'normalized', ...
            'FontSize', 10, 'FontName', 'Times New Roman', 'Color', [0.5 0.5 0.5]);
    end
    xlabel('Communication Range (km)', 'FontName', 'Times New Roman', 'FontSize', 13);
    ylabel('Number of Effective Paths (N_{eff})', 'FontName', 'Times New Roman', 'FontSize', 13);
    title('(a) Effective Paths', 'FontName', 'Times New Roman', 'FontSize', 14);
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
    
    % (b) RMS 时延扩展
    subplot(2, 2, 2);
    plot(ranges, [results.rms_delay_ms], '-s', 'LineWidth', 2, 'MarkerSize', 7, ...
        'Color', c4, 'MarkerFaceColor', c4);
    if length(ranges) >= 3
        p = polyfit(ranges, [results.rms_delay_ms], 1);
        hold on;
        plot(ranges, polyval(p, ranges), '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1.5);
        text(0.05, 0.9, sprintf('\\tau_{rms}=%.4f·r%+.4f', p(1), p(2)), ...
            'Units', 'normalized', 'FontSize', 10, 'FontName', 'Times New Roman', ...
            'Color', [0.5 0.5 0.5]);
    end
    xlabel('Communication Range (km)', 'FontName', 'Times New Roman', 'FontSize', 13);
    ylabel('RMS Delay Spread (ms)', 'FontName', 'Times New Roman', 'FontSize', 13);
    title('(b) RMS Delay Spread', 'FontName', 'Times New Roman', 'FontSize', 14);
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
    
    % (c) Gini 系数
    subplot(2, 2, 3);
    plot(ranges, [results.gini], '-^', 'LineWidth', 2, 'MarkerSize', 7, ...
        'Color', c2, 'MarkerFaceColor', c2);
    xlabel('Communication Range (km)', 'FontName', 'Times New Roman', 'FontSize', 13);
    ylabel('Gini Coefficient', 'FontName', 'Times New Roman', 'FontSize', 13);
    title('(c) Gini Coefficient', 'FontName', 'Times New Roman', 'FontSize', 14);
    ylim([0, 1.05]);
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
    
    % (d) 前3路径能量占比
    subplot(2, 2, 4);
    plot(ranges, [results.energy_top3], '-d', 'LineWidth', 2, 'MarkerSize', 7, ...
        'Color', c5, 'MarkerFaceColor', c5);
    xlabel('Communication Range (km)', 'FontName', 'Times New Roman', 'FontSize', 13);
    ylabel('Top-3 Paths Energy Ratio (%)', 'FontName', 'Times New Roman', 'FontSize', 13);
    title('(d) Energy Concentration', 'FontName', 'Times New Roman', 'FontSize', 14);
    ylim([0, 105]);
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
end
