function [out_frac, k_actual, tracking_error_history, P_trace] = iakf_dll_tracker(sig_bb, mseq_ref, current_ptr, total_symbols_to_process, len_SS, N_pn, delta, W_size)
% =========================================================================
% 函数名称：iakf_dll_tracker.m
% 功能描述：自适应新息卡尔曼滤波时延锁相环 (IAKF-DLL) 动态追踪模块
% 
% 【创新点说明 - 底层优化与创新设计】
% 1. 基于新息序列(Innovation Sequence)的在线协方差估计(IAE)：
%    利用滑动窗口内鉴相器误差(Zn)的方差 C_k，实时反演量测噪声协方差 R_k
%    与系统过程协方差 Q_k，解决传统KF在未知时变多普勒下极易发散或滞后的难题。
% 2. 结构正则化与抗发散保护：
%    在 Q_estimate 计算中强制对角化剥离高阶多普勒耦合噪声，同时引入鉴相器
%    死区边界 (abs(Zn) < 0.15) 和最大收敛限制，增强极低信噪比下的鲁棒容错机制。
%
% 输入参数：
%   sig_bb      - 降采样或滤波后的基带复信号
%   mseq_ref    - 升采样后的本地参考扩频m序列 (矩形脉冲成形)
%   current_ptr - 初始粗同步确定的信号起始采样点位置
%   total_symbols_to_process - 待追踪的总符号数
%   len_SS      - 扩频序列长度 (如 31 或 15)
%   N_pn        - 每个码片的采样点数 (如 24 或 6)
%   delta       - 超前-滞后门限相关间隔 (一般取 4~8 个采样点)
%   W_size      - 协方差估计自适应滑动窗口大小 (推荐 15~20)
%
% 输出参数：
%   out_frac    - 经过时延追踪对齐后的每码片软判决均值输出
%   k_actual    - 实际成功追踪并解扩的符号总数
%   tracking_error_history - 追踪鉴相新息误差轨迹 (用于评估收敛特性)
%   P_trace     - 误差协方差矩阵迹的动态变化轨迹
% =========================================================================

% --- 1. 卡尔曼滤波状态与协方差初始化 ---
X_k = [0; 0];          % 状态向量：[相位偏移(样本); 相位变化率(多普勒频率估计)]
P_k = eye(2);          % 初始状态误差协方差矩阵
F_mat = [1 1; 0 1];    % 状态转移矩阵 (恒定速度模型)
H_mat = [1 0];         % 量测矩阵 (仅能观测到时延相位偏移)
Q_k = [0.05 0; 0 0.002]; % 初始过程噪声协方差
R_k = 0.1;             % 初始量测噪声协方差

innov_buffer = zeros(1, W_size); % 新息自适应估计缓冲区
innov_idx = 1;
K_gain = [0; 0]; 

out_frac = zeros(1, total_symbols_to_process * len_SS); 
tracking_error_history = zeros(1, total_symbols_to_process);
P_trace = zeros(1, total_symbols_to_process);
k_actual = 0;

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
    % 【创新容错设计】：鉴相死区与阈值截断，防止纯噪声背景下的乱弹发散
    if abs(Zn) < 0.15
        Zn = 0; 
    end 
    
    innov = Zn * delta; % 将归一化鉴相结果映射到实际采样点偏差
    tracking_error_history(k) = innov;
    
    % (4) 【创新点：自适应协方差匹配机制 (IAE)】
    innov_buffer(innov_idx) = innov;
    innov_idx = mod(innov_idx, W_size) + 1;

    if k > W_size
        % 计算滑动窗口内新息序列的实际统计方差
        C_k = var(innov_buffer) + 1e-6; 

        % 实时反演量测噪声协方差 R_k
        R_estimate = C_k - H_mat * (F_mat * P_k * F_mat' + Q_k) * H_mat';
        R_k = max(0.01, 0.8 * R_k + 0.2 * R_estimate); 

        % 实时反演过程协方差 Q_k，并强制对角化剥离耦合项
        Q_estimate = K_gain * C_k * K_gain';
        Q_estimate = diag(diag(Q_estimate)); 
        Q_k = max(1e-4, 0.9 * Q_k + 0.1 * Q_estimate); 
    end
    
    % (5) 卡尔曼量测更新与增益调整
    P_pre = F_mat * P_k * F_mat' + Q_k; 
    K_gain = P_pre * H_mat' / (H_mat * P_pre * H_mat' + R_k); 
    
    X_k = X_pre + K_gain * innov; 
    P_k = (eye(2) - K_gain * H_mat) * P_pre;
    P_trace(k) = trace(P_k);
    
    % (6) Prompt 支路逐码片均值提取（为后续非相干或差分解码提供软判决统计量）
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
end
