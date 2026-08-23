%% 批量深度扫描 — 信道参数随接收深度的演变分析
%% JYZ 2026.7
%
% 固定声源深度和通信距离, 批量扫描不同接收深度,
% 自动运行 Bellhop + 提取信道稀疏性参数,
% 分析信道特性随深度的变化规律 (跨越多个传播区域)。
%
% 使用方法: 在 MATLAB 中设定好参数后直接运行

clc; clear; close all;

%% ========== 参数配置 ==========
% ---- 固定参数 ----
freq           = 3e3;       % 中心频率 (Hz)
Source_depth   = 100;       % 声源深度 (m) — 浅声源
range          = 20;        % 通信距离 (km) — 固定
Nbeams         = 1000;
Sea_depth      = 4325;
Speed_seafloor = 1542.6;
ssp_file       = 'SSP_202305.mat';
rstep          = 20;

% ---- 深度扫描列表 ----
% 选择跨越不同区域的典型深度
depth_list = [50, 100, 200, 400, 600, 800, 1000, 1161, 1500, ...
              2000, 2500, 3000, 3500, 4000, 4200];
% 区域对照:
% 50~500m:   可能属于会聚区/直达区/影区 (取决于距离)
% ~1161m:    声道轴附近 (SOFAR)
% 3500~4200: 近海底 (RAP)

% ---- 分析参数 ----
gap_threshold_ms = 1.0;

%% ========== 加载声速剖面 ==========
soundspeeds_ori = importdata(ssp_file);
[~, pos] = max(soundspeeds_ori(:, 1));

index1 = 1:1:500;
index2 = 500:3:pos;
soundspeeds = [soundspeeds_ori(index1, :); soundspeeds_ori(index2, :)];

