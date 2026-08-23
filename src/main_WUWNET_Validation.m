%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% WUWNET'26 Validation Main Script: TRM + VB-AKF with Bellhop Channel
% (Multi-Channel Batch Validation Version)
clc; clear; close all;

% ==================== 参数设定 ====================
MONTE_CARLO_ITERS = 3000; % 为了最终出图更平滑，已调整为 2000 次（如果您需要快速验证，可改回 200）。
currentFile = mfilename('fullpath');
[currentPath, ~, ~] = fileparts(currentFile);
addpath(genpath(fullfile(currentPath, '../lib')));
addpath(genpath(fullfile(currentPath, '../data')));
addpath(genpath(fullfile(currentPath, '../Bellhop2YS')));
fprintf('========================================================================\n');
fprintf('  WUWNET''26 验证平台: TRM + VB-AKF 物理场测试 (多信道遍历)\n');
fprintf('  Monte Carlo: %d 次\n', MONTE_CARLO_ITERS);
fprintf('========================================================================\n');

%% 1. 数据初始化与调制
fs = 48e3; f0 = 5e3; fh = 7e3; fl = 3e3; N_pn = 6;
load mseq.mat; mseq = mseq{2,1}; mseq(mseq==0) = -1; len_SS = length(mseq);

NumTotalSymbol_Short = 120; % 截取短数据帧加速验证
load send_rand_data.mat;
send_data_raw_short = send_rand_data(1 : NumTotalSymbol_Short - 2);

RandBinaryData_polar = sign(send_rand_data(1:15000) - 0.5);
RandBinaryData_polar(RandBinaryData_polar == 0) = 1;
dc = zeros(1, 15001); dc(1) = 1;
for n = 1:15000, dc(n+1) = RandBinaryData_polar(n) * dc(n); end
BinaryData1_Short = dc(1 : NumTotalSymbol_Short - 1);

CodeSend = kron(BinaryData1_Short, mseq);
SignalI1 = rectpulse(real(CodeSend), N_pn);
t_mod = (0:length(SignalI1)-1)/fs;
SignalAftMod = SignalI1 .* cos(2*pi*f0*t_mod);
SignalAftMod = SignalAftMod / max(abs(SignalAftMod));

[b_bp, a_bp] = butter(4, [fl-500, fh+500]/(fs/2));
[b_lp, a_lp] = butter(4, 2500/(fs/2));
SignalAftMod = filtfilt(b_bp, a_bp, SignalAftMod);

pw = 0.5; SignalLfm = syncsig(pw, fl, fh, fs, 2, 2) * 0.85;
SignalDelay = zeros(1, round(0.8 * fs));
SignalSend = [SignalDelay SignalLfm SignalDelay SignalAftMod SignalDelay];

plot_save_dir_base = '../results_plots/WUWNET';
if ~exist(plot_save_dir_base, 'dir'), mkdir(plot_save_dir_base); end

%% 定义要遍历的 Bellhop 信道模型
bellhop_channels = {
    'channel_100m_45km_110m.mat', '深海 45km';
    'channel_15m_20km_34m.mat', '浅海 20km (水深34m)';
    'channel_15m_20km_3467m.mat', '浅海 20km (斜坡起伏)' 
};

SNR_range = -14 : 1 : 0;
Num_Trials = MONTE_CARLO_ITERS;
num_channels = size(bellhop_channels, 1);

% 用于保存所有信道下 Proposed D (VB-AKF) 的 BER，以便最终汇总
all_channel_BER_D = zeros(num_channels, length(SNR_range));

