function [decoded_bits, runtime, meta] = run_paper2_receiver_variant(sig_pb, preamble, mseq_ref, sync_meta, cfg, variant_char)
% RUN_PAPER2_RECEIVER_VARIANT Unified wrapper for Paper 2 receivers.

    tic;
    meta = struct();
    meta.status = 'SUCCESS';
    meta.failure_reason = '';
    meta.variant = variant_char;
    
    try
        % 1. Configuration and Definitions
        var_def = paper2_variant_definition(variant_char);
        
        if strcmp(variant_char, 'E-VB-only')
            cfg.hvb.use_heteroscedastic = false;
            cfg.hvb.use_q_freeze = false;
        end
        
        if strcmp(variant_char, 'E-FQ')
            cfg.hvb.q_adaptation_mode = 'fixed';
            cfg.reliability.mode = 'relative_calibrated';
            cfg.hvb.use_heteroscedastic = true;
            % We leave Q initialized at [0.05 0; 0 0.002] and c2 unchanged (done in confirm script)
        end
        
        if strcmp(variant_char, 'VB-FQ')
            cfg.hvb.q_adaptation_mode = 'fixed';
            cfg.hvb.use_heteroscedastic = false;
            cfg.reliability.mode = 'none'; % Enforce disabled
        end

        if strcmp(variant_char, 'R-FQ')
            cfg.reliability.mode = 'relative_calibrated';
        end
        
        % Check for global frontend TRM override
        if isfield(cfg, 'frontend') && isfield(cfg.frontend, 'use_trm') && ~cfg.frontend.use_trm
            var_def.uses_trm = false;
        end
        
        % 2. CIR Extraction (using same coarse sync peak)
        peak_idx = sync_meta.peak_idx;
        [g_win, win_start, win_end] = extract_mf_local_window(sync_meta.mf, peak_idx, 50, 200);
        
        if ~var_def.uses_trm
            q_filter = 1;
            trm_group_delay = 0;
            meta.cir_meta = struct();
        else
            cfg_trm = cfg;
            if ~var_def.uses_hybrid
                cfg_trm.kappa_side = 0; % Force OS-CFAR only
            end
            
            [h_ext, ~, ~, ~, ~, cir_meta] = extract_cir_hybrid(g_win, preamble, cfg_trm);
            
            [q_filter, trm_group_delay, is_valid] = build_tr_filter(h_ext);
            if ~is_valid
                error('Paper2:SyncFail', 'TRM filter extraction failed (all zeros).');
            end
            meta.cir_meta = cir_meta;
        end
        
        % 3. Time-Reversal Pre-focusing
        if length(q_filter) > 1
            sig_focused = filter(q_filter, 1, sig_pb);
            offset_from_peak = peak_idx - win_start;
            trm_group_delay_true = trm_group_delay - offset_from_peak;
        else
            sig_focused = sig_pb;
            trm_group_delay_true = 0;
        end
        
        payload_start_focused = sync_meta.payload_start + trm_group_delay_true;
        
        % Downconvert focused signal to baseband. 
        % In TX, the payload phase is 0 at the start of the payload.
        t_down = ((1:length(sig_focused)) - payload_start_focused) / cfg.fs;
        sig_focused_bb = sig_focused .* exp(-1j * 2 * pi * cfg.fc * t_down);
        
        current_ptr = payload_start_focused;
        
        % 4. DLL Tracking Loop Initialization
        num_syms = cfg.num_diff_symbols;
        L_sym = cfg.symbol_samples;
        delta = round(0.5 * cfg.samples_per_chip); 
        
        x_k = [0; 0];
        P_k = eye(2);
        Q_k = [0.05 0; 0 0.002];
        
        alpha_k = 2; beta_k = 0.1;
        R_iae = 0.1;
        
        W_size = cfg.W_size;
        innov_buffer = zeros(1, W_size);
        innov_idx = 1;
        
        u_prev = 1; 
        rho_prev = 1;
        
        % Meta history initialization
        meta.num_processed_symbols = 0;
        meta.u_prompt = zeros(1, num_syms);
        meta.delay_measurement_z = zeros(1, num_syms);
        meta.delay_est_samples = zeros(1, num_syms);
        meta.delay_drift_est = zeros(1, num_syms);
        meta.K_gain = zeros(2, num_syms);
        meta.R_vb = zeros(1, num_syms);
        meta.R_eff = zeros(1, num_syms);
        meta.rho = zeros(1, num_syms);
        meta.m_reliability = zeros(1, num_syms);
        meta.Lambda = zeros(1, num_syms);
        meta.Q_diag = zeros(2, num_syms);
        
        meta.innovation = zeros(1, num_syms);
        meta.abs_innovation = zeros(1, num_syms);
        meta.NIS = zeros(1, num_syms);
        meta.directional_consistency = zeros(1, num_syms);
        meta.coherent_fraction = zeros(1, num_syms);
        
        meta.S = zeros(1, num_syms);
        meta.P_pred_diag = zeros(2, num_syms);
        
        W_innov = 5;
        innov_hist = zeros(1, W_innov);
        innov_hist_idx = 1;
        innov_count = 0;
        
        is_cal = strcmp(variant_char, 'E-CAL') || strcmp(variant_char, 'E-FQ') || ...
                 strcmp(variant_char, 'R-FQ') || ...
                 (strcmp(variant_char, 'E') && isfield(cfg, 'final_tracker_variant') && strcmp(cfg.final_tracker_variant, 'E-CAL'));
        if is_cal
            if isfield(cfg, 'reliability') && isfield(cfg.reliability, 'calibration_symbols')
                Kcal = cfg.reliability.calibration_symbols;
            else
                Kcal = 8;
            end
            rho_raw_buffer = zeros(1, Kcal);
            meta.rho_raw = zeros(1, num_syms);
            meta.rho_ref = NaN;
            meta.rho_relative = zeros(1, num_syms);
        end
        
        % 5. Tracking & Despreading Loop
        for k = 1:num_syms
            % Predict
            F_mat = [1 1; 0 1];
            x_pre = F_mat * x_k;
            phase_off = round(x_pre(1));
            
            idx = current_ptr + phase_off;
            
            if (idx - delta < 1) || (idx + L_sym - 1 + delta > length(sig_focused_bb))
                break; % Out of bounds
            end
            
            seg_P = sig_focused_bb(idx : idx + L_sym - 1);
            seg_E = sig_focused_bb(idx - delta : idx + L_sym - 1 - delta);
            seg_L = sig_focused_bb(idx + delta : idx + L_sym - 1 + delta);
            
            % Despread
            u_k = sum(seg_P .* conj(mseq_ref)) / L_sym;
            
            E_pwr = abs(sum(seg_E .* conj(mseq_ref)))^2;
            L_pwr = abs(sum(seg_L .* conj(mseq_ref)))^2;
            
            D_k = (L_pwr - E_pwr) / (E_pwr + L_pwr + 1e-9);
            z_res = D_k * delta;
            z_abs = x_pre(1) + z_res;
            
            % Normalized Reliability
            corr_p = sum(seg_P .* conj(mseq_ref));
            rho_raw_k = abs(corr_p) / sqrt(sum(abs(seg_P).^2) * sum(abs(mseq_ref).^2) + eps);
            rho_raw_k = min(max(rho_raw_k, 0), 1);
            
            if is_cal
                meta.rho_raw(k) = rho_raw_k;
                if k <= Kcal
                    rho_raw_buffer(k) = rho_raw_k;
                    rho_k = rho_raw_k;
                    meta.rho_relative(k) = rho_k;
                    
                    % During calibration: disable penalty and freeze
                    cfg.hvb.use_heteroscedastic = false;
                    cfg.hvb.use_q_freeze = false;
                else
                    if k == Kcal + 1
                        meta.rho_ref = median(rho_raw_buffer);
                        % Re-enable penalty and freeze
                        cfg.hvb.use_heteroscedastic = true;
                        cfg.hvb.use_q_freeze = true;
                        % Transition rho_prev to relative scale BEFORE computing m_k
                        rho_prev = min(1, rho_prev / max(meta.rho_ref, eps));
                    end
                    rho_rel = min(1, rho_raw_k / max(meta.rho_ref, eps));
                    rho_k = rho_rel;
                    meta.rho_relative(k) = rho_k;
                end
            else
                rho_k = rho_raw_k;
            end
            
            if k == 1
                rho_prev = rho_k;
            end
            m_k = sqrt(rho_k * rho_prev);
            
            % Save to meta
            meta.u_prompt(k) = u_k;
            meta.delay_measurement_z(k) = z_abs;
            meta.rho(k) = rho_k;
            meta.m_reliability(k) = m_k;
            
            % Filter Update
            if var_def.uses_reliability_only
                R0 = 0.05; % Same fixed measurement covariance as KF-FQ.
                [x_k, tracker_meta] = reliability_only_delay_tracker(...
                    z_abs, m_k, x_k, P_k, R0, cfg.c2);
                P_k = tracker_meta.P_post;

                meta.R_vb(k) = R0; % Baseline covariance for ratio telemetry.
                meta.R_eff(k) = tracker_meta.R_eff;
                meta.K_gain(:, k) = tracker_meta.K_gain;
                meta.Lambda(k) = tracker_meta.Lambda_k;
                meta.Q_diag(:, k) = tracker_meta.Q_diag;

                meta.innovation(k) = tracker_meta.innovation;
                meta.abs_innovation(k) = abs(tracker_meta.innovation);
                meta.NIS(k) = tracker_meta.NIS;
                meta.S(k) = tracker_meta.S;
                meta.P_pred_diag(:, k) = tracker_meta.P_pred_diag;

                innov_hist(innov_hist_idx) = tracker_meta.innovation;
                innov_hist_idx = mod(innov_hist_idx, W_innov) + 1;
                innov_count = min(innov_count + 1, W_innov);

                if innov_count == W_innov
                    d_k = abs(sum(innov_hist)) / (sum(abs(innov_hist)) + eps);
                    mu_nu = mean(innov_hist);
                    var_nu = var(innov_hist, 1);
                    meta.directional_consistency(k) = d_k;
                    meta.coherent_fraction(k) = mu_nu^2 / (mu_nu^2 + var_nu + eps);
                else
                    meta.directional_consistency(k) = NaN;
                    meta.coherent_fraction(k) = NaN;
                end
            elseif var_def.uses_vb
                [x_k, P_k, alpha_k, beta_k, Q_k, tracker_meta] = hvb_akf_delay_tracker(...
                    z_abs, u_k, u_prev, m_k, x_k, P_k, alpha_k, beta_k, Q_k, cfg);
                
                meta.R_vb(k) = tracker_meta.R_vb;
                meta.R_eff(k) = tracker_meta.R_eff;
                meta.K_gain(:, k) = tracker_meta.K_gain;
                meta.Lambda(k) = tracker_meta.Lambda_k;
                meta.Q_diag(:, k) = tracker_meta.Q_diag;
                
                meta.innovation(k) = tracker_meta.innovation;
                meta.abs_innovation(k) = abs(tracker_meta.innovation);
                meta.NIS(k) = tracker_meta.NIS;
                meta.S(k) = tracker_meta.S;
                meta.P_pred_diag(:, k) = tracker_meta.P_pred_diag;
                
                innov_hist(innov_hist_idx) = tracker_meta.innovation;
                innov_hist_idx = mod(innov_hist_idx, W_innov) + 1;
                innov_count = min(innov_count + 1, W_innov);
                
                if innov_count == W_innov
                    d_k = abs(sum(innov_hist)) / (sum(abs(innov_hist)) + eps);
                    mu_nu = mean(innov_hist);
                    var_nu = var(innov_hist, 1); % biased variance as per specification
                    coh_frac = mu_nu^2 / (mu_nu^2 + var_nu + eps);
                    
                    meta.directional_consistency(k) = d_k;
                    meta.coherent_fraction(k) = coh_frac;
                else
                    meta.directional_consistency(k) = NaN;
                    meta.coherent_fraction(k) = NaN;
                end
            else
                H_mat = [1 0];
                innov_buffer(innov_idx) = z_res;
                innov_idx = mod(innov_idx, W_size) + 1;
                
                if k > W_size && ~var_def.uses_kf_fq
                    C_k = var(innov_buffer) + 1e-6;
                    R_est = C_k - H_mat * (F_mat * P_k * F_mat' + Q_k) * H_mat';
                    R_iae = max(0.01, 0.8 * R_iae + 0.2 * R_est);
                    
                    Q_pre = F_mat * P_k * F_mat' + Q_k;
                    K_gain_est = Q_pre * H_mat' / (H_mat * Q_pre * H_mat' + R_iae);
                    Q_est = K_gain_est * C_k * K_gain_est';
                    Q_k(1,1) = max(1e-4, 0.9 * Q_k(1,1) + 0.1 * Q_est(1,1));
                    Q_k(2,2) = max(1e-4, 0.9 * Q_k(2,2) + 0.1 * Q_est(2,2));
                elseif var_def.uses_kf_fq
                    R_iae = 0.05;
                end
                
                R_eff = R_iae;
                if var_def.uses_reliability
                    penalty = 1 + cfg.var_D_A * exp(-cfg.var_D_b * m_k);
                    R_eff = max(R_iae, R_iae * penalty);
                end
                
                P_pre = F_mat * P_k * F_mat' + Q_k;
                K_gain = P_pre * H_mat' / (H_mat * P_pre * H_mat' + R_eff);
                
                x_k = x_pre + K_gain * (z_abs - H_mat * x_pre);
                P_k = (eye(2) - K_gain * H_mat) * P_pre;
                
                meta.R_vb(k) = R_iae;
                meta.R_eff(k) = R_eff;
                meta.K_gain(:, k) = K_gain;
                meta.Lambda(k) = R_eff / max(R_iae, eps);
                meta.Q_diag(:, k) = diag(Q_k);
                
                innov_k = z_abs - H_mat * x_pre;
                meta.innovation(k) = innov_k;
                meta.abs_innovation(k) = abs(innov_k);
                S_k = H_mat * P_pre * H_mat' + R_eff;
                meta.NIS(k) = innov_k^2 / max(S_k, eps);
                meta.S(k) = S_k;
                meta.P_pred_diag(:, k) = diag(P_pre);
                
                innov_hist(innov_hist_idx) = innov_k;
                innov_hist_idx = mod(innov_hist_idx, W_innov) + 1;
                innov_count = min(innov_count + 1, W_innov);
                
                if innov_count == W_innov
                    d_k = abs(sum(innov_hist)) / (sum(abs(innov_hist)) + eps);
                    mu_nu = mean(innov_hist);
                    var_nu = var(innov_hist, 1);
                    coh_frac = mu_nu^2 / (mu_nu^2 + var_nu + eps);
                    
                    meta.directional_consistency(k) = d_k;
                    meta.coherent_fraction(k) = coh_frac;
                else
                    meta.directional_consistency(k) = NaN;
                    meta.coherent_fraction(k) = NaN;
                end
            end
            
            meta.delay_est_samples(k) = x_k(1);
            meta.delay_drift_est(k) = x_k(2);
            meta.num_processed_symbols = k;
            
            u_prev = u_k;
            rho_prev = rho_k;
            current_ptr = current_ptr + L_sym;
        end
        
        if meta.num_processed_symbols < num_syms
            error('Paper2:SyncFail', 'Packet tracking lost/out of bounds prematurely.');
        end
        
        % 6. Differential Decoding
        raw_diff = meta.u_prompt(2:end) .* conj(meta.u_prompt(1:end-1));
        decoded_bits = real(raw_diff) > 0;
        
    catch ME
        if strcmp(ME.identifier, 'Paper2:SyncFail')
            meta.status = 'SYNC_FAIL';
            meta.failure_reason = ME.message;
            decoded_bits = [];
        else
            rethrow(ME); % Crash on unexpected errors
        end
    end
    
    runtime = toc;
end