[depth_sort, index] = sort(soundspeeds(:, 1));
speed_sort = soundspeeds(index, 2);
soundspeeds_sort = [[depth_sort.', Sea_depth].', [speed_sort.', Speed_seafloor].'];

%% ========== 加载有效角度 ==========
load valid_angles.mat;

%% ========== 找到声道轴深度 ==========
[~, sofar_idx] = min(soundspeeds_ori(:, 2));
sofar_depth = soundspeeds_ori(sofar_idx, 1);
fprintf('声道轴深度: %.0f m\n', sofar_depth);

%% ========== 批量扫描 ==========
global units; units = 'km'; %#ok<GVMIS>

n_depths = length(depth_list);
results = struct([]);

fprintf('开始批量深度扫描: %d 个深度点\n', n_depths);
fprintf('声源深度: %d m, 通信距离: %d km\n', Source_depth, range);
fprintf('接收深度范围: %d ~ %d m\n\n', min(depth_list), max(depth_list));

for di = 1:n_depths
    Rcr_depth = depth_list(di);
    fprintf('--- 扫描 %d/%d: 接收深度 = %d m ---\n', di, n_depths, Rcr_depth);
    
    % 检查深度有效性
    if Rcr_depth >= Sea_depth
        fprintf('  警告: 接收深度 >= 海深, 跳过\n');
        continue;
    end
    
    % 生成 .env 并运行 Bellhop
    outFileName = 'channel_A';
    R_OR_S = 'S';
    bellhopENVgen(soundspeeds_sort, freq, outFileName, Source_depth, Rcr_depth, ...
                  range, rstep, Nbeams, 'A', R_OR_S, Sea_depth, Speed_seafloor);
    
    bellhop channel_A
    
    % 读取到达数据
    [Arr, ~] = read_arrivals_asc('channel_A.arr');
    Narr = Arr.Narr;
    
    if Narr == 0
        fprintf('  无到达路径, 跳过\n');
        continue;
    end
    
    % 提取数据
    SrcAngle_range  = Arr.SrcAngle(1:Narr);
    Amp_range       = Arr.A(1:Narr);
    Delay_range     = Arr.delay(1:Narr);
    NumTopBnc_range = Arr.NumTopBnc(1:Narr);
    NumBotBnc_range = Arr.NumBotBnc(1:Narr);
    
    % 角度筛选
    valid = false(Narr, 1);
    for k = 1:length(valid_src_angles)
        [diff_min, idx_min] = min(abs(SrcAngle_range - valid_src_angles(k)));
        if diff_min < 0.5
            valid(idx_min) = true;
        end
    end
    
    amp_clean   = Amp_range(valid);
    delay_clean = Delay_range(valid);
    NumTopBnc_clean = NumTopBnc_range(valid);
    NumBotBnc_clean = NumBotBnc_range(valid);
    
    n_paths = length(delay_clean);
    
    if n_paths == 0
        fprintf('  筛选后无有效路径, 跳过\n');
        continue;
    end
    
    amp_norm = abs(amp_clean) / max(abs(amp_clean));
    
    % 分析
    metrics  = channel_sparsity_metrics(delay_clean, amp_norm, ...
                'Threshold_dB', -20, 'TopK', 3, 'Discretize', false);
    clusters = channel_cluster_analysis(delay_clean, amp_norm, ...
                'GapThreshold_ms', gap_threshold_ms);
    stats    = channel_pdp_statistics(delay_clean, amp_norm);
    
    % 声线分类
    n_refract = sum(NumTopBnc_clean == 0 & NumBotBnc_clean == 0);
    n_reflect = n_paths - n_refract;
    
    % 判断区域类型
    if Rcr_depth <= 500 && n_refract > 0
        zone_type = 'CZ/Direct';
    elseif abs(Rcr_depth - sofar_depth) < 300
        zone_type = 'SOFAR';
    elseif Rcr_depth > Sea_depth - 500
        zone_type = 'RAP';
    elseif n_refract == 0
        zone_type = 'Shadow';
    else
        zone_type = 'Mixed';
    end
    
    % 存储
    idx = length(results) + 1;
    results(idx).rcr_depth     = Rcr_depth;
    results(idx).zone_type     = zone_type;
    results(idx).n_paths       = n_paths;
    results(idx).n_refract     = n_refract;
    results(idx).n_reflect     = n_reflect;
    results(idx).gini          = metrics.gini;
    results(idx).l1_l2_norm    = metrics.l1_l2_norm;
    results(idx).n_eff_paths   = metrics.n_eff_paths;
    results(idx).energy_top3   = metrics.energy_topK;
    results(idx).n_clusters    = clusters.n_clusters;
    results(idx).first_pwr     = clusters.first_cluster_power_ratio;
    results(idx).rms_delay_ms  = stats.rms_delay_spread_ms;
    results(idx).coherence_bw  = stats.coherence_bw_50_Hz;
    results(idx).K_factor_dB   = stats.K_factor_dB;
    
    fprintf('  [%s] 路径=%d, Gini=%.4f, 簇=%d, RMS=%.3f ms\n', ...
        zone_type, n_paths, metrics.gini, clusters.n_clusters, ...
        stats.rms_delay_spread_ms);
end

%% ========== 可视化 ==========
if ~isempty(results)
    depths = [results.rcr_depth];
    
    figure('Position', [100, 100, 1400, 900], 'Color', 'w');
    sgtitle(sprintf('信道参数随接收深度变化 (声源%dm, 距离%dkm)', ...
        Source_depth, range), ...
        'FontName', 'Microsoft YaHei', 'FontSize', 16, 'FontWeight', 'bold');
    
    % 子图1: 有效路径数 vs 深度
    subplot(2, 3, 1);
    plot(depths, [results.n_eff_paths], '-o', 'LineWidth', 2, 'MarkerSize', 7, ...
        'Color', [0.890 0.101 0.109], 'MarkerFaceColor', [0.890 0.101 0.109]);
    xlabel('接收深度 (m)', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    ylabel('有效路径数', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    title('(a) 有效多径数', 'FontName', 'Microsoft YaHei', 'FontSize', 14);
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
    hold on; xline(sofar_depth, '--', '声道轴', 'Color', [0.5 0.5 0.5], ...
        'LabelOrientation', 'horizontal', 'FontName', 'Microsoft YaHei', 'FontSize', 10);
    
    % 子图2: Gini 系数
    subplot(2, 3, 2);
    plot(depths, [results.gini], '-s', 'LineWidth', 2, 'MarkerSize', 7, ...
        'Color', [0.121 0.466 0.705], 'MarkerFaceColor', [0.121 0.466 0.705]);
    xlabel('接收深度 (m)', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    ylabel('Gini 系数', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    title('(b) Gini 系数', 'FontName', 'Microsoft YaHei', 'FontSize', 14);
    ylim([0, 1.05]);
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
    hold on; xline(sofar_depth, '--', '声道轴', 'Color', [0.5 0.5 0.5], ...
        'LabelOrientation', 'horizontal', 'FontName', 'Microsoft YaHei', 'FontSize', 10);
    
    % 子图3: 簇数量
    subplot(2, 3, 3);
    plot(depths, [results.n_clusters], '-^', 'LineWidth', 2, 'MarkerSize', 7, ...
        'Color', [0.200 0.627 0.172], 'MarkerFaceColor', [0.200 0.627 0.172]);
    xlabel('接收深度 (m)', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    ylabel('簇数量', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    title('(c) 多径簇数量', 'FontName', 'Microsoft YaHei', 'FontSize', 14);
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
    hold on; xline(sofar_depth, '--', '声道轴', 'Color', [0.5 0.5 0.5], ...
        'LabelOrientation', 'horizontal', 'FontName', 'Microsoft YaHei', 'FontSize', 10);
    
    % 子图4: RMS 时延扩展
    subplot(2, 3, 4);
    plot(depths, [results.rms_delay_ms], '-d', 'LineWidth', 2, 'MarkerSize', 7, ...
        'Color', [0.580 0.404 0.741], 'MarkerFaceColor', [0.580 0.404 0.741]);
    xlabel('接收深度 (m)', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    ylabel('RMS 时延扩展 (ms)', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    title('(d) RMS 时延扩展', 'FontName', 'Microsoft YaHei', 'FontSize', 14);
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
    hold on; xline(sofar_depth, '--', '声道轴', 'Color', [0.5 0.5 0.5], ...
        'LabelOrientation', 'horizontal', 'FontName', 'Microsoft YaHei', 'FontSize', 10);
    
    % 子图5: 能量集中度
    subplot(2, 3, 5);
    plot(depths, [results.energy_top3], '-p', 'LineWidth', 2, 'MarkerSize', 10, ...
        'Color', [1 0.498 0.055], 'MarkerFaceColor', [1 0.498 0.055]);
    xlabel('接收深度 (m)', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    ylabel('能量占比 (%)', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    title('(e) 前3路径能量集中度', 'FontName', 'Microsoft YaHei', 'FontSize', 14);
    ylim([0, 105]);
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
    hold on; xline(sofar_depth, '--', '声道轴', 'Color', [0.5 0.5 0.5], ...
        'LabelOrientation', 'horizontal', 'FontName', 'Microsoft YaHei', 'FontSize', 10);
    
    % 子图6: K因子
    subplot(2, 3, 6);
    K_vals = [results.K_factor_dB];
    valid_K = K_vals(~isinf(K_vals));
    if isempty(valid_K)
        max_K = 10;
    else
        max_K = max(valid_K) + 5;
    end
    K_vals(isinf(K_vals)) = max_K;  % 处理 Inf
    plot(depths, K_vals, '-h', 'LineWidth', 2, 'MarkerSize', 8, ...
        'Color', [0.839 0.153 0.157], 'MarkerFaceColor', [0.839 0.153 0.157]);
    xlabel('接收深度 (m)', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    ylabel('K 因子 (dB)', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    title('(f) K 因子', 'FontName', 'Microsoft YaHei', 'FontSize', 14);
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
    hold on; xline(sofar_depth, '--', '声道轴', 'Color', [0.5 0.5 0.5], ...
        'LabelOrientation', 'horizontal', 'FontName', 'Microsoft YaHei', 'FontSize', 10);
    
    %% ===== 声速剖面 + 区域标注叠加图 =====
    figure('Position', [200, 200, 500, 700], 'Color', 'w');
    
    % 左轴: 声速剖面
    yyaxis left;
    plot(soundspeeds_ori(:, 2), soundspeeds_ori(:, 1), 'k-', 'LineWidth', 1.5);
    axis ij;
    ylabel('深度 (m)', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    xlabel('声速 (m/s)', 'FontName', 'Microsoft YaHei', 'FontSize', 13);
    
    % 标注扫描的接收深度
    hold on;
    for di = 1:length(results)
        % 用颜色编码 Gini 系数
        gini_norm = results(di).gini;
        c_val = [gini_norm, 0, 1-gini_norm];  % 红(稀疏) -> 蓝(不稀疏)
        
        % 在声速剖面上标记
        [~, ssp_idx] = min(abs(soundspeeds_ori(:, 1) - results(di).rcr_depth));
        scatter(soundspeeds_ori(ssp_idx, 2), results(di).rcr_depth, ...
            80, c_val, 'filled', 'MarkerEdgeColor', 'k');
    end
    
    % 标注声道轴
    yline(sofar_depth, '--r', sprintf('声道轴 (%.0fm)', sofar_depth), ...
        'LineWidth', 1.5, 'FontName', 'Microsoft YaHei', 'FontSize', 10, ...
        'LabelHorizontalAlignment', 'left');
    
    axis([1480 1550 0 Sea_depth]);
    set(gca, 'xaxislocation', 'top', 'FontName', 'Times New Roman', 'FontSize', 12);
    title('声速剖面与接收深度稀疏度标注', 'FontName', 'Microsoft YaHei', 'FontSize', 14);
    
    % 添加 colorbar 说明
    cb = colorbar('southoutside');
    colormap(gca, [linspace(0,1,256)', zeros(256,1), linspace(1,0,256)']);
    cb.Label.String = 'Gini 系数 (红=稀疏, 蓝=不稀疏)';
    cb.Label.FontName = 'Microsoft YaHei';
    cb.Label.FontSize = 11;
    
    grid on; box on;
end

%% ========== 保存结果 ==========
save_name = sprintf('depth_sweep_%dm_%dkm.mat', Source_depth, range);
save(save_name, 'results', 'depth_list', 'Source_depth', 'range');
fprintf('\n结果已保存至: %s\n', save_name);
