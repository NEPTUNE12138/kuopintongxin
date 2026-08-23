function stats = channel_pdp_statistics(delay, amp_norm, varargin)
% CHANNEL_PDP_STATISTICS  计算水声信道功率时延谱 (PDP) 统计参数
%
% 基于信道冲激响应的到达时延与幅度, 计算通信系统设计所需的关键统计参数。
%
% 输入:
%   delay      - 到达时延向量 (s)
%   amp_norm   - 归一化幅度向量
%   可选参数 (Name-Value):
%     'DirectPathIdx'  - 直达径索引 (默认自动识别为最早到达的最强路径)
%     'NoiseFloor_dB'  - 噪声底限 (dB), 低于此值的路径不参与统计, 默认 = -30
%
% 输出:
%   stats - 结构体, 包含以下字段:
%     .rms_delay_spread_ms  - RMS 时延扩展 (ms)
%     .mean_delay_ms        - 平均超额时延 (ms, 参考首达径)
%     .max_excess_delay_ms  - 最大超额时延 (ms)
%     .total_delay_spread_ms- 总时延扩展 (ms, 首达到末达)
%     .coherence_bw_50_Hz   - 50% 相干带宽 (Hz), 近似 = 1/(5·τ_rms)
%     .coherence_bw_90_Hz   - 90% 相干带宽 (Hz), 近似 = 1/(50·τ_rms)
%     .K_factor_dB          - K 因子 (dB), 直达径功率 / 散射径总功率
%     .n_paths_total        - 参与统计的总路径数
%     .n_paths_eff          - 有效路径数 (高于噪声底限)
%     .pdp_delay            - PDP 时延向量 (s, 参考首达径)
%     .pdp_power_dB         - PDP 功率向量 (dB)
%     .pdp_power_norm       - PDP 归一化功率 (线性)
%
% 参考:
%   [1] T.S. Rappaport, Wireless Communications, 2nd Ed.
%   [2] M. Stojanovic, "Underwater acoustic communications"
%
% JYZ 2026

    %% ===== 参数解析 =====
    p = inputParser;
    addRequired(p, 'delay');
    addRequired(p, 'amp_norm');
    addParameter(p, 'DirectPathIdx', [], @isnumeric);
    addParameter(p, 'NoiseFloor_dB', -30, @isnumeric);
    parse(p, delay, amp_norm, varargin{:});
    
    direct_idx   = p.Results.DirectPathIdx;
    noise_floor  = p.Results.NoiseFloor_dB;
    
    %% ===== 预处理 =====
    delay_real = real(delay(:));
    amp = abs(amp_norm(:));
    N = length(delay_real);
    
    % 归一化
    amp_max = max(amp);
    if amp_max > 0
        amp = amp / amp_max;
    end
    
    %% ===== 识别直达径 =====
    if isempty(direct_idx)
        % 取最早到达的路径中幅度最强的
        [~, sort_idx] = sort(delay_real);
        % 在前 30% 或前3条路径中找最强的
        n_early = max(3, round(0.3 * N));
        n_early = min(n_early, N);
        early_idx = sort_idx(1:n_early);
        [~, best] = max(amp(early_idx));
        direct_idx = early_idx(best);
    end
    
    %% ===== 构建 PDP =====
    % 以首达径时延为参考
    t_ref = delay_real(direct_idx);
    excess_delay = delay_real - t_ref;  % 超额时延
    power = amp.^2;  % 功率
    
    % 按超额时延排序
    [excess_sorted, sort_order] = sort(excess_delay);
    power_sorted = power(sort_order);
    amp_sorted = amp(sort_order);
    
    %% ===== 噪声底限滤除 =====
    noise_th = 10^(noise_floor / 10);  % 功率阈值 (相对于最大功率)
    valid = power_sorted >= noise_th;
    
    excess_valid = excess_sorted(valid);
    power_valid  = power_sorted(valid);
    n_eff = sum(valid);
    
    %% ===== 统计参数计算 =====
    total_power = sum(power_valid);
    
    % 平均超额时延 (功率加权)
    if total_power > 0
        mean_delay = sum(excess_valid .* power_valid) / total_power;
    else
        mean_delay = 0;
    end
    
    % RMS 时延扩展
    if total_power > 0 && n_eff > 1
        rms_delay = sqrt(sum(power_valid .* (excess_valid - mean_delay).^2) / total_power);
    else
        rms_delay = 0;
    end
    
    % 最大超额时延
    max_excess = max(excess_valid) - min(excess_valid);
    
    % 总时延扩展
    total_spread = max(delay_real) - min(delay_real);
    
    %% ===== 相干带宽 =====
    if rms_delay > 0
        Bc_50 = 1 / (5 * rms_delay);     % 50% 相关
        Bc_90 = 1 / (50 * rms_delay);    % 90% 相关
    else
        Bc_50 = Inf;
        Bc_90 = Inf;
    end
    
    %% ===== K 因子 =====
    direct_power = power(direct_idx);
    scatter_power = total_power - direct_power;
    
    if scatter_power > 0
        K_factor = direct_power / scatter_power;
        K_factor_dB = 10 * log10(K_factor);
    else
        K_factor_dB = Inf;  % 只有直达径
    end
    
    %% ===== PDP 输出 =====
    power_dB = 10 * log10(power_sorted + eps);  % dB
    power_dB = power_dB - max(power_dB);  % 归一化到最大值 0 dB
    
    %% ===== 构建输出结构体 =====
    stats.rms_delay_spread_ms   = rms_delay * 1e3;
    stats.mean_delay_ms         = mean_delay * 1e3;
    stats.max_excess_delay_ms   = max_excess * 1e3;
    stats.total_delay_spread_ms = total_spread * 1e3;
    stats.coherence_bw_50_Hz    = Bc_50;
    stats.coherence_bw_90_Hz    = Bc_90;
    stats.K_factor_dB           = K_factor_dB;
    stats.n_paths_total         = N;
    stats.n_paths_eff           = n_eff;
    stats.pdp_delay             = excess_sorted;
    stats.pdp_power_dB          = power_dB;
    stats.pdp_power_norm        = power_sorted / max(power_sorted + eps);
end
