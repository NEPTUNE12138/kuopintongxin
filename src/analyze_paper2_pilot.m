function analyze_paper2_pilot()
% ANALYZE_PAPER2_PILOT Reads Pilot MAT files and performs all fixed analyses.

    % 1. Find raw MAT files in results/pilot/
    pilot_dir = fullfile('results', 'pilot');
    val_files = dir(fullfile(pilot_dir, 'paper2_ber_validation_*.mat'));
    stress_files = dir(fullfile(pilot_dir, 'paper2_stress_pilot_*.mat'));
    
    if isempty(val_files) || isempty(stress_files)
        error('Cannot find Pilot MAT files in results/pilot/');
    end
    
    % Sort by date (latest first)
    [~, idx_v] = sort([val_files.datenum], 'descend');
    val_mat = fullfile(pilot_dir, val_files(idx_v(1)).name);
    
    [~, idx_s] = sort([stress_files.datenum], 'descend');
    stress_mat = fullfile(pilot_dir, stress_files(idx_s(1)).name);
    
    fprintf('Loading Pilot Validation MAT: %s\n', val_mat);
    D_val = load(val_mat);
    fprintf('Loading Pilot Stress MAT: %s\n', stress_mat);
    D_stress = load(stress_mat);
    
    out_dir = fullfile('results', 'pilot_review');
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end
    
    %% --- 1. Generate pilot_raw_index.txt ---
    fid_i = fopen(fullfile(out_dir, 'pilot_raw_index.txt'), 'w');
    fprintf(fid_i, 'Pilot Validation Raw MAT: %s\n', val_mat);
    fprintf(fid_i, 'Pilot Stress Raw MAT: %s\n', stress_mat);
    fclose(fid_i);
    
    %% --- 2. Generate pilot_ber_summary.csv ---
    csv_ber = fullfile(out_dir, 'pilot_ber_summary.csv');
    fid_b = fopen(csv_ber, 'w');
    fprintf(fid_b, 'Profile,SNR_dB,Variant,Trials_Total,Trials_Valid,ReceiverFailCount,ReceiverFailRate,BitErrors_Valid,Bits_Valid,BER_Valid,BER_Wilson_Lower,BER_Wilson_Upper,FrameErrors_Valid,FER_Valid,FrameErrors_Overall,FER_Overall,FER_Wilson_Lower,FER_Wilson_Upper\n');
    
    num_ch = size(D_val.cfg.channels, 1);
    num_snr = length(D_val.cfg.snr_range);
    num_v = length(D_val.variants);
    
    for ch = 1:num_ch
        ch_name = D_val.cfg.channels{ch, 2};
        for v = 1:num_v
            var_name = D_val.csv_labels{v};
            for s = 1:num_snr
                snr_db = D_val.cfg.snr_range(s);
                errs = squeeze(D_val.raw_errors(ch, s, v, :))';
                valid = ~isnan(errs);
                stats = compute_paper2_ber_statistics(errs, valid, D_val.cfg.num_data_bits);
                
                fprintf(fid_b, '%s,%d,%s,%d,%d,%d,%.4f,%d,%d,%.6f,%.6f,%.6f,%d,%.4f,%d,%.4f,%.6f,%.6f\n', ...
                    ch_name, snr_db, var_name, stats.Trials_Total, stats.Trials_Valid, ...
                    stats.SyncFailCount, stats.SyncFailRate, stats.BitErrors_Valid, stats.Bits_Valid, ...
                    stats.BER_Valid, stats.Wilson_Lower_ValidBER, stats.Wilson_Upper_ValidBER, ...
                    stats.FrameErrors_Valid, stats.FER_Valid, stats.FrameErrors_Overall, stats.FER_Overall, ...
                    stats.Wilson_Lower_OverallFER, stats.Wilson_Upper_OverallFER);
            end
        end
    end
    fclose(fid_b);
    
    %% --- 3. Generate pilot_stress_summary.csv & pilot_mechanism_table.csv ---
    csv_s = fullfile(out_dir, 'pilot_stress_summary.csv');
    fid_s = fopen(csv_s, 'w');
    fprintf(fid_s, 'Profile,Variant,Trials_Total,Trials_Valid,ValidRate,ReceiverFailRate,BER_Valid,FER_Overall,RMSE_Overall_Median,RMSE_PRE_Median,RMSE_FADE_Median,RMSE_POST_Median,RMSE_Overall_P10,RMSE_Overall_P90,RMSE_FADE_P10,RMSE_FADE_P90,Median_m_PRE,Median_m_FADE,Median_m_POST,Median_Reff_Rvb_PRE,Median_Reff_Rvb_FADE,Median_Reff_Rvb_POST,Median_K_PRE,Median_K_FADE,Median_K_POST,Median_Q11,Median_Q22\n');
    
    csv_m = fullfile(out_dir, 'pilot_mechanism_table.csv');
    fid_m = fopen(csv_m, 'w');
    fprintf(fid_m, 'Profile,Variant,Median_m_PRE,Median_m_FADE,Median_m_POST,Median_Reff_Rvb_PRE,Median_Reff_Rvb_FADE,Median_Reff_Rvb_POST,Median_K_PRE,Median_K_FADE,Median_K_POST,Median_Q11_PRE,Median_Q11_FADE,Median_Q11_POST,Median_Q22_PRE,Median_Q22_FADE,Median_Q22_POST\n');
    
    for ch = 1:num_ch
        ch_name = D_stress.cfg.channels{ch, 2};
        ch_key = sprintf('CH%d', ch);
        for v = 1:num_v
            var_name = D_stress.csv_labels{v};
            vc_key = strrep(D_stress.variants{v}, '-', '_');
            
            res = D_stress.results.(ch_key).(vc_key);
            valid_mask = res.valid;
            stats = compute_paper2_ber_statistics(res.raw_errors, valid_mask, D_stress.cfg.num_data_bits);
            
            % Compute metrics
            val_rate = stats.Trials_Valid / stats.Trials_Total;
            fail_rate = stats.SyncFailRate; % Renamed ReceiverFailRate in CSV output
            
            rm_o = prctile(res.rmse_overall(valid_mask), [10, 50, 90]);
            rm_f = prctile(res.rmse_fade(valid_mask), [10, 50, 90]);
            
            rm_pre = median(res.rmse_pre(valid_mask), 'omitnan');
            rm_post = median(res.rmse_post(valid_mask), 'omitnan');
            
            m_m_pre = NaN; m_m_fade = NaN; m_m_post = NaN;
            m_rr_pre = NaN; m_rr_fade = NaN; m_rr_post = NaN;
            m_k_pre = NaN; m_k_fade = NaN; m_k_post = NaN;
            m_q11 = NaN; m_q22 = NaN;
            
            if isfield(res, 'm_pre'), m_m_pre = median(res.m_pre(valid_mask), 'omitnan'); end
            if isfield(res, 'm_fade'), m_m_fade = median(res.m_fade(valid_mask), 'omitnan'); end
            if isfield(res, 'm_post'), m_m_post = median(res.m_post(valid_mask), 'omitnan'); end
            
            if isfield(res, 'mean_Reff_Rvb_pre'), m_rr_pre = median(res.mean_Reff_Rvb_pre(valid_mask), 'omitnan'); end
            if isfield(res, 'mean_Reff_Rvb_fade'), m_rr_fade = median(res.mean_Reff_Rvb_fade(valid_mask), 'omitnan'); end
            if isfield(res, 'mean_Reff_Rvb_post'), m_rr_post = median(res.mean_Reff_Rvb_post(valid_mask), 'omitnan'); end
            
            if isfield(res, 'mean_K_pre'), m_k_pre = median(res.mean_K_pre(valid_mask), 'omitnan'); end
            if isfield(res, 'mean_K_fade'), m_k_fade = median(res.mean_K_fade(valid_mask), 'omitnan'); end
            if isfield(res, 'mean_K_post'), m_k_post = median(res.mean_K_post(valid_mask), 'omitnan'); end
            
            if isfield(res, 'Q11_fade'), m_q11 = median(res.Q11_fade(valid_mask), 'omitnan'); end
            if isfield(res, 'Q22_fade'), m_q22 = median(res.Q22_fade(valid_mask), 'omitnan'); end
            
            m_q11_pre = NaN; m_q11_post = NaN;
            m_q22_pre = NaN; m_q22_post = NaN;
            if isfield(res, 'Q11_pre'), m_q11_pre = median(res.Q11_pre(valid_mask), 'omitnan'); end
            if isfield(res, 'Q11_post'), m_q11_post = median(res.Q11_post(valid_mask), 'omitnan'); end
            if isfield(res, 'Q22_pre'), m_q22_pre = median(res.Q22_pre(valid_mask), 'omitnan'); end
            if isfield(res, 'Q22_post'), m_q22_post = median(res.Q22_post(valid_mask), 'omitnan'); end
            
            fprintf(fid_s, '%s,%s,%d,%d,%.4f,%.4f,%.6f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
                ch_name, var_name, stats.Trials_Total, stats.Trials_Valid, val_rate, fail_rate, ...
                stats.BER_Valid, stats.FER_Overall, rm_o(2), rm_pre, rm_f(2), rm_post, ...
                rm_o(1), rm_o(3), rm_f(1), rm_f(3), ...
                m_m_pre, m_m_fade, m_m_post, m_rr_pre, m_rr_fade, m_rr_post, ...
                m_k_pre, m_k_fade, m_k_post, m_q11, m_q22);
                
            fprintf(fid_m, '%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
                ch_name, var_name, m_m_pre, m_m_fade, m_m_post, m_rr_pre, m_rr_fade, m_rr_post, ...
                m_k_pre, m_k_fade, m_k_post, m_q11_pre, m_q11, m_q11_post, m_q22_pre, m_q22, m_q22_post);
        end
    end
    fclose(fid_s);
    fclose(fid_m);
    
    %% --- 4. Generate pilot_tracking_paired_bootstrap.csv ---
    csv_bs = fullfile(out_dir, 'pilot_tracking_paired_bootstrap.csv');
    fid_bs = fopen(csv_bs, 'w');
    fprintf(fid_bs, 'Profile,Comparison,Metric,N_Paired,Median_Difference,CI95_Lower,CI95_Upper,WinRate_EFQ,Median_Ratio\n');
    
    rng(20260909, 'twister');
    n_boot = 10000;
    
    metrics = {'rmse_overall', 'rmse_fade'};
    metric_labels = {'Overall_RMSE', 'Fade_RMSE'};
    
    var_idx_efq = find(strcmp(D_stress.csv_labels, 'E-FQ'));
    var_idx_iae = find(strcmp(D_stress.csv_labels, 'IAE'));
    var_idx_vbfq = find(strcmp(D_stress.csv_labels, 'VB-FQ'));
    
    vc_efq = strrep(D_stress.variants{var_idx_efq}, '-', '_');
    vc_iae = strrep(D_stress.variants{var_idx_iae}, '-', '_');
    vc_vbfq = strrep(D_stress.variants{var_idx_vbfq}, '-', '_');
    
    for ch = 1:num_ch
        ch_name = D_stress.cfg.channels{ch, 2};
        ch_key = sprintf('CH%d', ch);
        
        for m = 1:length(metrics)
            met = metrics{m};
            mlbl = metric_labels{m};
            
            val_efq = D_stress.results.(ch_key).(vc_efq).(met);
            val_iae = D_stress.results.(ch_key).(vc_iae).(met);
            val_vbfq = D_stress.results.(ch_key).(vc_vbfq).(met);
            
            mask1 = D_stress.results.(ch_key).(vc_efq).valid & D_stress.results.(ch_key).(vc_iae).valid;
            mask2 = D_stress.results.(ch_key).(vc_efq).valid & D_stress.results.(ch_key).(vc_vbfq).valid;
            
            v1 = val_efq(mask1); v2_iae = val_iae(mask1);
            diff_iae = v1 - v2_iae;
            med_diff_iae = median(diff_iae);
            med_rat_iae = median(v1 ./ v2_iae);
            win_iae = sum(diff_iae < 0) / length(diff_iae);
            
            bs_iae = bootstrp(n_boot, @median, diff_iae);
            ci_iae = prctile(bs_iae, [2.5, 97.5]);
            
            fprintf(fid_bs, '%s,E-FQ vs IAE,%s,%d,%.6f,%.6f,%.6f,%.4f,%.4f\n', ...
                ch_name, mlbl, length(diff_iae), med_diff_iae, ci_iae(1), ci_iae(2), win_iae, med_rat_iae);
                
            v1 = val_efq(mask2); v2_vbfq = val_vbfq(mask2);
            diff_vbfq = v1 - v2_vbfq;
            med_diff_vbfq = median(diff_vbfq);
            med_rat_vbfq = median(v1 ./ v2_vbfq);
            win_vbfq = sum(diff_vbfq < 0) / length(diff_vbfq);
            
            bs_vbfq = bootstrp(n_boot, @median, diff_vbfq);
            ci_vbfq = prctile(bs_vbfq, [2.5, 97.5]);
            
            fprintf(fid_bs, '%s,E-FQ vs VB-FQ,%s,%d,%.6f,%.6f,%.6f,%.4f,%.4f\n', ...
                ch_name, mlbl, length(diff_vbfq), med_diff_vbfq, ci_vbfq(1), ci_vbfq(2), win_vbfq, med_rat_vbfq);
        end
    end
    fclose(fid_bs);
    
    %% --- 5. Generate pilot_transition_thresholds.csv ---
    csv_t = fullfile(out_dir, 'pilot_transition_thresholds.csv');
    fid_t = fopen(csv_t, 'w');
    fprintf(fid_t, 'Profile,Variant,SNR50,SNR05\n');
    
    snr_grid = D_val.cfg.snr_range;
    t_res = struct();
    
    for ch = 1:num_ch
        ch_name = D_val.cfg.channels{ch, 2};
        for v = 1:num_v
            var_name = D_val.csv_labels{v};
            
            fer_o = zeros(1, length(snr_grid));
            for s = 1:length(snr_grid)
                errs = squeeze(D_val.raw_errors(ch, s, v, :))';
                valid = ~isnan(errs);
                stats = compute_paper2_ber_statistics(errs, valid, D_val.cfg.num_data_bits);
                fer_o(s) = stats.FER_Overall;
            end
            
            idx50 = find(fer_o <= 0.50, 1, 'first');
            idx05 = find(fer_o <= 0.05, 1, 'first');
            
            snr50 = NaN; if ~isempty(idx50), snr50 = snr_grid(idx50); end
            snr05 = NaN; if ~isempty(idx05), snr05 = snr_grid(idx05); end
            
            t_res.(sprintf('CH%d', ch)).(strrep(var_name, '-', '_')).snr50 = snr50;
            t_res.(sprintf('CH%d', ch)).(strrep(var_name, '-', '_')).snr05 = snr05;
            
            fprintf(fid_t, '%s,%s,%d,%d\n', ch_name, var_name, snr50, snr05);
        end
    end
    fclose(fid_t);
    
    %% --- 6. Generate pilot_manifest.txt ---
    [~, git_sha] = system('git rev-parse HEAD');
    
    fid_mf = fopen(fullfile(out_dir, 'pilot_manifest.txt'), 'w');
    fprintf(fid_mf, 'pilot_basis_sha = %s\n', strtrim(git_sha));
    fprintf(fid_mf, 'final tracker = E-FQ\n');
    fprintf(fid_mf, 'Q = [%g,%g]\n', D_val.cfg.final_Q(1,1), D_val.cfg.final_Q(2,2));
    fprintf(fid_mf, 'Kcal = %d\n', D_val.cfg.reliability.calibration_symbols);
    fprintf(fid_mf, 'c2 = %g\n', D_val.cfg.c2);
    fprintf(fid_mf, 'TRM = disabled\n');
    fprintf(fid_mf, 'equalizer = disabled\n');
    fprintf(fid_mf, 'channel model = bellhop_local_cluster\n');
    fprintf(fid_mf, 'cluster gap = %g s\n', 0.05);
    fprintf(fid_mf, 'BER SNR range = %d:%d dB\n', min(D_val.cfg.snr_range), max(D_val.cfg.snr_range));
    fprintf(fid_mf, 'BER MC = %d\n', D_val.cfg.mc_trials_ber);
    fprintf(fid_mf, 'stress SNR = %d dB\n', D_stress.cfg.stress_snr_db);
    fprintf(fid_mf, 'stress MC = %d\n', D_stress.cfg.mc_trials_stress);
    fprintf(fid_mf, 'warp v0 = 0.5 m/s\n');
    fprintf(fid_mf, 'warp amp = 1.5 m/s\n');
    fprintf(fid_mf, 'warp freq = 0.2 Hz\n');
    fprintf(fid_mf, 'fade = 100-ms Gaussian deep fade\n');
    fprintf(fid_mf, 'publication variants = %s\n', strjoin(D_val.csv_labels, ', '));
    fprintf(fid_mf, 'paper MC = 3000\n');
    fprintf(fid_mf, 'paper run = NOT RUN\n');
    fclose(fid_mf);
    
    %% --- 7. Evaluate PILOT Gates and Output pilot_gate_report.txt ---
    fid_g = fopen(fullfile(out_dir, 'pilot_gate_report.txt'), 'w');
    
    % PILOT-1: numerical validity (ReceiverFailRate <= 0.05 in validation, valid trial rate >= 0.95 in stress)
    P1_pass = true;
    for ch = 1:num_ch
        for v = 1:num_v
            for s = 1:num_snr
                errs = squeeze(D_val.raw_errors(ch, s, v, :))';
                valid = ~isnan(errs);
                stats = compute_paper2_ber_statistics(errs, valid, D_val.cfg.num_data_bits);
                if stats.SyncFailRate > 0.05
                    P1_pass = false;
                end
            end
            ch_key = sprintf('CH%d', ch);
            vc_key = strrep(D_stress.variants{v}, '-', '_');
            res = D_stress.results.(ch_key).(vc_key);
            stats = compute_paper2_ber_statistics(res.raw_errors, res.valid, D_stress.cfg.num_data_bits);
            if (stats.Trials_Valid / stats.Trials_Total) < 0.95
                P1_pass = false;
            end
        end
    end
    
    % PILOT-2: primary dynamic tracking benefit vs IAE
    P2_pass = true;
    for ch = 1:num_ch
        ch_key = sprintf('CH%d', ch);
        rm_efq_o = median(D_stress.results.(ch_key).E_FQ.rmse_overall(D_stress.results.(ch_key).E_FQ.valid));
        rm_iae_o = median(D_stress.results.(ch_key).A.rmse_overall(D_stress.results.(ch_key).A.valid));
        rm_efq_f = median(D_stress.results.(ch_key).E_FQ.rmse_fade(D_stress.results.(ch_key).E_FQ.valid));
        rm_iae_f = median(D_stress.results.(ch_key).A.rmse_fade(D_stress.results.(ch_key).A.valid));
        
        if rm_efq_o > rm_iae_o, P2_pass = false; end
        if rm_efq_f > rm_iae_f, P2_pass = false; end
        if (rm_efq_o / rm_iae_o) > 0.90, P2_pass = false; end % Need median across profiles? Re-read: "median across profiles of Overall RMSE ratio E-FQ/IAE <= 0.90"
    end
    % Refined P2 check for median ratio across profiles
    med_rats = zeros(1, num_ch);
    for ch = 1:num_ch
        ch_key = sprintf('CH%d', ch);
        mask = D_stress.results.(ch_key).E_FQ.valid & D_stress.results.(ch_key).A.valid;
        med_rats(ch) = median(D_stress.results.(ch_key).E_FQ.rmse_overall(mask) ./ D_stress.results.(ch_key).A.rmse_overall(mask));
    end
    if median(med_rats) > 0.90, P2_pass = false; end
    
    % PILOT-3: reliability contribution beyond fixed-Q VB
    P3_pass = true;
    bs_support_count = 0;
    for ch = 1:num_ch
        ch_key = sprintf('CH%d', ch);
        rm_efq_f = median(D_stress.results.(ch_key).E_FQ.rmse_fade(D_stress.results.(ch_key).E_FQ.valid));
        rm_vbfq_f = median(D_stress.results.(ch_key).VB_FQ.rmse_fade(D_stress.results.(ch_key).VB_FQ.valid));
        if rm_efq_f > rm_vbfq_f, P3_pass = false; end
        
        mask = D_stress.results.(ch_key).E_FQ.valid & D_stress.results.(ch_key).VB_FQ.valid;
        v1 = D_stress.results.(ch_key).E_FQ.rmse_fade(mask);
        v2 = D_stress.results.(ch_key).VB_FQ.rmse_fade(mask);
        diff_v = v1 - v2;
        bs_v = bootstrp(10000, @median, diff_v);
        ci_u = prctile(bs_v, 97.5);
        if ci_u < 0
            bs_support_count = bs_support_count + 1;
        end
    end
    med_rats_f = zeros(1, num_ch);
    for ch = 1:num_ch
        ch_key = sprintf('CH%d', ch);
        mask = D_stress.results.(ch_key).E_FQ.valid & D_stress.results.(ch_key).VB_FQ.valid;
        med_rats_f(ch) = median(D_stress.results.(ch_key).E_FQ.rmse_fade(mask) ./ D_stress.results.(ch_key).VB_FQ.rmse_fade(mask));
    end
    if median(med_rats_f) >= 1.00, P3_pass = false; end
    
    P3_status = 'PASS';
    if ~P3_pass
        P3_status = 'PILOT_RELIABILITY_INCREMENTAL_GATE_FAIL';
    elseif bs_support_count < 2
        P3_status = 'RELIABILITY_INCREMENTAL_BENEFIT_WEAK';
        P3_pass = false;
    end
    
    % PILOT-4: mechanism consistency
    P4_pass = true;
    P4_status = 'PASS';
    for ch = 1:num_ch
        ch_key = sprintf('CH%d', ch);
        res = D_stress.results.(ch_key).E_FQ;
        
        [pass_gate, status_gate, ~] = evaluate_mechanism_gate(res);
        if ~pass_gate
            P4_pass = false;
            P4_status = status_gate;
        end
    end
    
    % PILOT-5: communication non-inferiority
    P5_pass = true;
    for ch = 1:num_ch
        ch_key = sprintf('CH%d', ch);
        efq_50 = t_res.(ch_key).E_FQ.snr50;
        iae_50 = t_res.(ch_key).IAE.snr50;
        if ~isnan(efq_50) && (isnan(iae_50) || efq_50 > iae_50 + 1), P5_pass = false; end
        
        efq_05 = t_res.(ch_key).E_FQ.snr05;
        iae_05 = t_res.(ch_key).IAE.snr05;
        if ~isnan(efq_05) && (isnan(iae_05) || efq_05 > iae_05 + 1), P5_pass = false; end
        
        % at -10 dB: FER_Overall <= 0.05, ReceiverFailRate <= 0.05
        errs = squeeze(D_val.raw_errors(ch, end, 3, :))';
        valid = ~isnan(errs);
        stats = compute_paper2_ber_statistics(errs, valid, D_val.cfg.num_data_bits);
        if stats.FER_Overall > 0.05, P5_pass = false; end
        if stats.SyncFailRate > 0.05, P5_pass = false; end
    end
    
    % PILOT-6: no hidden front-end contamination
    P6_pass = ~D_val.cfg.frontend.use_trm && ...
              ~D_val.cfg.equalizer.enabled && ...
              isequal(D_val.csv_labels, {'IAE', 'VB-FQ', 'E-FQ'}) && ...
              strcmp(D_val.cfg.hvb.q_adaptation_mode, 'fixed') && ...
              D_val.cfg.c2_frozen == true && ...
              isequal(D_val.cfg.snr_range, -16:1:-10) && ...
              D_stress.cfg.stress_snr_db == 15;
              
    fprintf(fid_g, 'PILOT-1: %d\n', P1_pass);
    fprintf(fid_g, 'PILOT-2: %d\n', P2_pass);
    fprintf(fid_g, 'PILOT-3: %s (Pass=%d)\n', P3_status, P3_pass);
    fprintf(fid_g, 'PILOT-4: %s (Pass=%d)\n', P4_status, P4_pass);
    fprintf(fid_g, 'PILOT-5: %d\n', P5_pass);
    fprintf(fid_g, 'PILOT-6: %d\n', P6_pass);
    
    fprintf(fid_g, '\nFINAL DECISION:\n');
    if ~P2_pass
        fprintf(fid_g, 'PILOT_PRIMARY_TRACKING_GATE_FAIL\nPAPER_BLOCKED\n');
    elseif ~P3_pass
        fprintf(fid_g, '%s\nPAPER_BLOCKED\n', P3_status);
    elseif ~P4_pass
        fprintf(fid_g, '%s\nPAPER_BLOCKED\n', P4_status);
    elseif ~P5_pass
        fprintf(fid_g, 'PILOT_TRACKING_PASS_COMMUNICATION_GATE_FAIL\nPAPER_BLOCKED_PENDING_SCIENTIFIC_REVIEW\n');
    elseif P1_pass && P2_pass && P3_pass && P4_pass && P5_pass && P6_pass
        fprintf(fid_g, 'PILOT_200MC_PASS\nPAPER_3000MC_READY\nPAPER_NOT_RUN\n');
    else
        fprintf(fid_g, 'PILOT_FAIL_OTHER\nPAPER_BLOCKED\n');
    end
    fprintf(fid_g, 'WAITING FOR SCIENTIFIC REVIEW BEFORE 3000-MC PAPER RUN.\n');
    fclose(fid_g);
end
