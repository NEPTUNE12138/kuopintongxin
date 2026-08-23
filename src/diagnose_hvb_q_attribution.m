function diagnose_hvb_q_attribution(mode)
% DIAGNOSE_HVB_Q_ATTRIBUTION Scientific diagnostic for Q attribution in HVB tracking.

    if nargin < 1, mode = 'quick'; end
    
    this_file = mfilename('fullpath');
    src_dir = fileparts(this_file);
    project_root = fileparts(src_dir);
    
    cfg = paper2_config(mode);
    num_mc = 50; % Enforce exactly 50 MC per scenario for falsification
    
    cfg.c2 = 1/50;
    cfg.reliability.calibration_symbols = 8;
    
    ch_file = cfg.channels{1, 1}; % Profile P1
    [h_chan, ~] = select_bellhop_local_cluster(ch_file, cfg);
    
    scenarios = {'S0_Static', 'S1_Warp', 'S2_Fade', 'S3_Warp_Fade'};
    variants = {'C', 'E', 'EQ0', 'EQ1', 'EQ2', 'EQ3'};
    
    fprintf('\n=== Running Q-Attribution Diagnostic ===\n');
    fprintf('MC Trials/Scenario: %d\n', num_mc);
    
    out_dir = fullfile(project_root, 'results', 'diagnostic');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    res = struct();
    
    % Store phase-level statistics
    fid_stat = fopen(fullfile(out_dir, 'q_attribution_phase_stats.csv'), 'w');
    fprintf(fid_stat, 'Scenario,Variant,Phase,Metric,Mean,Median,P10,P90\n');
    
    fid_sum = fopen(fullfile(out_dir, 'q_attribution_summary.csv'), 'w');
    fprintf(fid_sum, 'Scenario,Variant,RMSE_Median,RMSE_Mean,Bias_Median,ValidRate,BER_Mean\n');
    
    metrics_list = {'R_vb', 'R_eff', 'R_eff_R_vb', 'K_delay', 'Q11', 'Q22', ...
        'abs_innovation', 'NIS', 'directional_consistency', 'coherent_fraction', 'tracking_error'};
    
    for s = 1:length(scenarios)
        scen_name = scenarios{s};
        fprintf('\n--- Scenario: %s ---\n', scen_name);
        
        do_warp = contains(scen_name, 'Warp');
        do_fade = contains(scen_name, 'Fade');
        
        warp_cfg.v0_mps = 0.5;
        warp_cfg.velocity_amp_mps = 1.5;
        warp_cfg.velocity_freq_hz = 0.2;
        warp_cfg.phase_rad = 0;
        
        for v = 1:length(variants)
            vn = variants{v};
            res.(scen_name).(vn).rmse = NaN(1, num_mc);
            res.(scen_name).(vn).bias = NaN(1, num_mc);
            res.(scen_name).(vn).ber = NaN(1, num_mc);
            res.(scen_name).(vn).phase_data = struct();
        end
        
        for mc = 1:num_mc
            if mod(mc, 10) == 0, fprintf('  Trial %d/%d\n', mc, num_mc); end
            
            rng_seed = cfg.master_seed + 1000000 + s*10000 + mc;
            rng(rng_seed, 'twister');
            
            [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
            rx_clean = conv(tx_pb, h_chan, 'full');
            
            if do_warp
                [rx_warp, warp_meta] = apply_paper2_time_warp(rx_clean, cfg, warp_cfg);
            else
                rx_warp = rx_clean;
                warp_meta.epsilon_true_samples = zeros(size(rx_warp));
            end
            
            if do_fade
                t = (0:length(rx_warp)-1) / cfg.fs;
                packet_duration = length(rx_warp) / cfg.fs;
                fade_center = packet_duration / 2;
                fade_width = 0.1;
                fade_env = 1 - 0.9 * exp(-0.5 * ((t - fade_center) / (fade_width / 3)).^2);
                rx_fade = rx_warp .* fade_env;
            else
                rx_fade = rx_warp;
            end
            
            snr_db = 15;
            rx_power = norm(rx_fade)^2 / length(rx_fade);
            noise_power = rx_power / (10^(snr_db / 10));
            noise = sqrt(noise_power/2) * (randn(size(rx_fade)) + 1j * randn(size(rx_fade)));
            rx_final = rx_fade + noise;
            
            try
                [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_final, preamble, cfg);
                sync_meta.peak_idx = peak_idx;
                sync_meta.preamble_start = p_start;
                sync_meta.payload_start = pay_start;
                sync_meta.mf = mf;
                
                sym_centers = pay_start + (0:cfg.num_diff_symbols-1) * cfg.symbol_samples + round(cfg.symbol_samples/2);
                sym_centers = min(length(rx_warp), max(1, sym_centers));
                
                phases = struct(); % Reset to prevent stale fields from previous scenarios
                if do_fade
                    fade_env_at_centers = fade_env(sym_centers);
                    fade_mask = fade_env_at_centers < 0.5;
                    first_fade = find(fade_mask, 1, 'first');
                    last_fade = find(fade_mask, 1, 'last');
                    
                    phases.PRE = 1:(first_fade-1);
                    phases.FADE = first_fade:last_fade;
                    phases.POST = (last_fade+1):cfg.num_diff_symbols;
                else
                    phases.NORMAL = 1:cfg.num_diff_symbols;
                end
                
                eps_true_per_symbol = warp_meta.epsilon_true_samples(sym_centers);
                eps_true_rel = eps_true_per_symbol - eps_true_per_symbol(1);
                
                for v = 1:length(variants)
                    vn = variants{v};
                    cfg_run = cfg;
                    
                    if strcmp(vn, 'EQ0')
                        vc_run = 'E-CAL'; cfg_run.hvb.q_adaptation_mode = 'both';
                    elseif strcmp(vn, 'EQ1')
                        vc_run = 'E-CAL'; cfg_run.hvb.q_adaptation_mode = 'fixed';
                    elseif strcmp(vn, 'EQ2')
                        vc_run = 'E-CAL'; cfg_run.hvb.q_adaptation_mode = 'q22_only';
                    elseif strcmp(vn, 'EQ3')
                        vc_run = 'E-CAL'; cfg_run.hvb.q_adaptation_mode = 'q11_only';
                    else
                        vc_run = vn;
                    end
                    
                    try
                        [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_final, preamble, mseq_os, sync_meta, cfg_run, vc_run);
                        
                        if strcmp(meta.status, 'SUCCESS')
                            eps_est_rel = meta.delay_est_samples - meta.delay_est_samples(1);
                            err = eps_est_rel - eps_true_rel;
                            res.(scen_name).(vn).rmse(mc) = sqrt(mean(err.^2));
                            res.(scen_name).(vn).bias(mc) = mean(err);
                            res.(scen_name).(vn).ber(mc) = sum(decoded_bits ~= data_bits) / cfg.num_data_bits;
                            
                            phase_names = fieldnames(phases);
                            for p_i = 1:length(phase_names)
                                p_name = phase_names{p_i};
                                p_idx = phases.(p_name);
                                if isempty(p_idx), continue; end
                                
                                % Safely extract fields
                                if isfield(meta, 'R_vb'), data_tmp.R_vb = meta.R_vb(p_idx); else data_tmp.R_vb = NaN(size(p_idx)); end
                                if isfield(meta, 'R_eff'), data_tmp.R_eff = meta.R_eff(p_idx); else data_tmp.R_eff = NaN(size(p_idx)); end
                                data_tmp.R_eff_R_vb = data_tmp.R_eff ./ max(data_tmp.R_vb, eps);
                                if isfield(meta, 'K_gain'), data_tmp.K_delay = meta.K_gain(1, p_idx); else data_tmp.K_delay = NaN(size(p_idx)); end
                                if isfield(meta, 'Q_diag')
                                    data_tmp.Q11 = meta.Q_diag(1, p_idx); data_tmp.Q22 = meta.Q_diag(2, p_idx);
                                else
                                    data_tmp.Q11 = NaN(size(p_idx)); data_tmp.Q22 = NaN(size(p_idx));
                                end
                                if isfield(meta, 'abs_innovation'), data_tmp.abs_innovation = meta.abs_innovation(p_idx); else data_tmp.abs_innovation = NaN(size(p_idx)); end
                                if isfield(meta, 'NIS'), data_tmp.NIS = meta.NIS(p_idx); else data_tmp.NIS = NaN(size(p_idx)); end
                                if isfield(meta, 'directional_consistency'), data_tmp.directional_consistency = meta.directional_consistency(p_idx); else data_tmp.directional_consistency = NaN(size(p_idx)); end
                                if isfield(meta, 'coherent_fraction'), data_tmp.coherent_fraction = meta.coherent_fraction(p_idx); else data_tmp.coherent_fraction = NaN(size(p_idx)); end
                                data_tmp.tracking_error = err(p_idx);
                                
                                if ~isfield(res.(scen_name).(vn).phase_data, p_name)
                                    for m_i = 1:length(metrics_list), res.(scen_name).(vn).phase_data.(p_name).(metrics_list{m_i}) = []; end
                                end
                                for m_i = 1:length(metrics_list)
                                    m_str = metrics_list{m_i};
                                    res.(scen_name).(vn).phase_data.(p_name).(m_str) = [res.(scen_name).(vn).phase_data.(p_name).(m_str), data_tmp.(m_str)];
                                end
                            end
                        end
                    catch ME
                        if ~strcmp(ME.identifier, 'Paper2:SyncFail')
                            rethrow(ME);
                        end
                    end
                end
            catch ME
                if ~strcmp(ME.identifier, 'Paper2:SyncFail')
                    rethrow(ME);
                end
            end
        end
        
        for v = 1:length(variants)
            vn = variants{v};
            valid_trials = sum(~isnan(res.(scen_name).(vn).rmse));
            valid_rate = valid_trials / num_mc;
            med_rmse = median(res.(scen_name).(vn).rmse, 'omitnan');
            mean_rmse = mean(res.(scen_name).(vn).rmse, 'omitnan');
            med_bias = median(res.(scen_name).(vn).bias, 'omitnan');
            mean_ber = mean(res.(scen_name).(vn).ber, 'omitnan');
            
            fprintf(fid_sum, '%s,%s,%.4f,%.4f,%.4f,%.4f,%.6f\n', scen_name, vn, med_rmse, mean_rmse, med_bias, valid_rate, mean_ber);
            
            if isfield(res.(scen_name).(vn), 'phase_data')
                phase_names = fieldnames(res.(scen_name).(vn).phase_data);
                for p_i = 1:length(phase_names)
                    p_name = phase_names{p_i};
                    for m_i = 1:length(metrics_list)
                        m_str = metrics_list{m_i};
                        data_arr = res.(scen_name).(vn).phase_data.(p_name).(m_str);
                        if isempty(data_arr) || all(isnan(data_arr)), continue; end
                        m_mean = mean(data_arr, 'omitnan');
                        m_med = median(data_arr, 'omitnan');
                        m_p10 = prctile(data_arr, 10);
                        m_p90 = prctile(data_arr, 90);
                        fprintf(fid_stat, '%s,%s,%s,%s,%.6f,%.6f,%.6f,%.6f\n', scen_name, vn, p_name, m_str, m_mean, m_med, m_p10, m_p90);
                    end
                end
            end
        end
    end
    
    fclose(fid_stat);
    fclose(fid_sum);
    save(fullfile(out_dir, 'q_attribution_raw.mat'), 'res', 'scenarios', 'variants');
    fprintf('Saved Q-Attribution diagnostics to %s\n', out_dir);
    
    % Classification
    fprintf('\n=== Q-Attribution Diagnostic Classification ===\n');
    
    % Get RMSE ratios relative to C
    c_s1 = median(res.S1_Warp.C.rmse, 'omitnan');
    c_s3 = median(res.S3_Warp_Fade.C.rmse, 'omitnan');
    
    rmse_eq0_s1 = median(res.S1_Warp.EQ0.rmse, 'omitnan');
    rmse_eq1_s1 = median(res.S1_Warp.EQ1.rmse, 'omitnan');
    rmse_eq2_s1 = median(res.S1_Warp.EQ2.rmse, 'omitnan');
    rmse_eq3_s1 = median(res.S1_Warp.EQ3.rmse, 'omitnan');
    
    rmse_eq0_s3 = median(res.S3_Warp_Fade.EQ0.rmse, 'omitnan');
    rmse_eq1_s3 = median(res.S3_Warp_Fade.EQ1.rmse, 'omitnan');
    rmse_eq2_s3 = median(res.S3_Warp_Fade.EQ2.rmse, 'omitnan');
    rmse_eq3_s3 = median(res.S3_Warp_Fade.EQ3.rmse, 'omitnan');
    
    fprintf('RMSE Ratios vs C:\n');
    fprintf('  EQ0 (both) S1: %.3f, S3: %.3f\n', rmse_eq0_s1/c_s1, rmse_eq0_s3/c_s3);
    fprintf('  EQ1 (fixed) S1: %.3f, S3: %.3f\n', rmse_eq1_s1/c_s1, rmse_eq1_s3/c_s3);
    fprintf('  EQ2 (Q22)   S1: %.3f, S3: %.3f\n', rmse_eq2_s1/c_s1, rmse_eq2_s3/c_s3);
    fprintf('  EQ3 (Q11)   S1: %.3f, S3: %.3f\n', rmse_eq3_s1/c_s1, rmse_eq3_s3/c_s3);
    
    % Logic
    improves_s1 = (rmse_eq1_s1 <= 0.90 * rmse_eq0_s1) || (rmse_eq2_s1 <= 0.90 * rmse_eq0_s1);
    worsens_s3 = (rmse_eq1_s3 > 1.10 * rmse_eq0_s3) && (rmse_eq2_s3 > 1.10 * rmse_eq0_s3);
    q_adaptation_suspect = improves_s1 && ~worsens_s3;
    
    q11_inflation_suspect = (rmse_eq2_s1 < rmse_eq3_s1) && (rmse_eq2_s3 < rmse_eq3_s3);
    
    vb_r_recursion_suspect = (abs(rmse_eq1_s1 - rmse_eq0_s1) / rmse_eq0_s1 < 0.1) && (abs(rmse_eq2_s1 - rmse_eq0_s1) / rmse_eq0_s1 < 0.1);
    
    fprintf('\nPrimary Suspects:\n');
    fprintf('  Q_ADAPTATION_PRIMARY_SUSPECT: %d\n', q_adaptation_suspect);
    fprintf('  Q11_INFLATION_PRIMARY_SUSPECT: %d\n', q11_inflation_suspect);
    fprintf('  VB_R_RECURSION_STILL_SUSPECT: %d\n', vb_r_recursion_suspect);
    
    % Innovation consistency analysis
    s0_dir_cons = median(res.S0_Static.EQ0.phase_data.NORMAL.directional_consistency, 'omitnan');
    s1_dir_cons = median(res.S1_Warp.EQ0.phase_data.NORMAL.directional_consistency, 'omitnan');
    
    s0_coh_frac = median(res.S0_Static.EQ0.phase_data.NORMAL.coherent_fraction, 'omitnan');
    s1_coh_frac = median(res.S1_Warp.EQ0.phase_data.NORMAL.coherent_fraction, 'omitnan');
    
    fprintf('\nInnovation Consistency in EQ0:\n');
    fprintf('  Directional Consistency S0 vs S1: %.3f vs %.3f\n', s0_dir_cons, s1_dir_cons);
    fprintf('  Coherent Fraction       S0 vs S1: %.3f vs %.3f\n', s0_coh_frac, s1_coh_frac);
    
    fprintf('\nRecommended next path (A, B, or C) must be based on these results.\n');
end
