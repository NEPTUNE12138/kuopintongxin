function [decoded_bits, track_err_hist, runtime, meta] = run_paper2_receiver_variant(sig_bb, preamble, mseq_ref, cfg, variant)
% RUN_PAPER2_RECEIVER_VARIANT Unified wrapper for Paper 2 ablation baselines
% Inputs:
%   sig_bb   - Received baseband signal
%   preamble - HFM preamble waveform
%   mseq_ref - Upsampled m-sequence reference for correlation
%   cfg      - configuration struct
%   variant  - 'A', 'B', 'C', 'D', 'E'
%
% Variants:
% A - No TRM + IAE-AKF
% B - Conventional TRM (pure OS-CFAR) + IAE-AKF
% C - Hybrid TRM + IAE-AKF
% D - Hybrid TRM + Confidence-Gated IAE-AKF
% E - Hybrid TRM + HVB-AKF (Proposed)

    tic;
    
    %% 1. Preamble Synchronization & CIR Extraction
    % Matched filtering with preamble
    corr_out = xcorr(sig_bb, preamble);
    corr_out = corr_out(length(sig_bb):end); % Keep valid part
    
    [peak_val, peak_idx] = max(abs(corr_out));
    
    % Define CIR extraction window (e.g., -50 to +200 samples around peak)
    win_start = max(1, peak_idx - 50);
    win_end   = min(length(corr_out), peak_idx + 200);
    g_win = corr_out(win_start:win_end);
    
    % Default TRM filter is just a delta function (No TRM)
    q_filter = 1;
    trm_delay = 0;
    
    meta.variant = variant;
    
    if variant == 'A'
        % No TRM
        h_ext = zeros(size(g_win));
        [~, local_peak] = max(abs(g_win));
        h_ext(local_peak) = g_win(local_peak);
        q_filter = conj(fliplr(h_ext));
        trm_delay = length(h_ext) - 1;
    else
        % Extract CIR
        cfg_trm = cfg;
        if variant == 'B'
            cfg_trm.kappa_side = 0; % Disable ACF sidelobe threshold for pure OS-CFAR
        end
        
        [h_ext, gamma_os, gamma_acf, gamma_hybrid, mask, cir_meta] = extract_cir_hybrid(g_win, preamble, cfg_trm);
        
        if variant == 'B'
            % For variant B, force hybrid threshold to be just OS threshold
            h_ext = zeros(size(g_win));
            h_ext(abs(g_win) >= gamma_os) = g_win(abs(g_win) >= gamma_os);
        end
        
        q_filter = conj(fliplr(h_ext));
        trm_delay = length(h_ext) - 1;
        meta.cir_meta = cir_meta;
    end
    
    %% 2. Time-Reversal Pre-focusing
    if length(q_filter) > 1
        sig_bb_focused = filter(q_filter, 1, sig_bb);
    else
        sig_bb_focused = sig_bb;
    end
    
    % The new peak index after filtering will be delayed by trm_delay
    current_ptr = peak_idx + trm_delay + length(preamble); 
    % Note: +length(preamble) because the data usually starts after the preamble.
    % We might need a guard interval adjustment here if there is one.
    
    %% 3. DLL Tracking Loop Initialization
    num_syms = cfg.num_symbols + 1; % +1 for differential encoding reference
    len_SS = cfg.mseq_len;
    N_pn = cfg.N_pn;
    L_sym = len_SS * N_pn;
    delta = round(cfg.early_late_spacing * N_pn); % samples
    
    % Tracker states
    x_k = [0; 0];
    P_k = eye(2);
    Q_k = [0.05 0; 0 0.002];
    
    % HVB specific priors
    alpha_k = 2;
    beta_k = 0.1;
    
    % IAE specific
    R_k = 0.1;
    W_size = cfg.iae_window;
    innov_buffer = zeros(1, W_size);
    innov_idx = 1;
    
    track_err_hist = zeros(1, num_syms);
    u_k_history = zeros(1, num_syms);
    
    u_prev = 1; % Initialize for the first symbol's reliability calculation
    
    %% 4. Tracking & Despreading Loop
    for k = 1:num_syms
        % Predict phase offset
        F_mat = [1, cfg.symbol_dur; 0, 1];
        x_pre = F_mat * x_k;
        phase_off = round(x_pre(1));
        
        idx = current_ptr + phase_off;
        
        if (idx - delta < 1) || (idx + L_sym - 1 + delta > length(sig_bb_focused))
            break; % Out of bounds
        end
        
        % Early, Prompt, Late segments
        seg_P = sig_bb_focused(idx : idx + L_sym - 1);
        seg_E = sig_bb_focused(idx - delta : idx + L_sym - 1 - delta);
        seg_L = sig_bb_focused(idx + delta : idx + L_sym - 1 + delta);
        
        % Despread
        u_k = sum(seg_P .* mseq_ref) / L_sym;
        u_k_history(k) = u_k;
        
        E_pwr = abs(sum(seg_E .* mseq_ref))^2;
        L_pwr = abs(sum(seg_L .* mseq_ref))^2;
        
        % Discriminator
        D_k = (L_pwr - E_pwr) / (E_pwr + L_pwr + 1e-9);
        if abs(D_k) < 0.15
            D_k = 0; % Dead zone
        end
        
        z_k = D_k * delta;
        track_err_hist(k) = z_k;
        
        % Tracking Update
        if variant == 'E'
            % HVB-AKF
            [x_k, P_k, alpha_k, beta_k, Q_k, tracker_meta] = hvb_akf_delay_tracker(...
                z_k, u_k, u_prev, x_k, P_k, alpha_k, beta_k, Q_k, cfg);
            
            % Save meta
            meta.R_eff(k) = tracker_meta.R_eff;
            meta.K_gain(:, k) = tracker_meta.K_gain;
            meta.Lambda(k) = tracker_meta.Lambda_k;
            
        else
            % IAE-AKF Variants (A, B, C, D)
            H_mat = [1, 0];
            innov_buffer(innov_idx) = z_k;
            innov_idx = mod(innov_idx, W_size) + 1;
            
            if k > W_size
                C_k = var(innov_buffer) + 1e-6;
                R_est = C_k - H_mat * (F_mat * P_k * F_mat' + Q_k) * H_mat';
                R_k = max(0.01, 0.8 * R_k + 0.2 * R_est);
                
                % Confidence Gating for Variant D
                if variant == 'D'
                    m_k = abs(u_k * conj(u_prev));
                    penalty = 1 + 50 * exp(-2.5 * m_k);
                    R_k = R_k * penalty;
                end
                
                % Q adaptation
                P_pre = F_mat * P_k * F_mat' + Q_k;
                K_gain = P_pre * H_mat' / (H_mat * P_pre * H_mat' + R_k);
                
                Q_est = K_gain * C_k * K_gain';
                Q_est = diag(diag(Q_est));
                Q_k(1,1) = max(1e-4, 0.9 * Q_k(1,1) + 0.1 * Q_est(1,1));
                Q_k(2,2) = max(1e-4, 0.9 * Q_k(2,2) + 0.1 * Q_est(2,2));
            end
            
            P_pre = F_mat * P_k * F_mat' + Q_k;
            K_gain = P_pre * H_mat' / (H_mat * P_pre * H_mat' + R_k);
            
            x_k = x_pre + K_gain * (z_k - H_mat * x_pre);
            P_k = (eye(2) - K_gain * H_mat) * P_pre;
            
            meta.K_gain(:, k) = K_gain;
        end
        
        u_prev = u_k;
        current_ptr = current_ptr + L_sym;
    end
    
    % Truncate
    u_k_history = u_k_history(u_k_history ~= 0);
    track_err_hist = track_err_hist(1:length(u_k_history));
    
    %% 5. Differential Decoding
    if length(u_k_history) > 1
        raw_diff = u_k_history(2:end) .* conj(u_k_history(1:end-1));
        decoded_bits = real(raw_diff) > 0;
    else
        decoded_bits = [];
    end
    
    runtime = toc;
end
