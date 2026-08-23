function clusters = channel_cluster_analysis(delay, amp_norm, varargin)
% CHANNEL_CLUSTER_ANALYSIS  水声信道 CIR 多径簇自动识别与参数化分析
%
% 基于到达时延间隔的阈值法实现簇识别, 并提取每个簇的统计参数。
%
% 输入:
%   delay      - 到达时延向量 (s)
%   amp_norm   - 归一化幅度向量
%   可选参数 (Name-Value):
%     'GapThreshold_ms' - 簇间最小时延间隔阈值 (ms), 默认 = 1.0
%     'MinClusterSize'  - 最小簇成员数, 默认 = 1
%     'AmpThreshold_dB' - 筛选弱路径的幅度阈值 (dB), 默认 = -30
%
% 输出:
%   clusters - 结构体, 包含以下字段:
%     .n_clusters        - 簇总数
%     .cluster_id        - 每条路径的簇编号 (与输入等长, 0=被滤除)
%     .info              - 结构体数组, 每个元素描述一个簇:
%       .id              - 簇编号
%       .n_paths         - 簇内路径数
%       .delay_center    - 簇中心时延 (s) (功率加权质心)
%       .delay_min       - 簇内最小时延 (s)
%       .delay_max       - 簇内最大时延 (s)
%       .intra_spread_ms - 簇内时延扩展 (ms)
%       .rms_spread_ms   - 簇内 RMS 时延扩展 (ms)
%       .peak_amp        - 簇内最大归一化幅度
%       .mean_amp        - 簇内平均幅度
%       .total_power     - 簇内总功率 (归一化)
%       .power_ratio     - 簇功率占信道总功率百分比 (%)
%       .path_delays     - 簇内各路径时延
%       .path_amps       - 簇内各路径幅度
%     .inter_gap_ms      - 相邻簇间时延间隔向量 (ms) (长度 = n_clusters-1)
%     .mean_inter_gap_ms - 平均簇间间隔 (ms)
%     .first_cluster_power_ratio - 首簇功率占比 (%)
%     .decay_fit         - 簇间功率衰减拟合结构体:
%       .type            - 拟合类型 ('exponential')
%       .alpha           - 衰减系数 (1/s)
%       .r_squared       - 拟合 R^2
%       .model_str       - 拟合公式字符串
%
% 示例:
%   load('channel_100m_45km_110m.mat');
%   clusters = channel_cluster_analysis(delay_clean, amp_norm, 'GapThreshold_ms', 1.5);
%   fprintf('识别到 %d 个簇\n', clusters.n_clusters);
%
% JYZ 2026

    %% ===== 参数解析 =====
    p = inputParser;
    addRequired(p, 'delay');
    addRequired(p, 'amp_norm');
    addParameter(p, 'GapThreshold_ms', 1.0, @isnumeric);
    addParameter(p, 'MinClusterSize', 1, @isnumeric);
    addParameter(p, 'AmpThreshold_dB', -30, @isnumeric);
    parse(p, delay, amp_norm, varargin{:});
    
    gap_th_s     = p.Results.GapThreshold_ms * 1e-3;  % 转为秒
    min_size     = p.Results.MinClusterSize;
    amp_th_dB    = p.Results.AmpThreshold_dB;
    
    %% ===== 预处理 =====
    delay_real = real(delay(:));
    amp = abs(amp_norm(:));
    N = length(delay_real);
    
    % 幅度阈值滤除弱路径
    amp_th_lin = 10^(amp_th_dB / 20) * max(amp);
    valid_mask = amp >= amp_th_lin;
    
    delay_valid = delay_real(valid_mask);
    amp_valid   = amp(valid_mask);
    orig_idx    = find(valid_mask);
    
    % 按时延排序
    [delay_sorted, sort_order] = sort(delay_valid);
    amp_sorted = amp_valid(sort_order);
    orig_idx_sorted = orig_idx(sort_order);
    
    M = length(delay_sorted);
    
    %% ===== 簇识别: 基于时延间隔阈值 =====
    if M == 0
        clusters.n_clusters = 0;
        clusters.cluster_id = zeros(N, 1);
        clusters.info = [];
        clusters.inter_gap_ms = [];
        clusters.mean_inter_gap_ms = 0;
        clusters.first_cluster_power_ratio = 0;
        clusters.decay_fit = struct('type', 'exponential', 'alpha', 0, ...
                                     'r_squared', 0, 'model_str', 'N/A');
        return;
    end
    
    % 计算相邻路径的时延间隔
    dt = diff(delay_sorted);
    
    % 识别簇边界 (间隔超过阈值处断开)
    cluster_labels = ones(M, 1);  % 初始所有路径属于簇1
    cluster_count = 1;
    for k = 2:M
        if dt(k-1) > gap_th_s
            cluster_count = cluster_count + 1;
        end
        cluster_labels(k) = cluster_count;
    end
    
    %% ===== 筛除过小的簇 =====
    valid_clusters = [];
    for c = 1:cluster_count
        if sum(cluster_labels == c) >= min_size
            valid_clusters = [valid_clusters, c]; %#ok<AGROW>
        end
    end
    
    % 重新编号
    new_labels = zeros(M, 1);
    for i = 1:length(valid_clusters)
        new_labels(cluster_labels == valid_clusters(i)) = i;
    end
    cluster_labels = new_labels;
    n_clusters = length(valid_clusters);
    
    %% ===== 构建每条路径的簇编号 (映射回原始索引) =====
    cluster_id_full = zeros(N, 1);
    for k = 1:M
        if cluster_labels(k) > 0
            cluster_id_full(orig_idx_sorted(k)) = cluster_labels(k);
        end
    end
    
    %% ===== 提取每个簇的详细参数 =====
    total_power_all = sum(amp.^2);  % 全信道总功率
    info = struct([]);
    
    for c = 1:n_clusters
        mask_c = (cluster_labels == c);
        d_c = delay_sorted(mask_c);
        a_c = amp_sorted(mask_c);
        p_c = a_c.^2;  % 功率
        
        info(c).id = c;
        info(c).n_paths = sum(mask_c);
        
        % 功率加权质心时延
        if sum(p_c) > 0
            info(c).delay_center = sum(d_c .* p_c) / sum(p_c);
        else
            info(c).delay_center = mean(d_c);
        end
        
        info(c).delay_min = min(d_c);
        info(c).delay_max = max(d_c);
        info(c).intra_spread_ms = (max(d_c) - min(d_c)) * 1e3;  % ms
        
        % RMS 时延扩展 (簇内)
        if sum(p_c) > 0 && length(d_c) > 1
            mean_delay = sum(d_c .* p_c) / sum(p_c);
            rms_spread = sqrt(sum(p_c .* (d_c - mean_delay).^2) / sum(p_c));
            info(c).rms_spread_ms = rms_spread * 1e3;
        else
            info(c).rms_spread_ms = 0;
        end
        
        info(c).peak_amp = max(a_c);
        info(c).mean_amp = mean(a_c);
        info(c).total_power = sum(p_c);
        
        if total_power_all > 0
            info(c).power_ratio = sum(p_c) / total_power_all * 100;
        else
            info(c).power_ratio = 0;
        end
        
        info(c).path_delays = d_c;
        info(c).path_amps = a_c;
    end
    
    %% ===== 簇间参数 =====
    if n_clusters > 1
        centers = [info.delay_center];
        inter_gaps = diff(centers) * 1e3;  % ms
    else
        inter_gaps = [];
    end
    
    %% ===== 簇间功率衰减拟合 =====
    decay_fit = struct('type', 'exponential', 'alpha', 0, ...
                        'r_squared', 0, 'model_str', 'N/A');
    
    if n_clusters >= 3
        centers = [info.delay_center]';
        powers  = [info.total_power]';
        
        % 参考首簇的相对时延和归一化功率
        rel_delay = centers - centers(1);
        norm_power = powers / powers(1);
        
        % 指数衰减拟合: P(tau) = exp(-alpha * tau)
        % 取对数: ln(P) = -alpha * tau
        valid_fit = norm_power > 0;
        if sum(valid_fit) >= 2
            ln_p = log(norm_power(valid_fit));
            tau_fit = rel_delay(valid_fit);
            
            % 最小二乘线性拟合
            X = [tau_fit, ones(length(tau_fit), 1)];
            coeffs = X \ ln_p;
            alpha_fit = -coeffs(1);
            
            % R^2
            ln_p_pred = X * coeffs;
            ss_res = sum((ln_p - ln_p_pred).^2);
            ss_tot = sum((ln_p - mean(ln_p)).^2);
            if ss_tot > 0
                r2 = 1 - ss_res / ss_tot;
            else
                r2 = 0;
            end
            
            decay_fit.alpha = alpha_fit;
            decay_fit.r_squared = r2;
            decay_fit.model_str = sprintf('P(τ) = P_1 · exp(-%.2f · Δτ), R²=%.4f', ...
                                           alpha_fit, r2);
        end
    end
    
    %% ===== 构建输出 =====
    clusters.n_clusters = n_clusters;
    clusters.cluster_id = cluster_id_full;
    clusters.info = info;
    clusters.inter_gap_ms = inter_gaps;
    clusters.mean_inter_gap_ms = mean(inter_gaps);
    
    if n_clusters >= 1
        clusters.first_cluster_power_ratio = info(1).power_ratio;
    else
        clusters.first_cluster_power_ratio = 0;
    end
    
    clusters.decay_fit = decay_fit;
end
