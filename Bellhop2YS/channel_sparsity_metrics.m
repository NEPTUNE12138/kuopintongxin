function metrics = channel_sparsity_metrics(delay, amp_norm, varargin)
% CHANNEL_SPARSITY_METRICS  计算水声信道冲激响应的稀疏性度量指标
%
% 输入:
%   delay      - 到达时延向量 (s)
%   amp_norm   - 归一化幅度向量 (与 delay 等长)
%   可选参数 (Name-Value):
%     'Fs'            - 离散化采样率 (Hz), 默认 = 1e6 (1 MHz)
%     'Threshold_dB'  - 有效路径判定阈值 (dB), 默认 = -20 (最大值的 -20 dB)
%     'TopK'          - 能量集中度计算的前 K 条路径, 默认 = 3
%     'Discretize'    - 是否将连续 CIR 离散化到均匀时间网格, 默认 = true
%
% 输出:
%   metrics - 结构体, 包含以下字段:
%     .gini          - Gini 系数 (0~1, 越接近 1 越稀疏)
%     .l1_l2_ratio   - L1/L2 范数比值 (越小越稀疏; 最小值 = 1)
%     .l1_l2_norm    - 归一化 L1/L2 比值 (0~1, 越接近 0 越稀疏)
%     .eff_path_ratio- 有效路径占比 (占总 tap 数百分比, 越小越稀疏)
%     .n_eff_paths   - 有效路径绝对数量
%     .n_total_taps  - 离散化后总 tap 数
%     .energy_topK   - 前 K 条路径的能量占比 (%)
%     .energy_top1   - 最强路径的能量占比 (%)
%     .K              - 能量集中度计算使用的 K 值
%
% 示例:
%   load('channel_100m_45km_110m.mat');
%   metrics = channel_sparsity_metrics(delay_clean, amp_norm);
%   fprintf('Gini = %.4f, L1/L2 = %.4f\n', metrics.gini, metrics.l1_l2_ratio);
%
% JYZ 2026

    %% ===== 参数解析 =====
    p = inputParser;
    addRequired(p, 'delay');
    addRequired(p, 'amp_norm');
    addParameter(p, 'Fs', 1e6, @isnumeric);
    addParameter(p, 'Threshold_dB', -20, @isnumeric);
    addParameter(p, 'TopK', 3, @isnumeric);
    addParameter(p, 'Discretize', true, @islogical);
    parse(p, delay, amp_norm, varargin{:});
    
    Fs           = p.Results.Fs;
    threshold_dB = p.Results.Threshold_dB;
    topK         = p.Results.TopK;
    do_disc      = p.Results.Discretize;
    
    %% ===== 预处理: 取实部时延, 幅度归一化 =====
    delay_real = real(delay(:));
    amp = abs(amp_norm(:));
    
    % 确保幅度归一化到 [0, 1]
    if max(amp) > 0
        amp = amp / max(amp);
    end
    
    %% ===== 离散化到均匀时间网格 (可选) =====
    if do_disc && length(delay_real) > 1
        t_min = min(delay_real);
        t_max = max(delay_real);
        dt = 1 / Fs;
        t_grid = (t_min : dt : t_max)';
        n_taps = length(t_grid);
        
        % 在网格上放置到达能量
        h_disc = zeros(n_taps, 1);
        for k = 1:length(delay_real)
            [~, idx] = min(abs(t_grid - delay_real(k)));
            h_disc(idx) = h_disc(idx) + amp(k)^2;  % 功率叠加
        end
        h_disc = sqrt(h_disc);  % 转回幅度
        h_vec = h_disc;
    else
        h_vec = amp;
        n_taps = length(amp);
    end
    
    %% ===== 1. Gini 系数 =====
    % Gini 系数定义: G = (2·Σ_i(i·x_i)) / (n·Σ_i(x_i)) - (n+1)/n
    % 其中 x 按升序排列
    x_sorted = sort(abs(h_vec), 'ascend');
    n = length(x_sorted);
    if sum(x_sorted) > 0
        idx_vec = (1:n)';
        gini = (2 * sum(idx_vec .* x_sorted)) / (n * sum(x_sorted)) - (n + 1) / n;
        gini = max(0, min(1, gini));  % 限制在 [0, 1]
    else
        gini = 1;  % 全零 = 极度稀疏
    end
    
    %% ===== 2. L1/L2 范数比值 =====
    l1_norm = sum(abs(h_vec));
    l2_norm = sqrt(sum(h_vec.^2));
    
    if l2_norm > 0
        l1_l2_ratio = l1_norm / l2_norm;
        % 归一化到 [0, 1]: 最小值为1(一个非零元素), 最大值为sqrt(n)(均匀分布)
        l1_l2_norm = (l1_l2_ratio - 1) / (sqrt(n) - 1);
        l1_l2_norm = max(0, min(1, l1_l2_norm));
    else
        l1_l2_ratio = 0;
        l1_l2_norm = 0;
    end
    
    %% ===== 3. 有效路径占比 =====
    % 有效路径: 幅度超过最大值的 threshold_dB 的路径
    threshold_lin = 10^(threshold_dB / 20);  % 转换为线性幅度阈值
    
    % 基于原始到达数据计算(而非离散化网格)
    n_eff = sum(amp >= threshold_lin);
    eff_path_ratio = n_eff / n_taps;  % 相对于总 tap 数的占比
    
    %% ===== 4. 能量集中度 =====
    power_vec = amp.^2;
    total_power = sum(power_vec);
    
    if total_power > 0
        power_sorted = sort(power_vec, 'descend');
        K_actual = min(topK, length(power_sorted));
        energy_topK = sum(power_sorted(1:K_actual)) / total_power * 100;
        energy_top1 = power_sorted(1) / total_power * 100;
    else
        energy_topK = 0;
        energy_top1 = 0;
        K_actual = topK;
    end
    
    %% ===== 输出结构体 =====
    metrics.gini           = gini;
    metrics.l1_l2_ratio    = l1_l2_ratio;
    metrics.l1_l2_norm     = l1_l2_norm;
    metrics.eff_path_ratio = eff_path_ratio;
    metrics.n_eff_paths    = n_eff;
    metrics.n_total_taps   = n_taps;
    metrics.energy_topK    = energy_topK;
    metrics.energy_top1    = energy_top1;
    metrics.K              = K_actual;
end
