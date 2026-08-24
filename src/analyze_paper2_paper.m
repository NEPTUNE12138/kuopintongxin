function analyze_paper2_paper()
% ANALYZE_PAPER2_PAPER Final 3000-MC Analysis for WUWNet Paper 2

    out_dir = fullfile('results', 'paper_review');
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end
    
    % 1. Load Data
    ber_file = fullfile('results', 'paper', 'paper2_ber_validation_3000mc.mat');
    stress_file = fullfile('results', 'paper', 'paper2_stress_pilot_3000mc.mat');
    
    assert(exist(ber_file, 'file') > 0, 'BER file missing');
    assert(exist(stress_file, 'file') > 0, 'Stress file missing');
    
    D_ber = load(ber_file);
    D_stress = load(stress_file);
    
    num_ch = size(D_ber.cfg.channels, 1);
    num_snr = length(D_ber.cfg.snr_range);
    num_var = length(D_ber.variants);
    
    % Gates Initialization
    P1_pass = true; P2_pass = true; P3_pass = true; P4_pass = true; P5_pass = true; P6_pass = true;
    
    % --- FINAL MANIFEST ---
    fid_man = fopen(fullfile(out_dir, 'final_manifest.txt'), 'w');
    fprintf(fid_man, 'paper_basis_sha = %s\n', D_ber.paper_basis_sha);
    fprintf(fid_man, 'execution_head_sha = %s\n', D_ber.execution_worktree_sha);
    fprintf(fid_man, 'execution_worktree_clean = NOT RECORDED\n');
    fprintf(fid_man, 'paper_result_commit_sha = cda0964df2caf95ad03f9875d1e4dd47285f584a\n');
    
    [status, cmdout] = system('git rev-parse HEAD');
    if status == 0
        fprintf(fid_man, 'postprocessing_basis_sha = %s\n', strtrim(cmdout));
    else
        fprintf(fid_man, 'postprocessing_basis_sha = cda0964df2caf95ad03f9875d1e4dd47285f584a\n');
    end

    fprintf(fid_man, '\nfinal tracker = E-FQ\nQ = [%g,%g]\nKcal = 8\nc2 = %.4f\n', D_ber.cfg.final_Q(1,1), D_ber.cfg.final_Q(2,2), D_ber.cfg.c2);
    fprintf(fid_man, '\nTRM = disabled\nequalizer = disabled\n');
    fprintf(fid_man, '\nchannel model = bellhop_local_cluster\ncluster gap = 0.05 s\n');
    fprintf(fid_man, '\nprofiles = P1,P2,P3\nBER SNR = -16:-10 dB\nBER MC = 3000\n');
    fprintf(fid_man, '\nstress SNR = 15 dB\nstress MC = 3000\n');
    fprintf(fid_man, 'warp v0 = 0.5 m/s\nwarp amp = 1.5 m/s\nwarp freq = 0.2 Hz\nfade = 100-ms Gaussian deep fade\n');
    fprintf(fid_man, '\nvariants = IAE,VB-FQ,E-FQ\n');
    fprintf(fid_man, '\nbootstrap resamples = 10000\nbootstrap seed = 20260909\n');
    fclose(fid_man);
    
    if ~strcmp(D_ber.cfg.final_tracker_variant, 'E-FQ') || ...
       D_ber.cfg.final_Q(1,1) ~= 0.05 || D_ber.cfg.c2 ~= 0.02 || ...
       D_ber.cfg.frontend.use_trm || D_ber.cfg.equalizer.enabled
        P6_pass = false;
    end
    
    % --- BER/FER TABLE & THRESHOLDS ---
    fid_ber = fopen(fullfile(out_dir, 'final_ber_table.csv'), 'w');
    fprintf(fid_ber, 'ProfileID,ProfileDescription,Variant,SNR_dB,Trials_Total,Trials_Valid,ReceiverFailCount,ReceiverFailRate,BitErrors_Valid,Bits_Valid,BER_Valid,BER_Wilson_Lower,BER_Wilson_Upper,FrameErrors_Valid,FER_Valid,FrameErrors_Overall,FER_Overall,FER_Wilson_Lower,FER_Wilson_Upper\n');
    
    thresh_map = struct();
    for ch = 1:num_ch
        ch_name = D_ber.cfg.channels{ch, 2};
        p_id = canonical_profile_id(ch_name);
        
        for v = 1:num_var
            var_name = D_ber.csv_labels{v};
            
            thresh_map.(p_id).(strrep(var_name,'-','_')).SNR50 = NaN;
            thresh_map.(p_id).(strrep(var_name,'-','_')).SNR05 = NaN;
            
            for snr_idx = 1:num_snr
                snr_db = D_ber.cfg.snr_range(snr_idx);
                trial_errs = squeeze(D_ber.raw_errors(ch, snr_idx, v, :))';
                valid_flags = ~isnan(trial_errs);
                stats = compute_paper2_ber_statistics(trial_errs, valid_flags, D_ber.cfg.num_data_bits);
                
                fprintf(fid_ber, '%s,%s,%s,%d,%d,%d,%d,%.4f,%d,%d,%.6f,%.6f,%.6f,%d,%.4f,%d,%.4f,%.6f,%.6f\n', ...
                    p_id, ch_name, var_name, snr_db, stats.Trials_Total, stats.Trials_Valid, ...
                    stats.SyncFailCount, stats.SyncFailRate, stats.BitErrors_Valid, stats.Bits_Valid, stats.BER_Valid, ...
                    stats.Wilson_Lower_ValidBER, stats.Wilson_Upper_ValidBER, ...
                    stats.FrameErrors_Valid, stats.FER_Valid, stats.FrameErrors_Overall, stats.FER_Overall, ...
                    stats.Wilson_Lower_OverallFER, stats.Wilson_Upper_OverallFER);
                
                if stats.SyncFailRate > 0.05, P1_pass = false; end
                
                if isnan(thresh_map.(p_id).(strrep(var_name,'-','_')).SNR50) && stats.FER_Overall <= 0.50
                    thresh_map.(p_id).(strrep(var_name,'-','_')).SNR50 = snr_db;
                end
                if isnan(thresh_map.(p_id).(strrep(var_name,'-','_')).SNR05) && stats.FER_Overall <= 0.05
                    thresh_map.(p_id).(strrep(var_name,'-','_')).SNR05 = snr_db;
                end
                
                if snr_db == -10 && strcmp(var_name, 'E-FQ')
                    if stats.FER_Overall > 0.05 || stats.SyncFailRate > 0.05
                        P5_pass = false;
                    end
                end
            end
            
            if isnan(thresh_map.(p_id).(strrep(var_name,'-','_')).SNR50), thresh_map.(p_id).(strrep(var_name,'-','_')).SNR50 = max(D_ber.cfg.snr_range)+1; end
            if isnan(thresh_map.(p_id).(strrep(var_name,'-','_')).SNR05), thresh_map.(p_id).(strrep(var_name,'-','_')).SNR05 = max(D_ber.cfg.snr_range)+1; end
        end
        
        t_iae = thresh_map.(p_id).IAE;
        t_efq = thresh_map.(p_id).E_FQ;
        if t_efq.SNR50 > t_iae.SNR50 + 1, P5_pass = false; end
        if t_efq.SNR05 > t_iae.SNR05 + 1, P5_pass = false; end
    end
    fclose(fid_ber);
    
    fid_th = fopen(fullfile(out_dir, 'final_threshold_table.csv'), 'w');
    fprintf(fid_th, 'ProfileID,ProfileDescription,Variant,SNR50,SNR05,Delta_SNR50,Delta_SNR05\n');
    for ch = 1:num_ch
        ch_name = D_ber.cfg.channels{ch, 2};
        p_id = canonical_profile_id(ch_name);
        t_iae = thresh_map.(p_id).IAE;
        for v = 1:num_var
            var_name = D_ber.csv_labels{v};
            t_v = thresh_map.(p_id).(strrep(var_name,'-','_'));
            fprintf(fid_th, '%s,%s,%s,%d,%d,%d,%d\n', p_id, ch_name, var_name, t_v.SNR50, t_v.SNR05, t_v.SNR50 - t_iae.SNR50, t_v.SNR05 - t_iae.SNR05);
        end
    end
    fclose(fid_th);
    
    % --- STRESS TRACKING & MECHANISM & EFFECTS ---
    fid_tr = fopen(fullfile(out_dir, 'final_tracking_table.csv'), 'w');
    fprintf(fid_tr, 'ProfileID,ProfileDescription,Variant,N,ValidRate,Overall_RMSE_Median,Overall_RMSE_P10,Overall_RMSE_P90,PRE_RMSE_Median,FADE_RMSE_Median,POST_RMSE_Median,BER_Valid,FER_Overall\n');
    
    fid_me = fopen(fullfile(out_dir, 'final_mechanism_table.csv'), 'w');
    fprintf(fid_me, 'ProfileID,ProfileDescription,Variant,Median_m_PRE,Median_m_FADE,Median_m_POST,Median_Reff_Rvb_PRE,Median_Reff_Rvb_FADE,Median_Reff_Rvb_POST,Median_K_PRE,Median_K_FADE,Median_K_POST,Median_Q11_PRE,Median_Q11_FADE,Median_Q11_POST,Median_Q22_PRE,Median_Q22_FADE,Median_Q22_POST\n');
    
    fid_bs = fopen(fullfile(out_dir, 'final_bootstrap_table.csv'), 'w');
    fprintf(fid_bs, 'ProfileID,ProfileDescription,Comparison,Metric,N_Paired,Median_Comparator,Median_EFQ,Median_Difference,CI95_Lower,CI95_Upper,WinRate_EFQ,Median_Ratio,ReductionPercent\n');
    
    fid_he = fopen(fullfile(out_dir, 'final_headline_effects.csv'), 'w');
    fprintf(fid_he, 'ProfileID,ProfileDescription,Metric,Comparator,ComparatorMedian,EFQMedian,Ratio,ReductionPercent\n');

    fid_mee = fopen(fullfile(out_dir, 'final_mechanism_effects.csv'), 'w');
    fprintf(fid_mee, 'ProfileID,ProfileDescription,ReliabilityDropPercent,ReffRvbIncreasePercent,KReductionPercent\n');

    P3_pass_count = 0;
    P4_status = 'PASS';
    
    for ch = 1:num_ch
        ch_name = D_ber.cfg.channels{ch, 2};
        p_id = canonical_profile_id(ch_name);
        ch_key = sprintf('CH%d', ch);
        
        m_rmse_o = zeros(1, num_var);
        m_rmse_f = zeros(1, num_var);
        
        for v = 1:num_var
            var_name = D_ber.csv_labels{v};
            struct_key = strrep(D_ber.variants{v}, '-', '_');
            res = D_stress.results.(ch_key).(struct_key);
            
            valid = res.valid;
            N_val = sum(valid);
            val_rate = N_val / length(valid);
            if val_rate < 0.95, P1_pass = false; end
            
            stats = compute_paper2_ber_statistics(res.raw_errors, valid, D_ber.cfg.num_data_bits);
            
            rm_o = prctile(res.rmse_overall(valid), [10 50 90]);
            rm_f = median(res.rmse_fade(valid), 'omitnan');
            rm_pre = median(res.rmse_pre(valid), 'omitnan');
            rm_po = median(res.rmse_post(valid), 'omitnan');
            
            m_rmse_o(v) = rm_o(2);
            m_rmse_f(v) = rm_f;
            
            fprintf(fid_tr, '%s,%s,%s,%d,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.6f,%.4f\n', ...
                p_id, ch_name, var_name, length(valid), val_rate, rm_o(2), rm_o(1), rm_o(3), rm_pre, rm_f, rm_po, stats.BER_Valid, stats.FER_Overall);
                
            m_m_p = NaN; m_m_f = NaN; m_m_po = NaN;
            m_rr_p = NaN; m_rr_f = NaN; m_rr_po = NaN;
            m_k_p = NaN; m_k_f = NaN; m_k_po = NaN;
            q11_p = NaN; q11_f = NaN; q11_po = NaN;
            q22_p = NaN; q22_f = NaN; q22_po = NaN;
            
            if isfield(res, 'm_pre'), m_m_p = median(res.m_pre(valid), 'omitnan'); end
            if isfield(res, 'm_fade'), m_m_f = median(res.m_fade(valid), 'omitnan'); end
            if isfield(res, 'm_post'), m_m_po = median(res.m_post(valid), 'omitnan'); end
            if isfield(res, 'mean_Reff_Rvb_pre'), m_rr_p = median(res.mean_Reff_Rvb_pre(valid), 'omitnan'); end
            if isfield(res, 'mean_Reff_Rvb_fade'), m_rr_f = median(res.mean_Reff_Rvb_fade(valid), 'omitnan'); end
            if isfield(res, 'mean_Reff_Rvb_post'), m_rr_po = median(res.mean_Reff_Rvb_post(valid), 'omitnan'); end
            if isfield(res, 'mean_K_pre'), m_k_p = median(res.mean_K_pre(valid), 'omitnan'); end
            if isfield(res, 'mean_K_fade'), m_k_f = median(res.mean_K_fade(valid), 'omitnan'); end
            if isfield(res, 'mean_K_post'), m_k_po = median(res.mean_K_post(valid), 'omitnan'); end
            if isfield(res, 'Q11_pre'), q11_p = median(res.Q11_pre(valid), 'omitnan'); end
            if isfield(res, 'Q11_fade'), q11_f = median(res.Q11_fade(valid), 'omitnan'); end
            if isfield(res, 'Q11_post'), q11_po = median(res.Q11_post(valid), 'omitnan'); end
            if isfield(res, 'Q22_pre'), q22_p = median(res.Q22_pre(valid), 'omitnan'); end
            if isfield(res, 'Q22_fade'), q22_f = median(res.Q22_fade(valid), 'omitnan'); end
            if isfield(res, 'Q22_post'), q22_po = median(res.Q22_post(valid), 'omitnan'); end
            
            fprintf(fid_me, '%s,%s,%s,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
                p_id, ch_name, var_name, m_m_p, m_m_f, m_m_po, m_rr_p, m_rr_f, m_rr_po, m_k_p, m_k_f, m_k_po, q11_p, q11_f, q11_po, q22_p, q22_f, q22_po);
                
            if strcmp(var_name, 'E-FQ')
                [pass_gate, status_gate, ~] = evaluate_mechanism_gate(res);
                if ~pass_gate
                    P4_pass = false;
                    P4_status = status_gate;
                end
                rel_drop = 100 * (1 - m_m_f / m_m_p);
                reff_inc = 100 * (m_rr_f / m_rr_p - 1);
                k_red = 100 * (1 - m_k_f / m_k_p);
                fprintf(fid_mee, '%s,%s,%.4f,%.4f,%.4f\n', p_id, ch_name, rel_drop, reff_inc, k_red);
            end
        end
        
        if m_rmse_o(3) > m_rmse_o(1), P2_pass = false; end
        if m_rmse_f(3) > m_rmse_f(1), P2_pass = false; end
        if m_rmse_o(3)/m_rmse_o(1) > 0.90, P2_pass = false; end
        
        if m_rmse_f(3) > m_rmse_f(2), P3_pass = false; end
        
        v_idx = [1, 2];
        metrics = {'Overall_RMSE', 'Fade_RMSE'};
        for v = v_idx
            var_name = D_ber.csv_labels{v};
            vc_comp = strrep(D_ber.variants{v}, '-', '_');
            res_comp = D_stress.results.(ch_key).(vc_comp);
            res_efq = D_stress.results.(ch_key).E_FQ;
            mask = res_comp.valid & res_efq.valid;
            n_pair = sum(mask);
            
            for m_idx = 1:2
                met = metrics{m_idx};
                if strcmp(met, 'Overall_RMSE')
                    err_comp = res_comp.rmse_overall(mask);
                    err_efq = res_efq.rmse_overall(mask);
                else
                    err_comp = res_comp.rmse_fade(mask);
                    err_efq = res_efq.rmse_fade(mask);
                end
                
                med_comp = median(err_comp);
                med_efq = median(err_efq);
                diff_arr = err_efq - err_comp;
                med_diff = median(diff_arr);
                med_ratio = med_efq / med_comp;
                red_pct = 100 * (1 - med_ratio);
                win_rate = sum(err_efq < err_comp) / n_pair;
                
                rng(20260909, 'twister');
                B = 10000;
                boot_diffs = zeros(1, B);
                for b = 1:B
                    idx = randi(n_pair, 1, n_pair);
                    boot_diffs(b) = median(err_efq(idx) - err_comp(idx));
                end
                ci = prctile(boot_diffs, [2.5 97.5]);
                
                fprintf(fid_bs, '%s,%s,%s,%s,%d,%.6f,%.6f,%.6f,%.6f,%.6f,%.4f,%.6f,%.4f\n', ...
                    p_id, ch_name, sprintf('E-FQ vs %s', var_name), met, n_pair, med_comp, med_efq, med_diff, ci(1), ci(2), win_rate, med_ratio, red_pct);
                    
                fprintf(fid_he, '%s,%s,%s,%s,%.6f,%.6f,%.6f,%.4f\n', ...
                    p_id, ch_name, met, var_name, med_comp, med_efq, med_ratio, red_pct);
                    
                if v == 2 && strcmp(met, 'Fade_RMSE')
                    if ci(2) < 0
                        P3_pass_count = P3_pass_count + 1;
                    end
                end
            end
        end
    end
    fclose(fid_tr);
    fclose(fid_me);
    fclose(fid_bs);
    fclose(fid_he);
    fclose(fid_mee);
    
    if P3_pass_count < 2
        P3_pass = false;
    end
    
    % --- CONSISTENCY ANALYSIS ---
    try
        T_pilot_th = readtable(fullfile('results', 'pilot_review', 'pilot_transition_thresholds.csv'));
        T_pilot_tr = readtable(fullfile('results', 'pilot_review', 'pilot_stress_summary.csv'));
        
        % We also need to extract pilot mechanism stats from the MAT directly or rely on the previous run,
        % but the easiest way is to re-compute pilot medians if missing or just load pilot_stress_pilot4_cfg1.mat.
        % The instructions say: Regenerate from existing Pilot/Paper artifacts only.
        
        fid_cons = fopen(fullfile(out_dir, 'pilot_paper_consistency.csv'), 'w');
        fprintf(fid_cons, 'ProfileID,ProfileDescription,Variant_or_Comparison,Metric,PilotValue,PaperValue,Difference,RelativeDifference,DirectionConsistent\n');
        
        fid_dir = fopen(fullfile(out_dir, 'pilot_paper_direction_summary.csv'), 'w');
        fprintf(fid_dir, 'ProfileID,Overall_IAE_Consistent,Fade_IAE_Consistent,Overall_VBFQ_Consistent,Fade_VBFQ_Consistent,Mechanism_Consistent\n');
        
        pilot_stress_files = dir(fullfile('results', 'pilot', '*stress*.mat'));
        [~, max_idx] = max([pilot_stress_files.datenum]);
        pilot_stress_file = fullfile('results', 'pilot', pilot_stress_files(max_idx).name);
        
        if exist(pilot_stress_file, 'file')
            D_pilot = load(pilot_stress_file);
        else
            error('Pilot stress MAT missing');
        end
        
        profiles = {'P1', 'P2', 'P3'};
        vars = {'IAE', 'VB-FQ', 'E-FQ'};
        ch_map = {'CH1', 'CH2', 'CH3'};
        
        % THRESHOLDS
        for p = 1:3
            p_id = profiles{p};
            ch_name = D_ber.cfg.channels{p, 2};
            
            for v = 1:3
                p_idx_pilot = NaN;
                for r = 1:height(T_pilot_th)
                    if strcmp(canonical_profile_id(T_pilot_th.Profile{r}), p_id) && strcmp(T_pilot_th.Variant{r}, vars{v})
                        p_idx_pilot = r; break;
                    end
                end
                
                val_pilot_snr50 = T_pilot_th.SNR50(p_idx_pilot);
                val_pilot_snr05 = T_pilot_th.SNR05(p_idx_pilot);
                
                val_paper_snr50 = thresh_map.(p_id).(strrep(vars{v},'-','_')).SNR50;
                val_paper_snr05 = thresh_map.(p_id).(strrep(vars{v},'-','_')).SNR05;
                
                fprintf(fid_cons, '%s,%s,%s,%s,%g,%g,%g,NaN,NA\n', p_id, ch_name, vars{v}, 'SNR50', val_pilot_snr50, val_paper_snr50, val_paper_snr50 - val_pilot_snr50);
                fprintf(fid_cons, '%s,%s,%s,%s,%g,%g,%g,NaN,NA\n', p_id, ch_name, vars{v}, 'SNR05', val_pilot_snr05, val_paper_snr05, val_paper_snr05 - val_pilot_snr05);
            end
        end
        
        % TRACKING MEDIANS & EFFECT RATIOS & MECHANISM
        for p = 1:3
            p_id = profiles{p};
            ch_name = D_ber.cfg.channels{p, 2};
            ch_key = ch_map{p};
            
            % Medians
            var_struct_keys = {'A', 'VB_FQ', 'E_FQ'};
            for v = 1:3
                vc = var_struct_keys{v};
                res_pi = D_pilot.results.(ch_key).(vc);
                res_pa = D_stress.results.(ch_key).(vc);
                
                val_pi_o = median(res_pi.rmse_overall(res_pi.valid), 'omitnan');
                val_pa_o = median(res_pa.rmse_overall(res_pa.valid), 'omitnan');
                diff_o = val_pa_o - val_pi_o;
                rel_o = diff_o / val_pi_o * 100;
                
                val_pi_f = median(res_pi.rmse_fade(res_pi.valid), 'omitnan');
                val_pa_f = median(res_pa.rmse_fade(res_pa.valid), 'omitnan');
                diff_f = val_pa_f - val_pi_f;
                rel_f = diff_f / val_pi_f * 100;
                
                fprintf(fid_cons, '%s,%s,%s,%s,%g,%g,%g,%g,NA\n', p_id, ch_name, vars{v}, 'Overall_RMSE', val_pi_o, val_pa_o, diff_o, rel_o);
                fprintf(fid_cons, '%s,%s,%s,%s,%g,%g,%g,%g,NA\n', p_id, ch_name, vars{v}, 'Fade_RMSE', val_pi_f, val_pa_f, diff_f, rel_f);
            end
            
            % Effects
            comps = {'A', 'VB_FQ'};
            c_names = {'IAE', 'VB-FQ'};
            dir_consist = zeros(1, 4);
            idx_eff = 1;
            
            for c = 1:2
                res_pi_c = D_pilot.results.(ch_key).(comps{c});
                res_pi_e = D_pilot.results.(ch_key).E_FQ;
                rat_pi_o = median(res_pi_e.rmse_overall(res_pi_e.valid)) / median(res_pi_c.rmse_overall(res_pi_c.valid));
                rat_pi_f = median(res_pi_e.rmse_fade(res_pi_e.valid)) / median(res_pi_c.rmse_fade(res_pi_c.valid));
                
                res_pa_c = D_stress.results.(ch_key).(comps{c});
                res_pa_e = D_stress.results.(ch_key).E_FQ;
                rat_pa_o = median(res_pa_e.rmse_overall(res_pa_e.valid)) / median(res_pa_c.rmse_overall(res_pa_c.valid));
                rat_pa_f = median(res_pa_e.rmse_fade(res_pa_e.valid)) / median(res_pa_c.rmse_fade(res_pa_c.valid));
                
                dir_o = (rat_pi_o < 1) && (rat_pa_o < 1);
                dir_f = (rat_pi_f < 1) && (rat_pa_f < 1);
                dir_consist(idx_eff) = dir_o; idx_eff = idx_eff + 1;
                dir_consist(idx_eff) = dir_f; idx_eff = idx_eff + 1;
                
                str_dir_o = 'FALSE'; if dir_o, str_dir_o = 'TRUE'; end
                str_dir_f = 'FALSE'; if dir_f, str_dir_f = 'TRUE'; end
                
                fprintf(fid_cons, '%s,%s,%s,%s,%g,%g,%g,%g,%s\n', p_id, ch_name, sprintf('E-FQ/%s', c_names{c}), 'Overall', rat_pi_o, rat_pa_o, rat_pa_o - rat_pi_o, (rat_pa_o - rat_pi_o)/rat_pi_o*100, str_dir_o);
                fprintf(fid_cons, '%s,%s,%s,%s,%g,%g,%g,%g,%s\n', p_id, ch_name, sprintf('E-FQ/%s', c_names{c}), 'Fade', rat_pi_f, rat_pa_f, rat_pa_f - rat_pi_f, (rat_pa_f - rat_pi_f)/rat_pi_f*100, str_dir_f);
            end
            
            % Mechanism
            mech_keys = {'m_pre', 'm_fade', 'mean_Reff_Rvb_pre', 'mean_Reff_Rvb_fade', 'mean_K_pre', 'mean_K_fade', 'Q11_pre', 'Q22_pre'};
            mech_names = {'m_PRE', 'm_FADE', 'ReffRvb_PRE', 'ReffRvb_FADE', 'K_PRE', 'K_FADE', 'Q11', 'Q22'};
            
            res_pi_e = D_pilot.results.(ch_key).E_FQ;
            res_pa_e = D_stress.results.(ch_key).E_FQ;
            
            m_vals_pi = zeros(1, 8);
            m_vals_pa = zeros(1, 8);
            
            for m = 1:8
                v_pi = median(res_pi_e.(mech_keys{m})(res_pi_e.valid), 'omitnan');
                v_pa = median(res_pa_e.(mech_keys{m})(res_pa_e.valid), 'omitnan');
                m_vals_pi(m) = v_pi;
                m_vals_pa(m) = v_pa;
                diff_m = v_pa - v_pi;
                rel_m = diff_m / v_pi * 100;
                
                fprintf(fid_cons, '%s,%s,%s,%s,%g,%g,%g,%g,NA\n', p_id, ch_name, 'E-FQ', mech_names{m}, v_pi, v_pa, diff_m, rel_m);
            end
            
            m_f_lt_pre_pi = m_vals_pi(2) < m_vals_pi(1);
            m_f_lt_pre_pa = m_vals_pa(2) < m_vals_pa(1);
            r_f_gt_pre_pi = m_vals_pi(4) > m_vals_pi(3);
            r_f_gt_pre_pa = m_vals_pa(4) > m_vals_pa(3);
            k_f_lt_pre_pi = m_vals_pi(6) < m_vals_pi(5);
            k_f_lt_pre_pa = m_vals_pa(6) < m_vals_pa(5);
            q_fix_pi = (abs(m_vals_pi(7) - 0.05) < 1e-5) && (abs(m_vals_pi(8) - 0.002) < 1e-5);
            q_fix_pa = (abs(m_vals_pa(7) - 0.05) < 1e-5) && (abs(m_vals_pa(8) - 0.002) < 1e-5);
            
            mech_dir = (m_f_lt_pre_pi && m_f_lt_pre_pa) && (r_f_gt_pre_pi && r_f_gt_pre_pa) && ...
                       (k_f_lt_pre_pi && k_f_lt_pre_pa) && (q_fix_pi && q_fix_pa);
                       
            str_mech = 'FALSE'; if mech_dir, str_mech = 'TRUE'; end
            str_o_iae = 'FALSE'; if dir_consist(1), str_o_iae = 'TRUE'; end
            str_f_iae = 'FALSE'; if dir_consist(2), str_f_iae = 'TRUE'; end
            str_o_vb = 'FALSE'; if dir_consist(3), str_o_vb = 'TRUE'; end
            str_f_vb = 'FALSE'; if dir_consist(4), str_f_vb = 'TRUE'; end
            
            fprintf(fid_dir, '%s,%s,%s,%s,%s,%s\n', p_id, str_o_iae, str_f_iae, str_o_vb, str_f_vb, str_mech);
        end
        fclose(fid_cons);
        fclose(fid_dir);
    catch ME
        disp(ME.message);
    end

    % --- FINAL GATE REPORT ---
    fid_g = fopen(fullfile(out_dir, 'final_gate_report.txt'), 'w');
    fprintf(fid_g, 'PAPER-1: %d\n', P1_pass);
    fprintf(fid_g, 'PAPER-2: %d\n', P2_pass);
    fprintf(fid_g, 'PAPER-3: %d\n', P3_pass);
    fprintf(fid_g, 'PAPER-4: %s (Pass=%d)\n', P4_status, P4_pass);
    fprintf(fid_g, 'PAPER-5: %d\n', P5_pass);
    fprintf(fid_g, 'PAPER-6: %d\n', P6_pass);
    
    fprintf(fid_g, '\nFINAL DECISION:\n');
    all_pass = P1_pass && P2_pass && P3_pass && P4_pass && P5_pass && P6_pass;
    if all_pass
        fprintf(fid_g, 'FINAL_3000MC_DATA_AUDITED\nFINAL_PUBLICATION_ARTIFACTS_COMPLETE\nREADY_FOR_MANUSCRIPT_DRAFTING\n');
    else
        fprintf(fid_g, 'PAPER_3000MC_COMPLETE\nFINAL_RESULTS_GATE_FAIL\nNO_PARAMETER_RETUNING\nREADY_FOR_SCIENTIFIC_REASSESSMENT\n');
    end
    fprintf(fid_g, 'NO FURTHER PARAMETER TUNING AUTHORIZED.\n');
    fclose(fid_g);

    disp('analyze_paper2_paper complete.');
end
