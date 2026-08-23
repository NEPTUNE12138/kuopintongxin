function figure_sparsity_comparison(results_table, zone_names)
% FIGURE_SPARSITY_COMPARISON  四大传播区域信道稀疏性定量对比可视化
%
% 输入:
%   results_table - 结构体数组, 每个元素包含一个区域的分析结果:
%     .zone_name          - 区域名称
%     .gini               - Gini 系数
%     .l1_l2_norm         - 归一化 L1/L2 比值
%     .eff_path_ratio     - 有效路径占比
%     .energy_top3        - 前3路径能量占比 (%)
%     .n_clusters         - 簇数量
%     .rms_delay_ms       - RMS 时延扩展 (ms)
%     .coherence_bw_Hz    - 50% 相干带宽 (Hz)
%     .K_factor_dB        - K 因子 (dB)
%     .first_cluster_pwr  - 首簇功率占比 (%)
%   zone_names - 区域名称 cell 数组 (用于显示)
%
% JYZ 2026

    n_zones = length(results_table);
    
    %% ===== 颜色方案 =====
    colors = [0.890 0.101 0.109;   % 红 - 会聚区
              0.121 0.466 0.705;   % 蓝 - 声道轴
              0.200 0.627 0.172;   % 绿 - RAP
              0.580 0.404 0.741];  % 紫 - 影区
    
    if n_zones > size(colors, 1)
        colors = [colors; lines(n_zones - size(colors, 1))];
    end
    
    %% ===== 图1: 稀疏性指标柱状对比图 =====
    figure('Position', [100, 100, 1200, 800], 'Color', 'w');
    
    % 子图1: Gini 系数
    subplot(2, 3, 1);
    vals = [results_table.gini];
    bar_h = bar(vals, 0.6, 'FaceColor', 'flat');
    for k = 1:n_zones
        bar_h.CData(k,:) = colors(k,:);
    end
    set(gca, 'XTickLabel', zone_names, 'FontSize', 12, ...
        'FontName', 'Microsoft YaHei');
    ylabel('Gini 系数', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    title('(a) Gini 系数', 'FontName', 'Microsoft YaHei', 'FontSize', 14);
    ylim([0, 1.05]);
    grid on; box on;
    % 标注数值
    for k = 1:n_zones
        text(k, vals(k)+0.02, sprintf('%.4f', vals(k)), ...
            'HorizontalAlignment', 'center', 'FontSize', 10, ...
            'FontName', 'Times New Roman');
    end
    
    % 子图2: L1/L2 归一化比值
    subplot(2, 3, 2);
    vals = [results_table.l1_l2_norm];
    bar_h = bar(vals, 0.6, 'FaceColor', 'flat');
    for k = 1:n_zones
        bar_h.CData(k,:) = colors(k,:);
    end
    set(gca, 'XTickLabel', zone_names, 'FontSize', 12, ...
        'FontName', 'Microsoft YaHei');
    ylabel('L_1/L_2 归一化', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    title('(b) L_1/L_2 归一化比值', 'FontName', 'Microsoft YaHei', 'FontSize', 14);
    ylim([0, max(vals)*1.3 + 0.01]);
    grid on; box on;
    for k = 1:n_zones
        text(k, vals(k)+0.005, sprintf('%.4f', vals(k)), ...
            'HorizontalAlignment', 'center', 'FontSize', 10, ...
            'FontName', 'Times New Roman');
    end
    
    % 子图3: 有效路径数
    subplot(2, 3, 3);
    vals = [results_table.n_eff_paths];
    bar_h = bar(vals, 0.6, 'FaceColor', 'flat');
    for k = 1:n_zones
        bar_h.CData(k,:) = colors(k,:);
    end
    set(gca, 'XTickLabel', zone_names, 'FontSize', 12, ...
        'FontName', 'Microsoft YaHei');
    ylabel('有效路径数', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    title('(c) 有效多径数', 'FontName', 'Microsoft YaHei', 'FontSize', 14);
    grid on; box on;
    for k = 1:n_zones
        text(k, vals(k)+0.3, sprintf('%d', vals(k)), ...
            'HorizontalAlignment', 'center', 'FontSize', 10, ...
            'FontName', 'Times New Roman');
    end
    
    % 子图4: 前3路径能量占比
    subplot(2, 3, 4);
    vals = [results_table.energy_top3];
    bar_h = bar(vals, 0.6, 'FaceColor', 'flat');
    for k = 1:n_zones
        bar_h.CData(k,:) = colors(k,:);
    end
    set(gca, 'XTickLabel', zone_names, 'FontSize', 12, ...
        'FontName', 'Microsoft YaHei');
    ylabel('能量占比 (%)', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    title('(d) 前3路径能量集中度', 'FontName', 'Microsoft YaHei', 'FontSize', 14);
    ylim([0, 105]);
    grid on; box on;
    for k = 1:n_zones
        text(k, vals(k)+2, sprintf('%.1f%%', vals(k)), ...
            'HorizontalAlignment', 'center', 'FontSize', 10, ...
            'FontName', 'Times New Roman');
    end
    
    % 子图5: RMS 时延扩展
    subplot(2, 3, 5);
    vals = [results_table.rms_delay_ms];
    bar_h = bar(vals, 0.6, 'FaceColor', 'flat');
    for k = 1:n_zones
        bar_h.CData(k,:) = colors(k,:);
    end
    set(gca, 'XTickLabel', zone_names, 'FontSize', 12, ...
        'FontName', 'Microsoft YaHei');
    ylabel('RMS 时延扩展 (ms)', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    title('(e) RMS 时延扩展', 'FontName', 'Microsoft YaHei', 'FontSize', 14);
    grid on; box on;
    for k = 1:n_zones
        text(k, vals(k)+0.1, sprintf('%.2f', vals(k)), ...
            'HorizontalAlignment', 'center', 'FontSize', 10, ...
            'FontName', 'Times New Roman');
    end
    
    % 子图6: 簇数量
    subplot(2, 3, 6);
    vals = [results_table.n_clusters];
    bar_h = bar(vals, 0.6, 'FaceColor', 'flat');
    for k = 1:n_zones
        bar_h.CData(k,:) = colors(k,:);
    end
    set(gca, 'XTickLabel', zone_names, 'FontSize', 12, ...
        'FontName', 'Microsoft YaHei');
    ylabel('簇数量', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    title('(f) 多径簇数量', 'FontName', 'Microsoft YaHei', 'FontSize', 14);
    grid on; box on;
    for k = 1:n_zones
        text(k, vals(k)+0.1, sprintf('%d', vals(k)), ...
            'HorizontalAlignment', 'center', 'FontSize', 10, ...
            'FontName', 'Times New Roman');
    end
    
    sgtitle('深海典型传播区域信道稀疏性定量对比', ...
        'FontName', 'Microsoft YaHei', 'FontSize', 16, 'FontWeight', 'bold');
    
    %% ===== 图2: 雷达图 (蜘蛛图) =====
    figure('Position', [150, 150, 700, 600], 'Color', 'w');
    
    % 选取 5 个维度做雷达图 (归一化到 [0, 1])
    radar_labels = {'Gini系数', '能量集中度', '首簇占比', '1/时延扩展', '簇稀疏度'};
    n_dims = length(radar_labels);
    
    radar_data = zeros(n_zones, n_dims);
    for k = 1:n_zones
        radar_data(k, 1) = results_table(k).gini;
        radar_data(k, 2) = results_table(k).energy_top3 / 100;
        radar_data(k, 3) = results_table(k).first_cluster_pwr / 100;
        % 时延扩展取倒数归一化 (时延小 = 信道好)
        all_rms = [results_table.rms_delay_ms];
        if results_table(k).rms_delay_ms > 0
            radar_data(k, 4) = min(all_rms) / results_table(k).rms_delay_ms;
        else
            radar_data(k, 4) = 1;
        end
        % 簇稀疏度 = 1 - (簇数-1)/(最大簇数-1)
        all_nc = [results_table.n_clusters];
        max_nc = max(all_nc);
        if max_nc > 1
            radar_data(k, 5) = 1 - (results_table(k).n_clusters - 1) / (max_nc - 1);
        else
            radar_data(k, 5) = 1;
        end
    end
    
    % 绘制雷达图
    angles = linspace(0, 2*pi, n_dims+1);
    
    hold on;
    % 绘制网格
    for r = 0.2:0.2:1.0
        x_grid = r * cos(angles);
        y_grid = r * sin(angles);
        plot(x_grid, y_grid, ':', 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
    end
    % 绘制轴线
    for d = 1:n_dims
        plot([0, cos(angles(d))], [0, sin(angles(d))], '-', ...
            'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
        text(1.15*cos(angles(d)), 1.15*sin(angles(d)), radar_labels{d}, ...
            'HorizontalAlignment', 'center', 'FontSize', 12, ...
            'FontName', 'Microsoft YaHei');
    end
    
    % 绘制每个区域
    h_lines = zeros(n_zones, 1);
    for k = 1:n_zones
        r_vals = radar_data(k, :);
        x_pts = r_vals .* cos(angles(1:end-1));
        y_pts = r_vals .* sin(angles(1:end-1));
        x_pts = [x_pts, x_pts(1)]; %#ok<AGROW>
        y_pts = [y_pts, y_pts(1)]; %#ok<AGROW>
        
        h_lines(k) = plot(x_pts, y_pts, '-o', 'Color', colors(k,:), ...
            'LineWidth', 2, 'MarkerSize', 6, 'MarkerFaceColor', colors(k,:));
        fill(x_pts, y_pts, colors(k,:), 'FaceAlpha', 0.1, ...
            'EdgeColor', 'none', 'HandleVisibility', 'off');
    end
    
    axis equal;
    axis([-1.4, 1.4, -1.4, 1.4]);
    axis off;
    legend(h_lines, zone_names, 'Location', 'southoutside', ...
        'Orientation', 'horizontal', 'FontName', 'Microsoft YaHei', 'FontSize', 12);
    title('深海传播区域信道稀疏性雷达图', ...
        'FontName', 'Microsoft YaHei', 'FontSize', 16, 'FontWeight', 'bold');
    
    %% ===== 控制台输出对比表 =====
    fprintf('\n');
    fprintf('%s', repmat('=', 1, 80));
    fprintf('\n  深海典型传播区域信道特性定量对比表\n');
    fprintf('%s', repmat('=', 1, 80));
    fprintf('\n');
    fprintf('%-20s', '参数');
    for k = 1:n_zones
        fprintf('%-15s', zone_names{k});
    end
    fprintf('\n');
    fprintf('%s', repmat('-', 1, 80));
    fprintf('\n');
    
    % 各行数据
    param_names = {'Gini 系数', 'L1/L2 归一化', '有效路径数', ...
                   '前3路径能量(%)', '簇数量', 'RMS时延扩展(ms)', ...
                   '相干带宽(Hz)', 'K因子(dB)', '首簇功率(%)'};
    for k = 1:n_zones
        param_vals{k} = [results_table(k).gini, ...
                         results_table(k).l1_l2_norm, ...
                         results_table(k).n_eff_paths, ...
                         results_table(k).energy_top3, ...
                         results_table(k).n_clusters, ...
                         results_table(k).rms_delay_ms, ...
                         results_table(k).coherence_bw_Hz, ...
                         results_table(k).K_factor_dB, ...
                         results_table(k).first_cluster_pwr]; %#ok<AGROW>
    end
    
    for p = 1:length(param_names)
        fprintf('%-20s', param_names{p});
        for k = 1:n_zones
            if p == 3 || p == 5  % 整数
                fprintf('%-15d', round(param_vals{k}(p)));
            else
                fprintf('%-15.4f', param_vals{k}(p));
            end
        end
        fprintf('\n');
    end
    fprintf('%s', repmat('=', 1, 80));
    fprintf('\n');
end
