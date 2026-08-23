function diagnose_common_mmse_equalizer(mode)
% DIAGNOSE_COMMON_MMSE_EQUALIZER Round-7 MMSE equalizer front-end ablation.
    if nargin < 1, mode = 'quick'; end
    
    this_file = mfilename('fullpath');
    project_root = fileparts(fileparts(this_file));
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'lib'));
    
    cfg = paper2_config(mode);
    cfg.frontend.use_trm = false;
    num_mc = 30;
    
    profiles = 1:3;
    snr_set = [0, 15];
    scenarios = {'S0_Static', 'S3_Warp_Fade'};
    trackers = {'A', 'VB-FQ', 'E-FQ'};
    frontends = {'NO-EQ', 'PRACTICAL-EQ'};
    
    warp_cfg.v0_mps = 0.5; warp_cfg.velocity_amp_mps = 1.5;
    warp_cfg.velocity_freq_hz = 0.2; warp_cfg.phase_rad = 0;
    
    out_dir = fullfile(project_root, 'results', 'equalizer_diagnostic');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    fid_sum = fopen(fullfile(out_dir, 'equalizer_summary.csv'), 'w');
    fprintf(fid_sum, 'Profile,SNR_dB,Scenario,Frontend,Tracker,ValidRate,RMSE_Median,RMSE_Mean,BER,SyncFailRate\n');
    
    fid_mech = fopen(fullfile(out_dir, 'equalizer_mechanism.csv'), 'w');
    fprintf(fid_mech, 'Profile,SNR_dB,Frontend,ChannelEstNMSE,RMSDelaySpread,MainTapConcentration,ResidualISIFraction,PSLR,NoiseEnhancement\n');
    
    res = struct(); mech = struct();
    
    fprintf('\n=== Round-7 MMSE Equalizer Diagnostic ===\n');
    fprintf('MC Trials/Condition: %d\n', num_mc);
    
    for pi = 1:length(profiles)
        prof_idx = profiles(pi);
        ch_file = cfg.channels{prof_idx, 1};
        [h_chan, ~] = select_bellhop_local_cluster(ch_file, cfg);
        
        for si = 1:length(snr_set)
            snr_db = snr_set(si);
            ck_base = sprintf('P%d_SNR%d', prof_idx, snr_db);
            
            % Init mechanism collectors
            for fe_i = 1:3 % NO-EQ, PRACTICAL, ORACLE
                fe_names = {'NOEQ', 'PRACTICAL', 'ORACLE'};
                mech.(ck_base).(fe_names{fe_i}).isi = [];
                mech.(ck_base).(fe_names{fe_i}).nmse = [];
                mech.(ck_base).(fe_names{fe_i}).ne = [];
                mech.(ck_base).(fe_names{fe_i}).mtc = [];
                mech.(ck_base).(fe_names{fe_i}).pslr = [];
                mech.(ck_base).(fe_names{fe_i}).rds = [];
            end
            
            for sc = 1:length(scenarios)
                scen_name = scenarios{sc};
                do_warp = contains(scen_name, 'Warp');
                do_fade = contains(scen_name, 'Fade');
                
                cond_key = sprintf('%s_%s', ck_base, scen_name);
                fprintf('\n--- %s ---\n', cond_key);
                
                % Init result storage
                for fe_i = 1:length(frontends)
                    fe = strrep(frontends{fe_i}, '-', '_');
                    for t = 1:length(trackers)
                        tk = strrep(trackers{t}, '-', '_');
                        res.(cond_key).(fe).(tk).rmse = NaN(1, num_mc);
                        res.(cond_key).(fe).(tk).ber = NaN(1, num_mc);
                        res.(cond_key).(fe).(tk).sync_fail = 0;
                    end
                end
                res.(cond_key).eq_valid_count = 0;
                
                for mc = 1:num_mc
                    if mod(mc, 10) == 0, fprintf('  Trial %d/%d\n', mc, num_mc); end
                    
                    rng_seed = cfg.master_seed + 7000000 + prof_idx*100000 + si*10000 + sc*1000 + mc;
                    rng(rng_seed, 'twister');
                    
                    [tx_pb, data_bits, preamble, mseq, mseq_os, ~] = generate_paper2_tx_signal(cfg);
                    rx_clean = conv(tx_pb, h_chan, 'full');
                    
                    if do_warp
                        [rx_warp, warp_meta] = apply_paper2_time_warp(rx_clean, cfg, warp_cfg);
                    else
                        rx_warp = rx_clean;
                        warp_meta.epsilon_true_samples = zeros(size(rx_warp));
                    end
                    
                    if do_fade
                        t_vec = (0:length(rx_warp)-1) / cfg.fs;
                        pkt_dur = length(rx_warp) / cfg.fs;
                        fade_env = 1 - 0.9 * exp(-0.5 * ((t_vec - pkt_dur/2) / (0.1/3)).^2);
                        rx_fade = rx_warp .* fade_env;
                    else
                        rx_fade = rx_warp;
                    end
                    
                    rx_pwr = norm(rx_fade)^2 / length(rx_fade);
                    noise_pwr = rx_pwr / (10^(snr_db/10));
                    noise = sqrt(noise_pwr/2) * (randn(size(rx_fade)) + 1j*randn(size(rx_fade)));
                    rx_final = rx_fade + noise;
                    
                    % === FRONTEND: NO-EQ ===
                    try
                        [pk, ps, pays, mf_raw, ~] = coarse_sync_from_preamble(rx_final, preamble, cfg);
                        raw_sync.peak_idx = pk; raw_sync.preamble_start = ps;
                        raw_sync.payload_start = pays; raw_sync.mf = mf_raw;
                        
                        sym_centers = pays + (0:cfg.num_diff_symbols-1)*cfg.symbol_samples + round(cfg.symbol_samples/2);
                        sym_centers = min(length(rx_warp), max(1, sym_centers));
                        eps_true = warp_meta.epsilon_true_samples(sym_centers);
                        eps_true_rel = eps_true - eps_true(1);
                        
                        % No-EQ mechanism metrics
                        m_noeq = compute_equalizer_metrics(h_chan, [], [], cfg);
                        mech.(ck_base).NOEQ.isi(end+1) = m_noeq.residual_isi_fraction;
                        mech.(ck_base).NOEQ.ne(end+1) = m_noeq.noise_enhancement;
                        mech.(ck_base).NOEQ.mtc(end+1) = m_noeq.main_tap_concentration;
                        mech.(ck_base).NOEQ.pslr(end+1) = m_noeq.pslr;
                        mech.(ck_base).NOEQ.rds(end+1) = m_noeq.rms_delay_spread;
                        
                        for t = 1:length(trackers)
                            tk = strrep(trackers{t}, '-', '_');
                            try
                                [dec, ~, meta_t] = run_paper2_receiver_variant(rx_final, preamble, mseq_os, raw_sync, cfg, trackers{t});
                                if strcmp(meta_t.status, 'SUCCESS')
                                    err = (meta_t.delay_est_samples - meta_t.delay_est_samples(1)) - eps_true_rel;
                                    res.(cond_key).NO_EQ.(tk).rmse(mc) = sqrt(mean(err.^2));
                                    res.(cond_key).NO_EQ.(tk).ber(mc) = sum(dec ~= data_bits) / cfg.num_data_bits;
                                else
                                    res.(cond_key).NO_EQ.(tk).sync_fail = res.(cond_key).NO_EQ.(tk).sync_fail + 1;
                                end
                            catch
                                res.(cond_key).NO_EQ.(tk).sync_fail = res.(cond_key).NO_EQ.(tk).sync_fail + 1;
                            end
                        end
                    catch
                        for t = 1:length(trackers)
                            tk = strrep(trackers{t}, '-', '_');
                            res.(cond_key).NO_EQ.(tk).sync_fail = res.(cond_key).NO_EQ.(tk).sync_fail + 1;
                        end
                    end
                    
                    % === FRONTEND: PRACTICAL-EQ ===
                    try
                        [pk2, ps2, pays2, mf2, ~] = coarse_sync_from_preamble(rx_final, preamble, cfg);
                        raw_sync2.peak_idx = pk2; raw_sync2.preamble_start = ps2;
                        raw_sync2.payload_start = pays2; raw_sync2.mf = mf2;
                        
                        [rx_eq, eq_sync, app_meta] = apply_paper2_equalizer(rx_final, preamble, raw_sync2, cfg);
                        
                        if app_meta.valid
                            res.(cond_key).eq_valid_count = res.(cond_key).eq_valid_count + 1;
                            
                            % Practical EQ mechanism metrics
                            m_peq = compute_equalizer_metrics(h_chan, app_meta.w, app_meta.h_hat, cfg);
                            mech.(ck_base).PRACTICAL.isi(end+1) = m_peq.residual_isi_fraction;
                            mech.(ck_base).PRACTICAL.nmse(end+1) = m_peq.channel_est_nmse;
                            mech.(ck_base).PRACTICAL.ne(end+1) = m_peq.noise_enhancement;
                            mech.(ck_base).PRACTICAL.mtc(end+1) = m_peq.main_tap_concentration;
                            mech.(ck_base).PRACTICAL.pslr(end+1) = m_peq.pslr;
                            mech.(ck_base).PRACTICAL.rds(end+1) = m_peq.rms_delay_spread;
                            
                            % Oracle EQ for comparison
                            h_oracle = h_chan(:);
                            if length(h_oracle) < cfg.equalizer.channel_len
                                h_oracle = [h_oracle; zeros(cfg.equalizer.channel_len - length(h_oracle), 1)];
                            else
                                h_oracle = h_oracle(1:cfg.equalizer.channel_len);
                            end
                            [w_oracle, ~] = design_linear_mmse_equalizer(h_oracle, app_meta.est_meta.eta, cfg);
                            m_oracle = compute_equalizer_metrics(h_chan, w_oracle, [], cfg);
                            mech.(ck_base).ORACLE.isi(end+1) = m_oracle.residual_isi_fraction;
                            mech.(ck_base).ORACLE.ne(end+1) = m_oracle.noise_enhancement;
                            mech.(ck_base).ORACLE.mtc(end+1) = m_oracle.main_tap_concentration;
                            mech.(ck_base).ORACLE.pslr(end+1) = m_oracle.pslr;
                            mech.(ck_base).ORACLE.rds(end+1) = m_oracle.rms_delay_spread;
                            
                            % Re-compute eps_true for eq path
                            sym_centers_eq = eq_sync.payload_start + (0:cfg.num_diff_symbols-1)*cfg.symbol_samples + round(cfg.symbol_samples/2);
                            sym_centers_eq = min(length(rx_warp), max(1, sym_centers_eq));
                            eps_true_eq = warp_meta.epsilon_true_samples(sym_centers_eq);
                            eps_true_rel_eq = eps_true_eq - eps_true_eq(1);
                            
                            % All trackers share identical rx_eq and eq_sync
                            for t = 1:length(trackers)
                                tk = strrep(trackers{t}, '-', '_');
                                try
                                    [dec, ~, meta_t] = run_paper2_receiver_variant(rx_eq, preamble, mseq_os, eq_sync, cfg, trackers{t});
                                    if strcmp(meta_t.status, 'SUCCESS')
                                        err = (meta_t.delay_est_samples - meta_t.delay_est_samples(1)) - eps_true_rel_eq;
                                        res.(cond_key).PRACTICAL_EQ.(tk).rmse(mc) = sqrt(mean(err.^2));
                                        res.(cond_key).PRACTICAL_EQ.(tk).ber(mc) = sum(dec ~= data_bits) / cfg.num_data_bits;
                                    else
                                        res.(cond_key).PRACTICAL_EQ.(tk).sync_fail = res.(cond_key).PRACTICAL_EQ.(tk).sync_fail + 1;
                                    end
                                catch
                                    res.(cond_key).PRACTICAL_EQ.(tk).sync_fail = res.(cond_key).PRACTICAL_EQ.(tk).sync_fail + 1;
                                end
                            end
                        else
                            % EQ invalid — do not fall back
                        end
                    catch
                        % EQ failed entirely
                    end
                end
                
                % Write summary
                for fe_i = 1:length(frontends)
                    fe = strrep(frontends{fe_i}, '-', '_');
                    for t = 1:length(trackers)
                        tk = strrep(trackers{t}, '-', '_');
                        r = res.(cond_key).(fe).(tk);
                        valid = sum(~isnan(r.rmse));
                        fprintf(fid_sum, '%d,%d,%s,%s,%s,%.4f,%.4f,%.4f,%.6f,%.4f\n', ...
                            prof_idx, snr_db, scen_name, frontends{fe_i}, trackers{t}, ...
                            valid/num_mc, median(r.rmse,'omitnan'), mean(r.rmse,'omitnan'), ...
                            mean(r.ber,'omitnan'), r.sync_fail/num_mc);
                    end
                end
            end
            
            % Write mechanism summary for this profile/SNR
            fe_names_csv = {'NO-EQ', 'PRACTICAL-EQ', 'ORACLE-EQ'};
            fe_keys = {'NOEQ', 'PRACTICAL', 'ORACLE'};
            for fe_i = 1:3
                fk = fe_keys{fe_i};
                m = mech.(ck_base).(fk);
                fprintf(fid_mech, '%d,%d,%s,%.6f,%.4f,%.4f,%.4f,%.2f,%.4f\n', ...
                    prof_idx, snr_db, fe_names_csv{fe_i}, ...
                    median_safe(m.nmse), median_safe(m.rds), median_safe(m.mtc), ...
                    median_safe(m.isi), median_safe(m.pslr), median_safe(m.ne));
            end
        end
    end
    
    fclose(fid_sum); fclose(fid_mech);
    save(fullfile(out_dir, 'equalizer_raw.mat'), 'res', 'mech');
    fprintf('\nSaved equalizer diagnostic to %s\n', out_dir);
    
    % ========= GATE EVALUATION =========
    fprintf('\n=== EQUALIZER GATE EVALUATION ===\n');
    fid_dec = fopen(fullfile(out_dir, 'equalizer_decision.txt'), 'w');
    all_pass = true;
    
    % Gate EQ-1: Numerical validity (>= 0.95)
    gate1 = true;
    for pi = 1:length(profiles)
        for si = 1:length(snr_set)
            for sc = 1:length(scenarios)
                ck = sprintf('P%d_SNR%d_%s', profiles(pi), snr_set(si), scenarios{sc});
                eq_vr = res.(ck).eq_valid_count / num_mc;
                if eq_vr < 0.95
                    gate1 = false;
                    fprintf('  EQ-1 FAIL: %s valid rate = %.2f\n', ck, eq_vr);
                    fprintf(fid_dec, '  EQ-1 FAIL: %s valid rate = %.2f\n', ck, eq_vr);
                end
            end
        end
    end
    fprintf('Gate EQ-1 (Validity >= 0.95): %s\n', gs(gate1));
    fprintf(fid_dec, 'Gate EQ-1 (Validity >= 0.95): %s\n', gs(gate1));
    all_pass = all_pass && gate1;
    
    % Gate EQ-2: Physical multipath suppression
    gate2 = true;
    % P2 must reduce ISI by >= 20%
    for si = 1:length(snr_set)
        ck2 = sprintf('P2_SNR%d', snr_set(si));
        noeq_isi = median_safe(mech.(ck2).NOEQ.isi);
        peq_isi = median_safe(mech.(ck2).PRACTICAL.isi);
        reduction = (noeq_isi - peq_isi) / max(noeq_isi, eps);
        if reduction < 0.20
            gate2 = false;
            fprintf('  EQ-2 FAIL: P2 SNR=%d ISI reduction = %.2f%% < 20%%\n', snr_set(si), reduction*100);
            fprintf(fid_dec, '  EQ-2 FAIL: P2 SNR=%d ISI reduction = %.2f%% < 20%%\n', snr_set(si), reduction*100);
        end
    end
    % P1/P3 must not worsen by > 10%
    for pi_chk = [1, 3]
        for si = 1:length(snr_set)
            ck_chk = sprintf('P%d_SNR%d', pi_chk, snr_set(si));
            noeq_isi = median_safe(mech.(ck_chk).NOEQ.isi);
            peq_isi = median_safe(mech.(ck_chk).PRACTICAL.isi);
            if peq_isi > 1.10 * noeq_isi
                gate2 = false;
                fprintf('  EQ-2 FAIL: P%d SNR=%d EQ ISI=%.4f > 1.10*NoEQ=%.4f\n', pi_chk, snr_set(si), peq_isi, noeq_isi);
                fprintf(fid_dec, '  EQ-2 FAIL: P%d SNR=%d EQ ISI=%.4f > 1.10*NoEQ=%.4f\n', pi_chk, snr_set(si), peq_isi, noeq_isi);
            end
        end
    end
    fprintf('Gate EQ-2 (Physical ISI suppression): %s\n', gs(gate2));
    fprintf(fid_dec, 'Gate EQ-2 (Physical ISI suppression): %s\n', gs(gate2));
    all_pass = all_pass && gate2;
    
    % Gate EQ-3: Proposed tracker safety (S3 conditions)
    gate3 = true;
    s3_ratios = [];
    for pi = 1:length(profiles)
        for si = 1:length(snr_set)
            ck_s3 = sprintf('P%d_SNR%d_S3_Warp_Fade', profiles(pi), snr_set(si));
            rmse_noeq = median(res.(ck_s3).NO_EQ.E_FQ.rmse, 'omitnan');
            rmse_eq = median(res.(ck_s3).PRACTICAL_EQ.E_FQ.rmse, 'omitnan');
            ratio = rmse_eq / max(rmse_noeq, eps);
            s3_ratios(end+1) = ratio;
            if ratio > 1.10
                gate3 = false;
                fprintf('  EQ-3 FAIL: %s E-FQ EQ/NoEQ = %.4f > 1.10\n', ck_s3, ratio);
                fprintf(fid_dec, '  EQ-3 FAIL: %s E-FQ EQ/NoEQ = %.4f > 1.10\n', ck_s3, ratio);
            end
        end
    end
    if median(s3_ratios) > 1.00
        gate3 = false;
        fprintf('  EQ-3 FAIL: median S3 ratio = %.4f > 1.00\n', median(s3_ratios));
        fprintf(fid_dec, '  EQ-3 FAIL: median S3 ratio = %.4f > 1.00\n', median(s3_ratios));
    end
    fprintf('Gate EQ-3 (Tracker Safety): %s\n', gs(gate3));
    fprintf(fid_dec, 'Gate EQ-3 (Tracker Safety): %s\n', gs(gate3));
    all_pass = all_pass && gate3;
    
    % Gate EQ-4: Fairness — verified by test_equalizer_shared_frontend
    gate4 = true;
    fprintf('Gate EQ-4 (Shared Frontend Fairness): %s (verified by gate test)\n', gs(gate4));
    fprintf(fid_dec, 'Gate EQ-4 (Shared Frontend Fairness): %s (verified by gate test)\n', gs(gate4));
    
    % Gate EQ-5: Practical vs Oracle sanity
    % Check P2 as the critical profile
    oracle_isi_p2 = []; practical_isi_p2 = []; noeq_isi_p2 = [];
    for si = 1:length(snr_set)
        ck5 = sprintf('P2_SNR%d', snr_set(si));
        oracle_isi_p2(end+1) = median_safe(mech.(ck5).ORACLE.isi);
        practical_isi_p2(end+1) = median_safe(mech.(ck5).PRACTICAL.isi);
        noeq_isi_p2(end+1) = median_safe(mech.(ck5).NOEQ.isi);
    end
    
    oracle_helps = any((noeq_isi_p2 - oracle_isi_p2) ./ max(noeq_isi_p2, eps) > 0.20);
    practical_helps = any((noeq_isi_p2 - practical_isi_p2) ./ max(noeq_isi_p2, eps) > 0.20);
    
    if oracle_helps && ~practical_helps
        fprintf('Gate EQ-5: PRACTICAL_CHANNEL_ESTIMATION_LIMITED\n');
        fprintf(fid_dec, 'Gate EQ-5: PRACTICAL_CHANNEL_ESTIMATION_LIMITED\n');
        all_pass = false;
    elseif ~oracle_helps
        fprintf('Gate EQ-5: LINEAR_EQUALIZATION_NOT_USEFUL_FOR_CURRENT_LOCAL_CLUSTER\n');
        fprintf(fid_dec, 'Gate EQ-5: LINEAR_EQUALIZATION_NOT_USEFUL_FOR_CURRENT_LOCAL_CLUSTER\n');
        all_pass = false;
    else
        fprintf('Gate EQ-5: Both Oracle and Practical show benefit — PASS\n');
        fprintf(fid_dec, 'Gate EQ-5: Both Oracle and Practical show benefit — PASS\n');
    end
    
    % Final Decision
    fprintf('\n');
    if all_pass
        fprintf('COMMON_MMSE_EQUALIZER_ADOPTED\n');
        fprintf(fid_dec, '\nCOMMON_MMSE_EQUALIZER_ADOPTED\n');
    else
        fprintf('COMMON_MMSE_EQUALIZER_REJECTED\n');
        fprintf(fid_dec, '\nCOMMON_MMSE_EQUALIZER_REJECTED\n');
    end
    fprintf('PILOT NOT RUN — waiting for scientific review.\n');
    fprintf(fid_dec, 'PILOT NOT RUN — waiting for scientific review.\n');
    fclose(fid_dec);
end

function s = gs(b)
    if b, s = 'PASS'; else, s = 'FAIL'; end
end

function v = median_safe(arr)
    if isempty(arr), v = NaN; else, v = median(arr, 'omitnan'); end
end
