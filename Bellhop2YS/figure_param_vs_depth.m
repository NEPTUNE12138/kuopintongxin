function figure_param_vs_depth(results, ssp_data, sofar_depth, Sea_depth)
% FIGURE_PARAM_VS_DEPTH  信道参数随接收深度变化趋势可视化 (论文出图版)
%
% 输入:
%   results     - batch_depth_sweep.m 输出的 results 结构体数组
%   ssp_data    - 声速剖面数据 [depth, speed] 矩阵
%   sofar_depth - 声道轴深度 (m)
%   Sea_depth   - 海底深度 (m)
%
% JYZ 2026

    if isempty(results)
        error('输入结果为空');
    end
    
    depths = [results.rcr_depth];
    
    %% ===== 颜色 =====
    c1 = [0.890 0.101 0.109];
    c2 = [0.121 0.466 0.705];
    c3 = [0.200 0.627 0.172];
    c4 = [0.580 0.404 0.741];
    c5 = [1.000 0.498 0.055];
    
    %% ===== 图1: 声速剖面 + 核心参数并排 (1x4 布局, 删去Gini) =====
    figure('Position', [50, 100, 1280, 500], 'Color', 'w');
    
    % (a) 声速剖面
    subplot(1, 4, 1);
    plot(ssp_data(:,2), ssp_data(:,1), 'k-', 'LineWidth', 1.5);
    axis ij;
    hold on;
    yline(sofar_depth, '--r', 'LineWidth', 1);
    % 标注各区域
    fill_alpha = 0.08;
    % 会聚区 (浅层)
    patch([1480 1550 1550 1480], [0 0 300 300], c1, ...
        'FaceAlpha', fill_alpha, 'EdgeColor', 'none');
    % 声道轴区域
    patch([1480 1550 1550 1480], ...
        [sofar_depth-200 sofar_depth-200 sofar_depth+200 sofar_depth+200], c2, ...
        'FaceAlpha', fill_alpha, 'EdgeColor', 'none');
    % RAP 区域 (近底)
    patch([1480 1550 1550 1480], ...
        [Sea_depth-500 Sea_depth-500 Sea_depth Sea_depth], c3, ...
        'FaceAlpha', fill_alpha, 'EdgeColor', 'none');
    
    xlabel('Sound Speed (m/s)', 'FontName', 'Times New Roman', 'FontSize', 12);
    ylabel('Depth (m)', 'FontName', 'Times New Roman', 'FontSize', 12);
    title('(a) SSP', 'FontSize', 13);
    axis([1480 1550 0 Sea_depth]);
    set(gca, 'XAxisLocation', 'top', 'FontName', 'Times New Roman', 'FontSize', 11);
    grid on; box on;
    
    % (b) 有效路径数
    subplot(1, 4, 2);
    plot([results.n_eff_paths], depths, '-o', 'LineWidth', 2, 'MarkerSize', 6, ...
        'Color', c1, 'MarkerFaceColor', c1);
    axis ij; ylim([0 Sea_depth]);
    hold on; yline(sofar_depth, '--', 'Color', [0.5 0.5 0.5]);
    xlabel('N_{eff}', 'FontSize', 12);
    ylabel('Depth (m)', 'FontName', 'Times New Roman', 'FontSize', 12);
    title('(b) Effective Paths', 'FontName', 'Times New Roman', 'FontSize', 13);
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 11);
    
    % (c) RMS 时延扩展 (原 d)
    subplot(1, 4, 3);
    plot([results.rms_delay_ms], depths, '-^', 'LineWidth', 2, 'MarkerSize', 6, ...
        'Color', c4, 'MarkerFaceColor', c4);
    axis ij; ylim([0 Sea_depth]);
    hold on; yline(sofar_depth, '--', 'Color', [0.5 0.5 0.5]);
    xlabel('\tau_{rms} (ms)', 'FontSize', 12);
    title('(c) RMS Delay Spread', 'FontName', 'Times New Roman', 'FontSize', 13);
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 11, 'YTickLabel', {});
    
    % (d) 前3路径能量占比 (原 e)
    subplot(1, 4, 4);
    plot([results.energy_top3], depths, '-d', 'LineWidth', 2, 'MarkerSize', 6, ...
        'Color', c5, 'MarkerFaceColor', c5);
    axis ij; ylim([0 Sea_depth]); xlim([0 105]);
    hold on; yline(sofar_depth, '--', 'Color', [0.5 0.5 0.5]);
    xlabel('Top-3 Energy (%)', 'FontName', 'Times New Roman', 'FontSize', 12);
    title('(d) Energy Concentration', 'FontName', 'Times New Roman', 'FontSize', 13);
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 11, 'YTickLabel', {});
    
    %% ===== 图2: 带区域填充的综合分析图 =====
    figure('Position', [100, 100, 800, 700], 'Color', 'w');
    
    % 用双Y轴: 左=Gini, 右=RMS时延
    yyaxis left;
    plot(depths, [results.gini], '-o', 'LineWidth', 2.5, 'MarkerSize', 8, ...
        'Color', c2, 'MarkerFaceColor', c2);
    ylabel('Gini Coefficient', 'FontName', 'Times New Roman', 'FontSize', 14, 'Color', c2);
    ylim([0 1.1]);
    set(gca, 'YColor', c2);
    
    yyaxis right;
    plot(depths, [results.rms_delay_ms], '-s', 'LineWidth', 2.5, 'MarkerSize', 8, ...
        'Color', c1, 'MarkerFaceColor', c1);
    ylabel('RMS Delay Spread (ms)', 'FontName', 'Times New Roman', 'FontSize', 14, 'Color', c1);
    set(gca, 'YColor', c1);
    
    xlabel('Receiver Depth (m)', 'FontName', 'Times New Roman', 'FontSize', 14);
    
    % 区域标注
    hold on;
    xline(sofar_depth, '--k', sprintf('SOFAR Axis (%.0fm)', sofar_depth), ...
        'LineWidth', 1.5, 'FontSize', 11, 'FontName', 'Times New Roman', ...
        'LabelHorizontalAlignment', 'center', 'LabelVerticalAlignment', 'bottom');
    
    legend({'Gini Coefficient', 'RMS Delay Spread'}, 'FontName', 'Times New Roman', 'FontSize', 12, ...
        'Location', 'north');
    title('Channel Sparsity and Delay Spread vs. Depth', 'FontName', 'Times New Roman', 'FontSize', 16);
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
    
    %% ===== 图3: 区域分类散点图 (Gini vs RMS时延) =====
    figure('Position', [200, 200, 600, 500], 'Color', 'w');
    
    zone_types = {results.zone_type};
    unique_zones = unique(zone_types);
    zone_colors = [c1; c2; c3; c4; c5];
    zone_markers = {'o', 's', '^', 'd', 'p'};
    
    hold on;
    h_legend = [];
    legend_names = {};
    
    for zi = 1:length(unique_zones)
        mask = strcmp(zone_types, unique_zones{zi});
        if any(mask)
            mk = zone_markers{min(zi, length(zone_markers))};
            cc = zone_colors(min(zi, size(zone_colors,1)), :);
            
            h_legend(end+1) = scatter([results(mask).gini], ...
                [results(mask).rms_delay_ms], 100, cc, mk, 'filled', ...
                'MarkerEdgeColor', 'k', 'LineWidth', 1); %#ok<AGROW>
            
            % Translate zone type for legend
            zname = unique_zones{zi};
            if contains(zname, '会聚')
                ename = 'CZ';
            elseif contains(zname, '声道轴')
                ename = 'SOFAR Axis';
            elseif contains(zname, '可靠声路径')
                ename = 'RAP Zone';
            elseif contains(zname, '影区')
                ename = 'Shadow Zone';
            else
                ename = zname;
            end
            legend_names{end+1} = ename; %#ok<AGROW>
            
            % 标注深度
            idx_mask = find(mask);
            for j = 1:length(idx_mask)
                text(results(idx_mask(j)).gini + 0.01, ...
                    results(idx_mask(j)).rms_delay_ms + 0.05, ...
                    sprintf('%dm', results(idx_mask(j)).rcr_depth), ...
                    'FontSize', 9, 'FontName', 'Times New Roman');
            end
        end
    end
    
    xlabel('Gini Coefficient', 'FontName', 'Times New Roman', 'FontSize', 14);
    ylabel('RMS Delay Spread (ms)', 'FontName', 'Times New Roman', 'FontSize', 14);
    legend(h_legend, legend_names, 'FontName', 'Times New Roman', ...
        'FontSize', 12, 'Location', 'best');
    title('Channel Characteristics across Propagation Zones', 'FontName', 'Times New Roman', 'FontSize', 16);
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
end
