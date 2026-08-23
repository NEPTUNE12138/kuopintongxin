function figure_plot_channel_angle_amp_3D(SrcAngle, delay, amp_norm, NumTopBnc, NumBotBnc)
% 绘制发射掠射角-时延-归一化幅度的3D图

figure(3); hold on;

colors = [0.890 0.101 0.109;   % 深红 - 折射（主角）
          0.121 0.466 0.705;   % 深蓝 - 海底反射
          0.200 0.627 0.172;   % 墨绿 - 海面反射
          0.400 0.400 0.400];  % 深灰 - 海面底反射

h = [];
legend_labels = {};

for t = 1:4
    if t == 1
        idx = NumTopBnc == 0 & NumBotBnc == 0;
        mk = 'o'; lb = '折射声线';
    elseif t == 2
        idx = NumTopBnc == 0 & NumBotBnc >= 1;
        mk = 's'; lb = '海底反射声线';
    elseif t == 3
        idx = NumTopBnc >= 1 & NumBotBnc == 0;
        mk = '^'; lb = '海面反射声线';
    else
        idx = NumTopBnc >= 1 & NumBotBnc >= 1;
        mk = 'd'; lb = '海面-海底反射声线';
    end
    
    if any(idx)
        n_this = sum(idx);
        % 数量多时缩小marker，不加黑描边
        if n_this > 10
            ms = 4;
            edge_color = colors(t, :);
        else
            ms = 8;
            edge_color = 'k';
        end
        
        h(end+1) = stem3(SrcAngle(idx), delay(idx), amp_norm(idx), ...
            'filled', 'Color', colors(t,:), 'Marker', mk, ...
            'MarkerSize', ms, 'LineWidth', 1.5, ...
            'MarkerFaceColor', colors(t,:), ...
            'MarkerEdgeColor', edge_color);
        legend_labels{end+1} = lb;
    end
end

% 反射声线标注（抬高错开）
other_idx = find(~(NumTopBnc == 0 & NumBotBnc == 0));
if ~isempty(other_idx)
    [~, sort_order] = sort(delay(other_idx));
    sorted_idx = other_idx(sort_order);
    
    base_height = 0.15;
    step_height = 0.10;
    
    for k = 1:length(sorted_idx)
        i = sorted_idx(k);
        label_str = sprintf('(%d,%d)', NumTopBnc(i), NumBotBnc(i));
        z_label = amp_norm(i) + base_height + (k-1)*step_height;
        
        text(SrcAngle(i), delay(i), z_label, label_str, ...
             'FontSize', 14, 'FontName', 'Times New Roman', ...
             'HorizontalAlignment', 'center', 'Color', 'k');
        plot3([SrcAngle(i), SrcAngle(i)], [delay(i), delay(i)], ...
              [amp_norm(i), z_label], 'k:', 'LineWidth', 0.5, ...
              'HandleVisibility', 'off');
    end
end

% 直达声线数量标注
direct_idx = find(NumTopBnc == 0 & NumBotBnc == 0);
if length(direct_idx) >= 1
    [~, max_i] = max(amp_norm(direct_idx));
    i = direct_idx(max_i);
    text(SrcAngle(i), delay(i), amp_norm(i)+0.08, ...
         sprintf('直达×%d', length(direct_idx)), ...
         'FontSize', 14, 'FontName', '宋体', ...
         'HorizontalAlignment', 'center', 'Color', 'k');
end

xlabel(''); ylabel(''); zlabel('');
lgd = legend(h, legend_labels, 'Location', 'best');
set(lgd, 'FontName', '宋体', 'FontSize', 14);
grid on;
view(60, 25);
set(gca, 'FontName', 'Times New Roman', 'FontSize', 14);
box on;
grid on, grid minor;
end