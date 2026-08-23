%% 深海声信道稀疏特性定量分析 — Demo 验证脚本
%% 基于现有仿真数据运行完整的稀疏性分析流程
%% JYZ 2026.7
%
% 本脚本演示如何使用新开发的三个核心分析函数:
%   1. channel_sparsity_metrics()  - 稀疏度量
%   2. channel_cluster_analysis()  - 多径簇分析
%   3. channel_pdp_statistics()    - PDP 统计参数
%
% 使用现有的 .mat 数据文件进行分析

clc; clear; close all;

%% ========== 加载可用的信道数据 ==========
% 自动检测目录下所有 channel_*.mat 文件
mat_files = dir('channel_*m_*km_*m.mat');
fprintf('找到 %d 个信道数据文件:\n', length(mat_files));
for k = 1:length(mat_files)
    fprintf('  [%d] %s\n', k, mat_files(k).name);
end
fprintf('\n');

%% ========== 逐一分析每个数据文件 ==========
all_results = struct([]);

for f = 1:length(mat_files)
    fname = mat_files(f).name;
    fprintf('\n%s\n', repmat('=', 1, 60));
    fprintf('分析: %s\n', fname);
    fprintf('%s\n', repmat('=', 1, 60));
    
    data = load(fname);
    
    % 提取数据
    delay = real(data.delay_clean);
    amp_norm = abs(data.amp_norm);
    
    % 解析文件名获取配置参数
    tokens = regexp(fname, 'channel_(\d+)m_(\d+)km_(\d+)m', 'tokens');
    if ~isempty(tokens)
        src_depth = str2double(tokens{1}{1});
        range_km  = str2double(tokens{1}{2});
        rcr_depth = str2double(tokens{1}{3});
        config_str = sprintf('声源%dm, 距离%dkm, 接收%dm', ...
                             src_depth, range_km, rcr_depth);
    else
        config_str = fname;
        src_depth = NaN; range_km = NaN; rcr_depth = NaN;
    end
    
    fprintf('配置: %s\n', config_str);
    fprintf('有效路径总数: %d\n', length(delay));
    
    %% ----- 1. 稀疏度量分析 -----
    fprintf('\n--- 稀疏度量 ---\n');
    metrics = channel_sparsity_metrics(delay, amp_norm, ...
        'Threshold_dB', -20, 'TopK', 3, 'Discretize', false);
    
    fprintf('  Gini 系数:         %.4f  (越接近1越稀疏)\n', metrics.gini);
    fprintf('  L1/L2 比值:        %.4f\n', metrics.l1_l2_ratio);
    fprintf('  L1/L2 归一化:      %.4f  (越接近0越稀疏)\n', metrics.l1_l2_norm);
    fprintf('  有效路径数:        %d / %d\n', metrics.n_eff_paths, metrics.n_total_taps);
    fprintf('  有效路径占比:      %.4f%%\n', metrics.eff_path_ratio * 100);
    fprintf('  前%d路径能量占比:  %.2f%%\n', metrics.K, metrics.energy_topK);
    fprintf('  最强路径能量占比:  %.2f%%\n', metrics.energy_top1);
    
    %% ----- 2. 多径簇分析 -----
    fprintf('\n--- 多径簇分析 ---\n');
    clusters = channel_cluster_analysis(delay, amp_norm, ...
        'GapThreshold_ms', 1.0, 'MinClusterSize', 1, 'AmpThreshold_dB', -30);
    
    fprintf('  识别到 %d 个多径簇\n', clusters.n_clusters);
    fprintf('  首簇功率占比: %.2f%%\n', clusters.first_cluster_power_ratio);
    
    if ~isempty(clusters.inter_gap_ms)
        fprintf('  平均簇间间隔: %.2f ms\n', clusters.mean_inter_gap_ms);
    end
    
    for c = 1:clusters.n_clusters
        ci = clusters.info(c);
        fprintf('  簇 %d: 路径数=%d, 中心时延=%.2f ms, 簇内扩展=%.3f ms, 峰值=%.4f, 功率占比=%.1f%%\n', ...
            ci.id, ci.n_paths, ci.delay_center*1e3, ci.intra_spread_ms, ...
            ci.peak_amp, ci.power_ratio);
    end
    
    if clusters.n_clusters >= 3
        fprintf('  衰减拟合: %s\n', clusters.decay_fit.model_str);
    end
    
    %% ----- 3. PDP 统计参数 -----
    fprintf('\n--- PDP 统计参数 ---\n');
    stats = channel_pdp_statistics(delay, amp_norm, 'NoiseFloor_dB', -30);
    
    fprintf('  RMS 时延扩展:     %.4f ms\n', stats.rms_delay_spread_ms);
    fprintf('  平均超额时延:     %.4f ms\n', stats.mean_delay_ms);
    fprintf('  最大超额时延:     %.4f ms\n', stats.max_excess_delay_ms);
    fprintf('  总时延扩展:       %.4f ms\n', stats.total_delay_spread_ms);
    fprintf('  50%%相干带宽:      %.2f Hz\n', stats.coherence_bw_50_Hz);
    fprintf('  90%%相干带宽:      %.2f Hz\n', stats.coherence_bw_90_Hz);
    fprintf('  K 因子:           %.2f dB\n', stats.K_factor_dB);
    
    %% ----- 存入汇总结构体 -----
    all_results(f).filename       = fname;
    all_results(f).config_str     = config_str;
    all_results(f).src_depth      = src_depth;
    all_results(f).range_km       = range_km;
    all_results(f).rcr_depth      = rcr_depth;
    all_results(f).metrics        = metrics;
    all_results(f).clusters       = clusters;
    all_results(f).stats          = stats;
    
    %% ----- 单数据可视化 -----
    figure('Position', [100, 100, 1400, 500], 'Color', 'w');
    sgtitle(config_str, 'FontName', 'Microsoft YaHei', 'FontSize', 16, 'FontWeight', 'bold');
    
    % 子图1: CIR 茎状图 + 簇着色
    subplot(1, 3, 1);
    cluster_colors = lines(max(clusters.n_clusters, 1));
    hold on;
    for c = 1:clusters.n_clusters
        ci = clusters.info(c);
        stem(ci.path_delays * 1e3, ci.path_amps, 'filled', ...
            'Color', cluster_colors(c,:), 'MarkerSize', 6, 'LineWidth', 1.5, ...
            'MarkerFaceColor', cluster_colors(c,:));
    end
    % 标注簇编号
    for c = 1:clusters.n_clusters
        ci = clusters.info(c);
        text(ci.delay_center*1e3, ci.peak_amp + 0.05, ...
            sprintf('簇%d', c), 'FontSize', 11, 'FontName', 'Microsoft YaHei', ...
            'HorizontalAlignment', 'center', 'Color', cluster_colors(c,:));
    end
    xlabel('时延 (ms)', 'FontSize', 13, 'FontName', 'Microsoft YaHei');
    ylabel('归一化幅度', 'FontSize', 13, 'FontName', 'Microsoft YaHei');
    title('(a) CIR 簇标注', 'FontSize', 14, 'FontName', 'Microsoft YaHei');
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
    
    % 子图2: PDP (dB)
    subplot(1, 3, 2);
    stem(stats.pdp_delay * 1e3, stats.pdp_power_dB, 'filled', ...
        'Color', [0.2 0.2 0.8], 'MarkerSize', 5, 'LineWidth', 1.2);
    hold on;
    yline(-20, 'r--', '-20 dB', 'LineWidth', 1.2, 'FontSize', 11, ...
        'LabelHorizontalAlignment', 'left');
    xlabel('超额时延 (ms)', 'FontSize', 13, 'FontName', 'Microsoft YaHei');
    ylabel('归一化功率 (dB)', 'FontSize', 13, 'FontName', 'Microsoft YaHei');
    title('(b) 功率时延谱 (PDP)', 'FontSize', 14, 'FontName', 'Microsoft YaHei');
    grid on; grid minor; box on;
    set(gca, 'FontName', 'Times New Roman', 'FontSize', 12);
    
    % 子图3: 稀疏指标仪表盘
    subplot(1, 3, 3);
    axis off; hold on;
    
    text(0.5, 0.95, '稀疏性指标', 'FontSize', 15, 'FontName', 'Microsoft YaHei', ...
        'FontWeight', 'bold', 'HorizontalAlignment', 'center', ...
        'Units', 'normalized');
    
    info_lines = {
        sprintf('Gini 系数:      %.4f', metrics.gini);
        sprintf('L_1/L_2 归一化:  %.4f', metrics.l1_l2_norm);
        sprintf('有效路径:        %d 条', metrics.n_eff_paths);
        sprintf('前3能量占比:     %.1f%%', metrics.energy_topK);
        '';
        sprintf('簇数量:          %d', clusters.n_clusters);
        sprintf('首簇功率:        %.1f%%', clusters.first_cluster_power_ratio);
        sprintf('平均簇间距:      %.2f ms', clusters.mean_inter_gap_ms);
        '';
        sprintf('RMS 时延扩展:    %.3f ms', stats.rms_delay_spread_ms);
        sprintf('50%%相干带宽:     %.0f Hz', stats.coherence_bw_50_Hz);
        sprintf('K 因子:          %.1f dB', stats.K_factor_dB);
    };
    
    y_pos = 0.85;
    for i = 1:length(info_lines)
        if isempty(info_lines{i})
            y_pos = y_pos - 0.03;
            continue;
        end
        text(0.1, y_pos, info_lines{i}, 'FontSize', 12, ...
            'FontName', 'Times New Roman', 'Units', 'normalized', ...
            'VerticalAlignment', 'top');
        y_pos = y_pos - 0.065;
    end
    
    title('(c) 统计指标汇总', 'FontSize', 14, 'FontName', 'Microsoft YaHei');
