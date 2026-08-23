function [out_frac, k_actual, tracking_error_history, P_trace, K_trace] = df_iakf_pll(sig_bb, mseq_ref, current_ptr, total_symbols_to_process, len_SS, N_pn, delta, W_size, use_confidence)
% =========================================================================
% 函数名称：df_iakf_pll.m
% 功能描述：判决反馈自适应新息卡尔曼滤波锁相环 (DF-IAKF-PLL) 
%           ——面向极端多径ISI的时空联合均衡追踪模块
%
% 【重构模块 4：DF-IAKF 的置信度防雪崩机制】
% [MODIFIED] 在原 iakf_dll_tracker.m 基础上注入软符号包络实时调控卡尔曼
% 量测协方差 R_k 的机制，切断深度衰落引起的判决反馈误差雪崩传播：
%
% 核心物理机理：
%   1. 提取当前差分软符号包络 soft_mag = abs(raw_diff(k))
%   2. 置信度惩罚函数：penalty_factor = 1 + 50 * exp(-2.5 * soft_mag)
%      - soft_mag → 0 (深衰落)：penalty_factor → 51, R_k 剧增 → K_gain → 0
%        状态进入惯性滑行 (Coast) 模式，避免错误判决污染状态
%      - soft_mag → ∞ (可靠判决)：penalty_factor → 1, R_k ≈ R_baseline
%        正常卡尔曼跟踪
%   3. 动态量测噪声：R_k_adaptive = R_baseline * penalty_factor
%   4. 在卡尔曼增益公式中用 R_k_adaptive 替代固定 R
%
% 兼容性说明：
%   函数签名与 iakf_dll_tracker.m 完全一致，可直接替换调用。
%
% 输入参数：
%   sig_bb      - 基带复信号 (降采样或低通滤波后)
%   mseq_ref    - 升采样后的本地参考扩频m序列 (矩形脉冲成形)
%   current_ptr - 初始粗同步确定的信号起始采样点位置
%   total_symbols_to_process - 待追踪的总符号数
%   len_SS      - 扩频序列长度 (如 31)
%   N_pn        - 每个码片的采样点数 (如 6 或 24)
%   delta       - 超前-滞后门限相关间隔 (一般取 2~8 个采样点)
%   W_size      - 协方差估计自适应滑动窗口大小 (推荐 15~20)
%   use_confidence - [消融控制] 置信度防雪崩开关 (1=激活指数膨胀, 0=关闭强制penalty=1)
%
% 输出参数：
%   out_frac    - 经过时延追踪对齐后的每码片软判决均值输出
%   k_actual    - 实际成功追踪并解扩的符号总数
%   tracking_error_history - 追踪鉴相新息误差轨迹
%   P_trace     - 误差协方差矩阵迹的动态变化轨迹
% =========================================================================

% --- 1. 卡尔曼滤波状态与协方差初始化 ---
X_k = [0; 0];          % 状态向量：[相位偏移(样本); 相位变化率(多普勒频率估计)]
P_k = eye(2);          % 初始状态误差协方差矩阵
F_mat = [1 1; 0 1];    % 状态转移矩阵 (恒定速度模型)
H_mat = [1 0];         % 量测矩阵 (仅能观测到时延相位偏移)
Q_k = [0.05 0; 0 0.002]; % 初始过程噪声协方差
R_k = 0.1;             % 初始量测噪声协方差

% ======================== [MODIFIED-Module4 START] ========================
% 【重构模块 4】：DF-IAKF 的置信度防雪崩机制
% R_baseline：基准量测噪声方差，用于构建自适应 R_k_adaptive
R_baseline = 0.1;      % [MODIFIED] 基准量测噪声方差
% ======================== [MODIFIED-Module4 INIT] =========================

innov_buffer = zeros(1, W_size); % 新息自适应估计缓冲区
innov_idx = 1;
K_gain = [0; 0]; 

out_frac = zeros(1, total_symbols_to_process * len_SS); 
tracking_error_history = zeros(1, total_symbols_to_process);
P_trace = zeros(1, total_symbols_to_process);
K_trace = zeros(1, total_symbols_to_process);
k_actual = 0;

% ======================== [MODIFIED-Module4 BUFFER] =======================
% [MODIFIED] 为差分软符号包络计算预分配缓冲区
% 需要存储逐符号的 Prompt 支路相关输出，用于计算 raw_diff
prev_soft_sym = 0;     % 前一符号的 Prompt 软相关值（初始化为零）
% =========================================================================

