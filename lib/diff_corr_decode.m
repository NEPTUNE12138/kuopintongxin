function [output_decode, temp_num, temp_rat] = diff_corr_decode_v2(m, ~, out_frac, ~, symbol_num, N, send_data) 
% diff_corr_decode_v2: 针对低信噪比优化的标量差分接收机
% m: 扩频序列 (-1, 1)
% out_frac: 接收到的复数码片流

m = m(:).'; % 确保行向量
% 1. 解扩：将每个符号 N 个码片聚合成一个复数标量
soft_symbols = zeros(1, symbol_num + 1);
for a = 1 : symbol_num + 1
    current_symbol_chips = out_frac((a-1)*N + 1 : a*N);
    % 利用扩频增益提取复数峰值
    soft_symbols(a) = sum(current_symbol_chips .* m);
end

% 2. 差分解调：相邻符号共轭相乘
output = zeros(1, symbol_num);
for b = 1 : symbol_num
    % 差分判决核心：real( S(k) * conj(S(k-1)) )
    % 对应发送端 dc(n+1) = data(n) * dc(n) -> data(n) = dc(n+1)/dc(n)
    decision_stat = real(soft_symbols(b+1) * conj(soft_symbols(b)));
    
    if decision_stat > 0
        output(b) = 1; % 原始数据 1
    else
        output(b) = 0; % 原始数据 0
    end
end

% 3. 结果统计
output_decode = output;
[temp_num, temp_rat] = symerr(output, send_data(1:symbol_num));

% 绘制解扩后的星座图观察质量
% figure;
% plot(soft_symbols, 'o'); grid on;
% title('解扩后的符号星座图 (应呈现BPSK旋转状态)');
% xlabel('In-phase'); ylabel('Quadrature');
% end