%% 2. 开始多信道遍历测试
for ch_idx = 1 : num_channels
    ch_filename = bellhop_channels{ch_idx, 1};
    ch_desc = bellhop_channels{ch_idx, 2};
    [~, ch_name_no_ext, ~] = fileparts(ch_filename);
    
    fprintf('\n========================================================================\n');
    fprintf('>>> 开始测试信道 [%d/%d]: %s (%s)\n', ch_idx, num_channels, ch_desc, ch_filename);
    fprintf('========================================================================\n');
    
    % 为当前信道创建独立的保存目录
    plot_save_dir = fullfile(plot_save_dir_base, ch_name_no_ext);
    if ~exist(plot_save_dir, 'dir'), mkdir(plot_save_dir); end
    
    %% 加载当前 Bellhop 物理场数据
    try
        bellhop = load(['../Bellhop2YS/', ch_filename]);
        delay_samples = round(bellhop.delay_clean * fs);
        delay_samples = delay_samples - min(delay_samples) + 1;
        h = zeros(1, max(delay_samples) + 100);
        for i = 1:length(delay_samples)
            h(delay_samples(i)) = h(delay_samples(i)) + bellhop.amp_norm(i);
        end
        h = h / norm(h); % 能量归一化
        
        % 绘制当前信道冲激响应
        fig_channel = figure('Name', ['Bellhop 信道 - ' ch_desc], 'Position', [200, 200, 800, 400], 'Visible', 'off');
        stem(bellhop.delay_clean * 1000, bellhop.amp_norm, 'b', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
        grid on; set(gca, 'YMinorGrid', 'on', 'XMinorGrid', 'on', 'GridAlpha', 0.4, 'FontSize', 12);
        title(['物理多径冲激响应 (Bellhop) - ', ch_desc], 'FontSize', 14, 'FontWeight', 'bold');
        xlabel('到达时延 (ms)', 'FontSize', 13, 'FontWeight', 'bold');
        ylabel('归一化幅度', 'FontSize', 13, 'FontWeight', 'bold');
        saveas(fig_channel, fullfile(plot_save_dir, 'Fig_Bellhop_CIR.png'));
        close(fig_channel);
    catch
        fprintf('警告：未能成功加载 %s 数据，将跳过此信道...\n', ch_filename);
        continue;
    end
    
    signal_channel = filter(h, 1, SignalSend);
    mseq_ref = rectpulse(mseq, N_pn);
    
    %% 当前信道下的 SNR 遍历仿真
    BER_A = zeros(size(SNR_range)); 
    BER_B = zeros(size(SNR_range)); 
    BER_C = zeros(size(SNR_range)); 
    BER_D = zeros(size(SNR_range)); 
    
    for s_idx = 1 : length(SNR_range)
        SNR = SNR_range(s_idx);
        err_a = 0; err_b = 0; err_c = 0; err_d = 0;
        
        for trial = 1 : Num_Trials
            noise = randn(1, length(signal_channel));
            NoiseFilt = filter(b_bp, a_bp, noise);
            scale_noise = sqrt(var(signal_channel) / (10^(SNR/10)) / var(NoiseFilt));
            SignalRe = signal_channel + NoiseFilt * scale_noise;
            SignalAftBP = filter(b_bp, a_bp, SignalRe);
            
            % CIR 估计
            Ifft_est = corr_fun(SignalAftBP(1:round(fs*2.5)), SignalLfm);
            [~, Peak_est] = max(abs(Ifft_est));
            
            % OS-CFAR 提取 CIR
            win_start = max(1, Peak_est - 50);
            win_end   = min(length(Ifft_est), Peak_est + 800);
            h_raw     = Ifft_est(win_start : win_end);
            
            noise_win_start = max(1, Peak_est - 4000);
            noise_win_end   = max(1, Peak_est - 1000);
            if noise_win_end <= noise_win_start, noise_win_start=1; noise_win_end=500; end
            noise_segment = abs(Ifft_est(noise_win_start : noise_win_end));
            h_thresh_cfar = mean(noise_segment) + 3.5 * std(noise_segment);
            
            h_cfar = h_raw;
            h_cfar(abs(h_cfar) < h_thresh_cfar) = 0;
            
            % ================================================================
            % Baseline A: 无TRM + DF-IAKF
            % ================================================================
            if Peak_est + length(SignalDelay) <= length(SignalAftBP)
                Sig_a = SignalAftBP(Peak_est + length(SignalDelay) : end);
                t1 = (0:length(Sig_a)-1)/fs;
                sig_bb_a = filter(b_lp, a_lp, 2 * Sig_a .* exp(-1j*2*pi*f0*t1));
                [out_frac_a, k_a, ~, ~] = df_iakf_pll(sig_bb_a, mseq_ref, 401, ...
                    length(BinaryData1_Short), len_SS, N_pn, 2, 15, 0); 
                if k_a > 2
                    [~, ~, ber] = block_doppler_decode_silent(mseq, out_frac_a(:).', k_a - 1, len_SS, send_data_raw_short(1:k_a-1));
                    err_a = err_a + ber;
                else, err_a = err_a + 0.5; end
            else, err_a = err_a + 0.5; end
            
            % ================================================================
            % CFAR-TRM 预聚焦
            % ================================================================
            h_tr = fliplr(h_cfar);
            h_tr = h_tr / (max(abs(h_tr)) + 1e-12);
            Sig_TRM = conv(SignalAftBP, h_tr);
            Sig_TRM = Sig_TRM(length(h_tr) : end);
            Sig_TRM = Sig_TRM / (max(abs(Sig_TRM)) + 1e-12);
            
            Ifft_TRM = corr_fun(Sig_TRM(1:round(fs*2.5)), SignalLfm);
            [~, Peak_TRM] = max(abs(Ifft_TRM));
            
            start_cut = max(1, Peak_TRM + length(SignalDelay) - 400);
            if start_cut < length(Sig_TRM)
                SigInt = Sig_TRM(start_cut : end);
                t_bb = (0:length(SigInt)-1)/fs;
                sig_bb_trm = filter(b_lp, a_lp, 2 * SigInt .* exp(-1j*2*pi*f0*t_bb));
                
                % Baseline B: TRM + Std AKF (无衰落惩罚)
                [out_frac_b, k_b, ~, ~] = df_iakf_pll(sig_bb_trm, mseq_ref, 401, ...
                    length(BinaryData1_Short), len_SS, N_pn, 2, 15, 0);
                if k_b > 2
                    [~, ~, ber] = block_doppler_decode_silent(mseq, out_frac_b(:).', k_b - 1, len_SS, send_data_raw_short(1:k_b-1));
                    err_b = err_b + ber;
                else, err_b = err_b + 0.5; end
                
                % Baseline C: TRM + IAE-AKF (经验衰落惩罚)
                [out_frac_c, k_c, ~, ~] = df_iakf_pll(sig_bb_trm, mseq_ref, 401, ...
                    length(BinaryData1_Short), len_SS, N_pn, 2, 15, 1);
                if k_c > 2
                    [~, ~, ber] = block_doppler_decode_silent(mseq, out_frac_c(:).', k_c - 1, len_SS, send_data_raw_short(1:k_c-1));
                    err_c = err_c + ber;
                else, err_c = err_c + 0.5; end
                
                % Proposed D: TRM + VB-AKF
                [out_frac_d, k_d, trk_err_d, ~] = vb_iakf_pll(sig_bb_trm, mseq_ref, 401, ...
                    length(BinaryData1_Short), len_SS, N_pn, 2, 1);
                if k_d > 2
                    [~, ~, ber] = block_doppler_decode_silent(mseq, out_frac_d(:).', k_d - 1, len_SS, send_data_raw_short(1:k_d-1));
                    err_d = err_d + ber;
                else, err_d = err_d + 0.5; end
            else
                err_b = err_b + 0.5; err_c = err_c + 0.5; err_d = err_d + 0.5;
            end
        end
        
        BER_A(s_idx) = err_a / Num_Trials;
        BER_B(s_idx) = err_b / Num_Trials;
        BER_C(s_idx) = err_c / Num_Trials;
        BER_D(s_idx) = err_d / Num_Trials;
        
        fprintf('SNR: %3d dB | A(NoTRM): %.4f | B(TRM+Std): %.4f | C(TRM+Heur): %.4f | D(Proposed VB): %.4f\n', ...
            SNR, BER_A(s_idx), BER_B(s_idx), BER_C(s_idx), BER_D(s_idx));
    end
    
    % 记录当前信道下 D 的结果用于最终汇总
    all_channel_BER_D(ch_idx, :) = BER_D;
    
    %% 当前信道绘制对比图
    fig_joint = figure('Name', ['WUWNET 验证 - ' ch_desc], 'Position', [150, 150, 900, 600], 'Visible', 'off');
    
    semilogy(SNR_range, max(BER_A, 1e-6), 'k--s', 'LineWidth', 1.8, 'MarkerSize', 7, 'MarkerFaceColor', 'k'); hold on;
    semilogy(SNR_range, max(BER_B, 1e-6), 'm-.d', 'LineWidth', 1.8, 'MarkerSize', 7, 'MarkerFaceColor', 'm');
    semilogy(SNR_range, max(BER_C, 1e-6), 'b-.^', 'LineWidth', 1.8, 'MarkerSize', 7, 'MarkerFaceColor', 'b');
    semilogy(SNR_range, max(BER_D, 1e-6), 'r-p', 'LineWidth', 3.2, 'MarkerSize', 11, 'MarkerFaceColor', 'y', 'MarkerEdgeColor', 'r');
    
    grid on; set(gca, 'YMinorGrid', 'on', 'XMinorGrid', 'on', 'GridAlpha', 0.4, 'FontSize', 12);
    yline(1e-3, 'g--', 'LineWidth', 1.5, 'Label', '目标 10^{-3}');
    title(['WUWNET''26 验证: ', ch_desc, ' 物理场性能'], 'FontSize', 13, 'FontWeight', 'bold');
    xlabel('SNR (dB)', 'FontSize', 13, 'FontWeight', 'bold');
    ylabel('Bit Error Rate (BER)', 'FontSize', 13, 'FontWeight', 'bold');
    legend({'Baseline A: No TRM + Std AKF', 'Baseline B: TRM + Std AKF', 'Baseline C: TRM + IAE-AKF (Heuristic)', 'Proposed: TRM + VB-AKF'}, 'Location', 'southwest', 'FontSize', 11);
    ylim([1e-4, 1.0]); xlim([min(SNR_range), max(SNR_range)]);
    
    saveas(fig_joint, fullfile(plot_save_dir, 'Fig_WUWNET_BER_Comparison.png'));
    close(fig_joint);
    save(fullfile(plot_save_dir, 'WUWNET_BER_Data.mat'), 'SNR_range', 'BER_A', 'BER_B', 'BER_C', 'BER_D');
    fprintf('  -> 已保存 [%s] 验证结果至 %s\n', ch_desc, plot_save_dir);
    
    %% 当前信道深度剖析出图 (Deep Analysis Plots)
    fprintf('  -> 生成 [%s] 的深度剖析图像...\n', ch_desc);
    SNR_demo = -8;
    noise_demo = randn(1, length(signal_channel));
    NoiseFilt_demo = filter(b_bp, a_bp, noise_demo);
    scale_noise_demo = sqrt(var(signal_channel) / (10^(SNR_demo/10)) / var(NoiseFilt_demo));
    SignalRe_demo = signal_channel + NoiseFilt_demo * scale_noise_demo;
    SignalAftBP_demo = filter(b_bp, a_bp, SignalRe_demo);
    
    Ifft_est_demo = corr_fun(SignalAftBP_demo(1:round(fs*2.5)), SignalLfm);
    [~, Peak_est_demo] = max(abs(Ifft_est_demo));
    win_start_demo = max(1, Peak_est_demo - 50);
    win_end_demo   = min(length(Ifft_est_demo), Peak_est_demo + 800);
    h_raw_demo     = Ifft_est_demo(win_start_demo : win_end_demo);
    
    noise_win_start_d = max(1, Peak_est_demo - 4000);
    noise_win_end_d   = max(1, Peak_est_demo - 1000);
    if noise_win_end_d <= noise_win_start_d, noise_win_start_d=1; noise_win_end_d=500; end
    h_thresh_cfar_d = mean(abs(Ifft_est_demo(noise_win_start_d:noise_win_end_d))) + 3.5 * std(abs(Ifft_est_demo(noise_win_start_d:noise_win_end_d)));
    h_cfar_demo = h_raw_demo; h_cfar_demo(abs(h_cfar_demo) < h_thresh_cfar_d) = 0;
    
    h_tr_demo = fliplr(h_cfar_demo);
    h_tr_demo = h_tr_demo / (max(abs(h_tr_demo)) + 1e-12);
    h_equiv = conv(h_cfar_demo, h_tr_demo);
    
    fig_trm = figure('Name', ['TRM 预聚焦等效信道 - ' ch_desc], 'Position', [250, 250, 850, 450], 'Visible', 'off');
    subplot(2,1,1);
    plot(abs(h_cfar_demo), 'b', 'LineWidth', 1.5);
    title(['接收端估计的原始多径 CIR (', ch_desc, ')'], 'FontSize', 12, 'FontWeight', 'bold');
    grid on; ylabel('幅度'); set(gca, 'FontSize', 11);
    subplot(2,1,2);
    plot(abs(h_equiv), 'r', 'LineWidth', 1.5);
    title('经过 TRM 空时匹配滤波后的等效 CIR (能量完美聚焦于主峰)', 'FontSize', 12, 'FontWeight', 'bold');
    grid on; ylabel('幅度'); xlabel('抽头延迟 (Tap Index)'); set(gca, 'FontSize', 11);
    saveas(fig_trm, fullfile(plot_save_dir, 'Fig_TRM_Focusing.png'));
    close(fig_trm);
    
    Sig_TRM_demo = conv(SignalAftBP_demo, h_tr_demo);
    Sig_TRM_demo = Sig_TRM_demo(length(h_tr_demo) : end);
    Sig_TRM_demo = Sig_TRM_demo / (max(abs(Sig_TRM_demo)) + 1e-12);
    
    Ifft_TRM_d = corr_fun(Sig_TRM_demo(1:round(fs*2.5)), SignalLfm);
    [~, Peak_TRM_d] = max(abs(Ifft_TRM_d));
    start_cut_d = max(1, Peak_TRM_d + length(SignalDelay) - 400);
    SigInt_d = Sig_TRM_demo(start_cut_d : end);
    t_bb_d = (0:length(SigInt_d)-1)/fs;
    sig_bb_trm_demo = filter(b_lp, a_lp, 2 * SigInt_d .* exp(-1j*2*pi*f0*t_bb_d));
    
    % Baseline A Demo (No TRM)
    if Peak_est_demo + length(SignalDelay) <= length(SignalAftBP_demo)
        Sig_a_demo = SignalAftBP_demo(Peak_est_demo + length(SignalDelay) : end);
        t1_demo = (0:length(Sig_a_demo)-1)/fs;
        sig_bb_a_demo = filter(b_lp, a_lp, 2 * Sig_a_demo .* exp(-1j*2*pi*f0*t1_demo));
        [out_frac_a_demo, ~, trk_err_a_demo, ~] = df_iakf_pll(sig_bb_a_demo, mseq_ref, 401, length(BinaryData1_Short), len_SS, N_pn, 2, 15, 0);
    else
        out_frac_a_demo = ones(1, length(BinaryData1_Short));
        trk_err_a_demo = zeros(1, length(BinaryData1_Short));
    end

    % Baseline B Demo (TRM + Std AKF)
    [out_frac_b_demo, ~, trk_err_b_demo, ~] = df_iakf_pll(sig_bb_trm_demo, mseq_ref, 401, length(BinaryData1_Short), len_SS, N_pn, 2, 15, 0);

    % Baseline C Demo (TRM + IAE-AKF)
    [out_frac_c_demo, ~, trk_err_c_demo, ~] = df_iakf_pll(sig_bb_trm_demo, mseq_ref, 401, length(BinaryData1_Short), len_SS, N_pn, 2, 15, 1);
    
    % Proposed D Demo (TRM + VB-AKF)
    [out_frac_d_demo, ~, trk_err_d_demo, ~] = vb_iakf_pll(sig_bb_trm_demo, mseq_ref, 401, length(BinaryData1_Short), len_SS, N_pn, 2, 1);
    
    fig_trk = figure('Name', ['追踪误差动态收敛轨迹 - ' ch_desc], 'Position', [300, 300, 850, 450], 'Visible', 'off');
    plot(trk_err_a_demo, 'k', 'LineWidth', 1.5); hold on;
    plot(trk_err_b_demo, 'm', 'LineWidth', 1.5);
    plot(trk_err_c_demo, 'b', 'LineWidth', 1.5);
    plot(trk_err_d_demo, 'r', 'LineWidth', 1.5);
    grid on; set(gca, 'YMinorGrid', 'on', 'XMinorGrid', 'on', 'GridAlpha', 0.4, 'FontSize', 12);
    title(sprintf('残余相位/时延追踪误差轨迹比对 (%s, SNR = %d dB)', ch_desc, SNR_demo), 'FontSize', 13, 'FontWeight', 'bold');
    xlabel('符号索引 (Symbol Index)', 'FontSize', 12, 'FontWeight', 'bold');
    ylabel('追踪误差状态估计', 'FontSize', 12, 'FontWeight', 'bold');
    legend({'Baseline A: No TRM + Std AKF', 'Baseline B: TRM + Std AKF', 'Baseline C: TRM + IAE-AKF (Heur)', 'Proposed: TRM + VB-AKF'}, 'FontSize', 11, 'Location', 'best');
    saveas(fig_trk, fullfile(plot_save_dir, 'Fig_Tracking_Error.png'));
    close(fig_trk);
    
    diff_a = out_frac_a_demo(2:end) .* conj(out_frac_a_demo(1:end-1));
    diff_b = out_frac_b_demo(2:end) .* conj(out_frac_b_demo(1:end-1));
    diff_c = out_frac_c_demo(2:end) .* conj(out_frac_c_demo(1:end-1));
    diff_d = out_frac_d_demo(2:end) .* conj(out_frac_d_demo(1:end-1));
    
    fig_const = figure('Name', ['软判决星座图 - ' ch_desc], 'Position', [350, 350, 1200, 300], 'Visible', 'off');
    
    subplot(1,4,1);
    scatter(real(diff_a), imag(diff_a), 20, 'k', 'filled', 'MarkerFaceAlpha', 0.6);
    grid on; title('Baseline A', 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('I'); ylabel('Q'); axis square; set(gca, 'XLim', [-2 2], 'YLim', [-2 2], 'FontSize', 10);
    
    subplot(1,4,2);
    scatter(real(diff_b), imag(diff_b), 20, 'm', 'filled', 'MarkerFaceAlpha', 0.6);
    grid on; title('Baseline B', 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('I'); ylabel('Q'); axis square; set(gca, 'XLim', [-2 2], 'YLim', [-2 2], 'FontSize', 10);
    
    subplot(1,4,3);
    scatter(real(diff_c), imag(diff_c), 20, 'b', 'filled', 'MarkerFaceAlpha', 0.6);
    grid on; title('Baseline C', 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('I'); ylabel('Q'); axis square; set(gca, 'XLim', [-2 2], 'YLim', [-2 2], 'FontSize', 10);
    
    subplot(1,4,4);
    scatter(real(diff_d), imag(diff_d), 20, 'r', 'filled', 'MarkerFaceAlpha', 0.6);
    grid on; title('Proposed D', 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('I'); ylabel('Q'); axis square; set(gca, 'XLim', [-2 2], 'YLim', [-2 2], 'FontSize', 10);
    saveas(fig_const, fullfile(plot_save_dir, 'Fig_Constellation.png'));
    close(fig_const);
end

%% 3. 最终汇总：绘制跨信道 VB-AKF 性能对比图
fprintf('\n========================================================================\n');
fprintf('所有信道测试完成，正在生成跨信道汇总图...\n');
fig_summary = figure('Name', '跨信道性能汇总 (Proposed D)', 'Position', [200, 200, 900, 600]);
colors = {'r', 'b', 'g', 'm', 'c'};
markers = {'p', 'o', '^', 's', 'd'};

for ch_idx = 1 : num_channels
    c_str = colors{mod(ch_idx-1, length(colors))+1};
    m_str = markers{mod(ch_idx-1, length(markers))+1};
    semilogy(SNR_range, max(all_channel_BER_D(ch_idx, :), 1e-6), ['-', c_str, m_str], ...
        'LineWidth', 2.5, 'MarkerSize', 9, 'MarkerFaceColor', c_str);
    hold on;
end

grid on; set(gca, 'YMinorGrid', 'on', 'XMinorGrid', 'on', 'GridAlpha', 0.4, 'FontSize', 12);
yline(1e-3, 'k--', 'LineWidth', 1.5, 'Label', '目标 10^{-3}');
title('TRM + VB-AKF 算法在多种 Bellhop 物理信道下的性能对比', 'FontSize', 14, 'FontWeight', 'bold');
xlabel('SNR (dB)', 'FontSize', 13, 'FontWeight', 'bold');
ylabel('Bit Error Rate (BER)', 'FontSize', 13, 'FontWeight', 'bold');

% 生成图例
leg_strs = cell(1, num_channels);
for ch_idx = 1 : num_channels
    leg_strs{ch_idx} = bellhop_channels{ch_idx, 2};
end
legend(leg_strs, 'Location', 'southwest', 'FontSize', 12);
ylim([1e-4, 1.0]); xlim([min(SNR_range), max(SNR_range)]);

saveas(fig_summary, fullfile(plot_save_dir_base, 'Fig_Summary_MultiChannel_BER.png'));
save(fullfile(plot_save_dir_base, 'Summary_MultiChannel_Data.mat'), 'SNR_range', 'bellhop_channels', 'all_channel_BER_D');
fprintf('汇总图表已保存至: %s\n', plot_save_dir_base);
fprintf('========================================================================\n');
