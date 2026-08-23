function [output_decode, err_num, err_rat, global_phase_drift] = block_doppler_decode_silent(m, out_frac, symbol_num, N, ground_truth)
% =========================================================================
% 函数名称：block_doppler_decode_silent.m
% 功能描述：基于全局残差相漂补偿的块解调与非相干判决反馈器
%
% 【创新点说明 - 算法升级】
% 1. 动态相漂自适应消除：
%    在传统非相干差分解调 (raw_diff = soft_syms(2:end) .* conj(soft_syms(1:end-1)))
%    后，进一步利用整体块内的残差相位偏移，通过平方求和与角度估算
%    (angle(sum(sq_diff)) / 2) 提取剩余的高阶多普勒或时钟漂移相位，将其反向
%    补偿至差分结果中，显著降低残留多普勒导致的误码率底线。
% 2. 软判决输出兼容与静默统计：
%    对不同信道质量自适应评估，返回全局估计漂移角，支持主控系统的多策略比选。
% =========================================================================

m = m(:).';
soft_syms = zeros(1, symbol_num + 1);

% --- 1. 逐符号软相关解扩 ---
for i = 1 : symbol_num + 1
    idx_range = (i-1)*N + 1 : i*N;
    if max(idx_range) > length(out_frac)
        break; 
    end
    chips = out_frac(idx_range);
    soft_syms(i) = sum(chips .* m);
end

soft_syms = soft_syms(1 : symbol_num + 1);

% --- 2. 差分共轭乘积解调 ---
raw_diff = soft_syms(2:end) .* conj(soft_syms(1:end-1));

% --- 3. 【创新点：全局残差相漂估计与自适应校准】 ---
sq_diff = raw_diff .^ 2; 
global_phase_drift = angle(sum(sq_diff)) / 2; 

% 应用相位漂移反向补偿
corrected_diff = raw_diff .* exp(-1j * global_phase_drift);

% --- 4. 判决输出与误码率统计 ---
decoded = double(real(corrected_diff) > 0);
output_decode = decoded;

if nargin >= 5 && ~isempty(ground_truth)
    valid_len = min(length(decoded), length(ground_truth));
    err_num = sum(decoded(1:valid_len) ~= ground_truth(1:valid_len));
    if valid_len > 0
        err_rat = err_num / valid_len;
    else
        err_rat = 0.5;
    end
else
    err_num = 0;
    err_rat = 0;
end
end
