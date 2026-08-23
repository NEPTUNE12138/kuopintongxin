function [out_frac, k_actual, tracking_error_history, P_trace, K_trace] = vb_iakf_pll(sig_bb, mseq_ref, current_ptr, total_symbols_to_process, len_SS, N_pn, delta, use_vb)
% =========================================================================
% 名称：vb_iakf_pll.m
% 基于变分贝叶斯 (Variational Bayes) 的自适应追踪环路
%
% 核心创新：
%   1. 摈弃了传统 IAE 滑动窗口，使用 VB 递推估计量测噪声方差 R_k。
%   2. 结合基于条件异方差推导出的贝叶斯理论惩罚 c1/(m_k^2 + c2)，在信号深衰落时
%      自适应放大方差，确保滤波器进入“稳定滑行”，防止发散。
%   3. 对过程噪声 Q_k 采用对角结构正则化约束。
%
% 输入:
%   sig_bb      - 基带信号
%   mseq_ref    - 扩频参考序列
%   current_ptr - 初始位置指针
%   total_symbols_to_process - 需处理的符号总数
%   len_SS      - 扩频码长
%   N_pn        - 码片内采样点数
%   delta       - 迟早门间距
%   use_vb      - 是否开启变分贝叶斯与理论惩罚 (1=开启, 0=关闭，退化为传统)
%
% 输出:
%   out_frac    - 符号解扩输出
%   k_actual    - 实际处理符号数
%   tracking_error_history - 瞬时追踪误差轨迹
%   P_trace     - 协方差阵的迹(评估收敛性)
% =========================================================================

% --- 1. 初始化 ---
X_k = [0; 0];          
P_k = eye(2);          
F_mat = [1 1; 0 1];    
H_mat = [1 0];         
Q_k = diag([0.05, 0.002]); 
R_k = 0.1;             
R_baseline = 0.1;      

% VB 先验参数初始化
alpha_R = 1;
beta_R = R_k;
rho_R = 0.95; % R_k 的遗忘因子

out_frac = zeros(1, total_symbols_to_process * len_SS); 
tracking_error_history = zeros(1, total_symbols_to_process);
P_trace = zeros(1, total_symbols_to_process);
K_trace = zeros(1, total_symbols_to_process);
k_actual = 0;

prev_soft_sym = 0;     

% --- 2. 符号级追踪迭代 ---
for k = 1 : total_symbols_to_process
    X_pre = F_mat * X_k; 
    phase_off = round(X_pre(1)); 
    idx = current_ptr + phase_off;
    
    % 越界保护
    if (idx - delta < 1) || (idx + len_SS*N_pn + delta > length(sig_bb))
        break; 
    end
    
    % E-L-P 支路提取
    seg_P = sig_bb(idx : idx + len_SS*N_pn - 1);
    seg_E = sig_bb(idx - delta : idx + len_SS*N_pn - 1 - delta);
    seg_L = sig_bb(idx + delta : idx + len_SS*N_pn - 1 + delta);
    
    % 能量积分
    E_pwr = abs(sum(seg_E .* mseq_ref))^2; 
    L_pwr = abs(sum(seg_L .* mseq_ref))^2;
    
    % 鉴相器输出
    Zn = (L_pwr - E_pwr) / (E_pwr + L_pwr + 1e-12);
    raw_innov = Zn * delta; 
    
    if abs(Zn) < 0.15
        Zn = 0; 
    end 
    
    innov = Zn * delta; 
    tracking_error_history(k) = raw_innov;
    
    % --- 深衰落理论惩罚 ---
    current_soft_sym = sum(seg_P .* mseq_ref) / (len_SS * N_pn);  
    raw_diff_k = current_soft_sym * conj(prev_soft_sym);
    soft_mag = abs(raw_diff_k);   % 当前包络
    
    if use_vb == 1
        % 贝叶斯推导的最优条件异方差惩罚: R_optimal ∝ 1 / (m_k^2 + c)
        % 保证 m_k=1 时 penalty=1, m_k=0 时 penalty~=1/c2
        try
            c2 = evalin('base', 'c2_override');
        catch
            c2 = 1/50; 
        end 
        c1 = 1 + c2;
        penalty_factor = c1 / (soft_mag^2 + c2);
    else
        penalty_factor = 1; % 关闭时退化
    end
    
    prev_soft_sym = current_soft_sym;
    P_pre = F_mat * P_k * F_mat' + Q_k; 
    
    % --- 变分贝叶斯 (VB) 更新 ---
    if use_vb == 1
        % 1. 变分 M-step 更新 R_k 超参数 (追踪基准底噪)
        alpha_R = rho_R * alpha_R + 0.5;
        beta_R = rho_R * beta_R + 0.5 * (innov^2 + H_mat * P_pre * H_mat');
        R_vb = beta_R / alpha_R;
        
        % 2. 结合理论惩罚，动态放大方差
        % 当深衰落发生时，用 penalty_factor 放大 VB 估计的基准噪声
        R_k_adaptive = R_vb * penalty_factor;
        
        % 3. Q_k 的变分自适应 (简化为结构正则化对角匹配)
        if k > 2
            if penalty_factor > 2 % [FIXED] 发生深衰落时冻结 Q_k 更新，防止 P_pre 疯狂膨胀
                Q_k = max(1e-4, Q_k); 
            else
                K_temp = P_pre * H_mat' / (H_mat * P_pre * H_mat' + R_k_adaptive);
                Q_est = K_temp * (innov^2) * K_temp';
                Q_k = max(1e-4, 0.9 * Q_k + 0.1 * diag(diag(Q_est)));
            end
        end
    else
        R_k_adaptive = R_baseline;
    end
    
    % --- 滤波增益计算与状态更新 ---
    K_gain = P_pre * H_mat' / (H_mat * P_pre * H_mat' + R_k_adaptive); 
    
    X_k = X_pre + K_gain * innov; 
    P_k = (eye(2) - K_gain * H_mat) * P_pre;
    P_trace(k) = trace(P_k);
    K_trace(k) = K_gain(1);
    
    % --- 软判决输出构建 ---
    for m = 1:len_SS
        out_frac((k-1)*len_SS + m) = mean(seg_P((m-1)*N_pn+1 : m*N_pn)); 
    end
    
    current_ptr = current_ptr + len_SS * N_pn;
    k_actual = k;
end

out_frac = out_frac(1 : k_actual * len_SS);
tracking_error_history = tracking_error_history(1 : k_actual);
P_trace = P_trace(1 : k_actual);
K_trace = K_trace(1 : k_actual);
end