% --- 2. 逐符号时延追踪与解扩大循环 ---
for k = 1 : total_symbols_to_process
    % (1) 卡尔曼先验估计
    X_pre = F_mat * X_k; 
    phase_off = round(X_pre(1)); 
    idx = current_ptr + phase_off;
    
    % 容错越界检查：如果追踪超出基带信号范围，则停止追踪
    if (idx - delta < 1) || (idx + len_SS*N_pn + delta > length(sig_bb))
        break; 
    end
    
    % (2) 超前-滞后 (Early-Late-Prompt) 支路截取
    seg_P = sig_bb(idx : idx + len_SS*N_pn - 1);
    seg_E = sig_bb(idx - delta : idx + len_SS*N_pn - 1 - delta);
    seg_L = sig_bb(idx + delta : idx + len_SS*N_pn - 1 + delta);
    
    % 计算超前与滞后支路的相关能量
    E_pwr = abs(sum(seg_E .* mseq_ref))^2; 
    L_pwr = abs(sum(seg_L .* mseq_ref))^2;
    
    % (3) 非相干鉴相器 (Phase Detector) 计算归一化时延误差
    Zn = (L_pwr - E_pwr) / (E_pwr + L_pwr + 1e-9);
    raw_innov = Zn * delta; 
    
    % (4) 判断是否处于深度衰落并执行“平稳滑行”策略 (死区机制)
    if abs(Zn) < 0.15
        Zn = 0; 
    end 
    
    innov = Zn * delta; 
    tracking_error_history(k) = raw_innov;
    
    % ==================== [MODIFIED-Module4 CORE START] ====================
    % 【重构模块 4 核心】：软符号包络驱动的置信度防雪崩机制
    
    % (4a) [MODIFIED] 提取当前 Prompt 支路软相关值（用于差分包络计算）
    current_soft_sym = sum(seg_P .* mseq_ref) / (len_SS * N_pn);  % 当前符号的 Prompt 软相关输出
    
    % (4b) [MODIFIED] 计算差分软符号包络 soft_mag
    %   raw_diff(k) = current_soft_sym * conj(prev_soft_sym)
    %   当信道质量差时，差分输出幅度趋近零 → 判决不可靠
    raw_diff_k = current_soft_sym * conj(prev_soft_sym);
    soft_mag = abs(raw_diff_k);   % 差分软符号包络幅度
    
    % (4c) [MODIFIED] 置信度惩罚函数 —— 受消融开关 use_confidence 控制
    %   - 深度衰落 (soft_mag → 0)：penalty → 51，R 剧增 → K_gain → 0 (惯性滑行)
    %   - 可靠判决 (soft_mag → ∞)：penalty → 1，R ≈ R_baseline (正常跟踪)
    if use_confidence == 1
        % [消融ON] 激活指数膨胀惩罚 —— 完整防雪崩保护
        penalty_factor = 1 + 50 * exp(-2.5 * soft_mag);
    else
        % [消融OFF] 关闭防雪崩机制，强制 penalty = 1（退化为标准 IAKF）
        penalty_factor = 1;
    end
    
    % (4d) [MODIFIED] 动态更新当前时刻的量测噪声方差
    R_k_adaptive = R_baseline * penalty_factor;
    
    % (4e) 更新前一符号软相关值（为下一步差分计算做准备）
    prev_soft_sym = current_soft_sym;
    % ==================== [MODIFIED-Module4 CORE END] ======================
    
    % (5) 自适应协方差匹配机制 (IAE) —— 保留原创新息自适应
    innov_buffer(innov_idx) = innov;
    innov_idx = mod(innov_idx, W_size) + 1;

    if k > W_size
        % 计算滑动窗口内新息序列的实际统计方差
        C_k = var(innov_buffer) + 1e-6; 

        % 实时反演量测噪声协方差 R_k (传统 IAE 路径)
        R_estimate = C_k - H_mat * (F_mat * P_k * F_mat' + Q_k) * H_mat';
        R_k = max(0.01, 0.8 * R_k + 0.2 * R_estimate); 

        % 实时反演过程协方差 Q_k，并强制对角化剥离耦合项
        if use_confidence == 1 && penalty_factor > 2
            Q_k = max(1e-4, Q_k);
        else
            Q_estimate = K_gain * C_k * K_gain';
            Q_estimate = diag(diag(Q_estimate)); 
            Q_k = max(1e-4, 0.9 * Q_k + 0.1 * Q_estimate); 
        end 
        
        % ============ [MODIFIED-Module4 融合] ============
        % [MODIFIED] 将 IAE 估计的 R_k 与置信度惩罚后的 R_k_adaptive 融合
        % 取两者中更保守（更大）的值，确保双重保护
        R_k_adaptive = max(R_k_adaptive, R_k);
        % ================================================
    end
    
    % (6) 卡尔曼量测更新与增益调整
    P_pre = F_mat * P_k * F_mat' + Q_k; 
    % ============ [MODIFIED-Module4 K_gain] ============
    % [MODIFIED] 在卡尔曼增益计算中，使用 R_k_adaptive 替代原有固定 R_k
    % 当陷入深度衰落时，R_k_adaptive 急剧增大 → K_gain 趋于 0 → 惯性滑行
    K_gain = P_pre * H_mat' / (H_mat * P_pre * H_mat' + R_k_adaptive); 
    % ==================================================
    
    X_k = X_pre + K_gain * innov; 
    P_k = (eye(2) - K_gain * H_mat) * P_pre;
    P_trace(k) = trace(P_k);
    K_trace(k) = K_gain(1);
    
    % (7) Prompt 支路逐码片均值提取（为后续非相干或差分解码提供软判决统计量）
    for m = 1:len_SS
        out_frac((k-1)*len_SS + m) = mean(seg_P((m-1)*N_pn+1 : m*N_pn)); 
    end
    
    % 指针推进一个扩频符号周期
    current_ptr = current_ptr + len_SS * N_pn;
    k_actual = k;
end

% 剪裁多余的输出缓冲区
out_frac = out_frac(1 : k_actual * len_SS);
tracking_error_history = tracking_error_history(1 : k_actual);
P_trace = P_trace(1 : k_actual);
K_trace = K_trace(1 : k_actual);
end
