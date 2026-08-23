function figure_plot_channel_delay_amp_2D(delay, amp_norm, NumTopBnc, NumBotBnc)
% 绘制时延-归一化幅度的2D投影图

figure; hold on;

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
        if n_this > 10
            ms = 4;
            edge_color = colors(t, :);
        else
            ms = 8;
            edge_color = 'k';
        end
        
        h(end+1) = stem(delay(idx), amp_norm(idx), ...
            'filled', 'Color', colors(t,:), 'Marker', mk, ...
            'MarkerSize', ms, 'LineWidth', 1.5, ...
            'MarkerFaceColor', colors(t,:), ...
            'MarkerEdgeColor', edge_color);
        legend_labels{end+1} = lb;
    end
end

% 反射声线标注（抬高错开）
other_idx = find(~(NumTopBnc == 0 & NumBotBnc == 0));
sorted_idx = [];
if ~isempty(other_idx)
    [~, sort_order] = sort(delay(other_idx));
    sorted_idx = other_idx(sort_order);
    
    base_height = 0.12;
    step_height = 0.10;
    
    for k = 1:length(sorted_idx)
        i = sorted_idx(k);
        label_str = sprintf('(%d,%d)', NumTopBnc(i), NumBotBnc(i));
        y_label = amp_norm(i) + base_height + (k-1)*step_height;
        
        text(delay(i), y_label, label_str, ...
             'FontSize', 14, 'FontName', 'Times New Roman', ...
             'HorizontalAlignment', 'center', 'Color', 'k');
        plot([delay(i), delay(i)], [amp_norm(i), y_label], ...
             'k:', 'LineWidth', 0.5, 'HandleVisibility', 'off');
    end
end

% 直达声线数量标注
direct_idx = find(NumTopBnc == 0 & NumBotBnc == 0);
if length(direct_idx) >= 1
    [~, max_i] = max(amp_norm(direct_idx));
    i = direct_idx(max_i);
    text(delay(i), amp_norm(i)+0.05, ...
         sprintf('直达×%d', length(direct_idx)), ...
         'FontSize', 14, 'FontName', '宋体', ...
         'HorizontalAlignment', 'center', 'Color', 'k');
end

xlabel(''); ylabel('');
lgd = legend(h, legend_labels, 'Location', 'northeast');
set(lgd, 'FontName', '宋体', 'FontSize', 14);
grid on; grid minor;
set(gca, 'FontName', 'Times New Roman', 'FontSize', 14);
box on;

if ~isempty(sorted_idx)
    max_label_height = 0.15 + length(sorted_idx) * 0.10;
    ylim([0, max(1.15, max_label_height + 0.1)]);
else
    ylim([0, 1.15]);
end
grid on, grid minor;
end