end

%% ========== 汇总对比表 (如果有多个数据集) ==========
if length(all_results) > 1
    fprintf('\n\n');
    fprintf('%s\n', repmat('=', 1, 100));
    fprintf('  全部区域信道特性定量对比汇总表\n');
    fprintf('%s\n', repmat('=', 1, 100));
    
    % 表头
    fprintf('%-25s', '参数');
    for k = 1:length(all_results)
        fprintf('%-18s', all_results(k).config_str);
    end
    fprintf('\n');
    fprintf('%s\n', repmat('-', 1, 100));
    
    % 数据行
    fprintf('%-25s', 'Gini 系数');
    for k = 1:length(all_results)
        fprintf('%-18.4f', all_results(k).metrics.gini);
    end
    fprintf('\n');
    
    fprintf('%-25s', 'L1/L2 归一化');
    for k = 1:length(all_results)
        fprintf('%-18.4f', all_results(k).metrics.l1_l2_norm);
    end
    fprintf('\n');
    
    fprintf('%-25s', '有效路径数');
    for k = 1:length(all_results)
        fprintf('%-18d', all_results(k).metrics.n_eff_paths);
    end
    fprintf('\n');
    
    fprintf('%-25s', '前3路径能量占比(%)');
    for k = 1:length(all_results)
        fprintf('%-18.2f', all_results(k).metrics.energy_topK);
    end
    fprintf('\n');
    
    fprintf('%-25s', '簇数量');
    for k = 1:length(all_results)
        fprintf('%-18d', all_results(k).clusters.n_clusters);
    end
    fprintf('\n');
    
    fprintf('%-25s', '首簇功率占比(%)');
    for k = 1:length(all_results)
        fprintf('%-18.2f', all_results(k).clusters.first_cluster_power_ratio);
    end
    fprintf('\n');
    
    fprintf('%-25s', 'RMS时延扩展(ms)');
    for k = 1:length(all_results)
        fprintf('%-18.4f', all_results(k).stats.rms_delay_spread_ms);
    end
    fprintf('\n');
    
    fprintf('%-25s', '50%相干带宽(Hz)');
    for k = 1:length(all_results)
        fprintf('%-18.2f', all_results(k).stats.coherence_bw_50_Hz);
    end
    fprintf('\n');
    
    fprintf('%-25s', 'K因子(dB)');
    for k = 1:length(all_results)
        fprintf('%-18.2f', all_results(k).stats.K_factor_dB);
    end
    fprintf('\n');
    
    fprintf('%s\n', repmat('=', 1, 100));
end

%% ========== 保存分析结果 ==========
save('sparsity_analysis_results.mat', 'all_results');
fprintf('\n分析结果已保存至: sparsity_analysis_results.mat\n');

fprintf('\n===== Demo 分析完成 =====\n');
fprintf('现有 %d 个信道配置的完整稀疏性分析已生成。\n', length(all_results));
fprintf('请在 MATLAB 中运行本脚本查看图形结果。\n');
