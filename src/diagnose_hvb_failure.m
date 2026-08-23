function decision = diagnose_hvb_failure(mode)
% DIAGNOSE_HVB_FAILURE Scientific diagnostic for Variant E dynamic tracking failure.

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
    variants = {'C', 'E', 'E-VB-only', 'E-CAL'};
    
    fprintf('\n=== Running HVB Diagnostic ===\n');
    fprintf('MC Trials/Scenario: %d\n', num_mc);
    
    out_dir = fullfile(project_root, 'results', 'diagnostic');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    res = struct();
    
    % Store phase-level statistics
    fid_stat = fopen(fullfile(out_dir, 'hvb_diagnostic_phase_stats.csv'), 'w');
    fprintf(fid_stat, 'Scenario,Variant,Phase,Metric,Mean,Median,P10,P90\n');
    
    fid_sum = fopen(fullfile(out_dir, 'hvb_diagnostic_summary.csv'), 'w');
    fprintf(fid_sum, 'Scenario,Variant,RMSE_Median,RMSE_Mean,m_Median,Reff_Rvb_Median,ValidTrials,BER_Mean\n');
    
    metrics_list = {'rho_raw', 'rho_relative', 'm_reliability', 'Lambda', 'R_vb', 'R_eff', 'R_eff_R_vb', 'K_delay', 'Q11', 'Q22', 'abs_innovation', 'tracking_error'};
    
    for s = 1:length(scenarios)
        scen_name = scenarios{s};
        fprintf('\n--- Scenario: %s ---\n', scen_name);
        
        do_warp = contains(scen_name, 'Warp');
        do_fade = contains(scen_name, 'Fade');
        
        warp_cfg.v0_mps = 0.5;
        warp_cfg.velocity_amp_mps = 1.5;
        warp_cfg.velocity_freq_hz = 0.2;
        warp_cfg.phase_rad = 0;
        
        % Preallocate structs for MC accumulation
        for v = 1:length(variants)
            vn = strrep(variants{v}, '-', '_');
            res.(scen_name).(vn).rmse = NaN(1, num_mc);
            res.(scen_name).(vn).ber = NaN(1, num_mc);
            
            % To collect all symbols for percentile stats
            res.(scen_name).(vn).phase_data = struct();
        end
        
        for mc = 1:num_mc
            if mod(mc, 10) == 0, fprintf('  Trial %d/%d\n', mc, num_mc); end
            
            rng_seed = cfg.master_seed + 1000000 + s*10000 + mc;
            rng(rng_seed, 'twister');
            
            [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
            % Use full convolution
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
                
                % Determine Phase Masks
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
                    vc = variants{v};
                    vn = strrep(vc, '-', '_');
                    
                    try
                        [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_final, preamble, mseq_os, sync_meta, cfg, vc);
                        
                        if strcmp(meta.status, 'SUCCESS')
                            eps_est_rel = meta.delay_est_samples - meta.delay_est_samples(1);
                            err = eps_est_rel - eps_true_rel;
                            res.(scen_name).(vn).rmse(mc) = sqrt(mean(err.^2));
                            res.(scen_name).(vn).ber(mc) = sum(decoded_bits ~= data_bits) / cfg.num_data_bits;
                            
                            phase_names = fieldnames(phases);
                            for p_i = 1:length(phase_names)
                                p_name = phase_names{p_i};
                                p_idx = phases.(p_name);
                                if isempty(p_idx), continue; end
                                
                                % Collect metrics
                                if isfield(meta, 'rho_raw'), data_tmp.rho_raw = meta.rho_raw(p_idx); else data_tmp.rho_raw = NaN(size(p_idx)); end
                                if isfield(meta, 'rho_relative'), data_tmp.rho_relative = meta.rho_relative(p_idx); else data_tmp.rho_relative = NaN(size(p_idx)); end
                                data_tmp.m_reliability = meta.m_reliability(p_idx);
                                data_tmp.Lambda = meta.Lambda(p_idx);
                                if isfield(meta, 'R_vb')
                                    data_tmp.R_vb = meta.R_vb(p_idx);
                                    data_tmp.R_eff = meta.R_eff(p_idx);
                                    data_tmp.R_eff_R_vb = meta.R_eff(p_idx) ./ max(meta.R_vb(p_idx), eps);
                                    data_tmp.K_delay = meta.K_gain(1, p_idx);
                                    data_tmp.Q11 = meta.Q_diag(1, p_idx);
                                    data_tmp.Q22 = meta.Q_diag(2, p_idx);
                                else
                                    data_tmp.R_vb = NaN(size(p_idx)); data_tmp.R_eff = NaN(size(p_idx)); data_tmp.R_eff_R_vb = NaN(size(p_idx));
                                    data_tmp.K_delay = NaN(size(p_idx)); data_tmp.Q11 = NaN(size(p_idx)); data_tmp.Q22 = NaN(size(p_idx));
                                end
                                data_tmp.abs_innovation = NaN(size(p_idx)); % Approximation, we don't have direct innovation output
                                data_tmp.tracking_error = err(p_idx);
                                
                                % Accumulate
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
        
        % Export phase stats for this scenario
        for v = 1:length(variants)
            vn = strrep(variants{v}, '-', '_');
            
            % Summary stats
            valid_trials = sum(~isnan(res.(scen_name).(vn).rmse));
            med_rmse = median(res.(scen_name).(vn).rmse, 'omitnan');
            mean_rmse = mean(res.(scen_name).(vn).rmse, 'omitnan');
            mean_ber = mean(res.(scen_name).(vn).ber, 'omitnan');
            
            % Get overall m_median and Reff_Rvb_median for summary
            if do_fade
                if isfield(res.(scen_name).(vn).phase_data, 'PRE')
                    overall_m = median(res.(scen_name).(vn).phase_data.PRE.m_reliability, 'omitnan');
                    overall_rr = median(res.(scen_name).(vn).phase_data.PRE.R_eff_R_vb, 'omitnan');
                else
                    overall_m = NaN; overall_rr = NaN;
                end
            else
                if isfield(res.(scen_name).(vn).phase_data, 'NORMAL')
                    overall_m = median(res.(scen_name).(vn).phase_data.NORMAL.m_reliability, 'omitnan');
                    overall_rr = median(res.(scen_name).(vn).phase_data.NORMAL.R_eff_R_vb, 'omitnan');
                else
                    overall_m = NaN; overall_rr = NaN;
                end
            end
            
            fprintf(fid_sum, '%s,%s,%.4f,%.4f,%.4f,%.4f,%d,%.6f\n', scen_name, variants{v}, med_rmse, mean_rmse, overall_m, overall_rr, valid_trials, mean_ber);
            
            % Export detailed phase data
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
                        fprintf(fid_stat, '%s,%s,%s,%s,%.6f,%.6f,%.6f,%.6f\n', scen_name, variants{v}, p_name, m_str, m_mean, m_med, m_p10, m_p90);
                    end
                end
            end
        end
    end
    
    fclose(fid_stat);
    fclose(fid_sum);
    
    % Classification Logic & E-CAL Gate
    fprintf('\n=== E-CAL Scientific Gate & Classification ===\n');
    
    % 1. Extract values
    % Normal behavior (from S0 Static NORMAL or S1 Warp NORMAL)
    ecal_s0_m = median(res.S0_Static.E_CAL.phase_data.NORMAL.m_reliability, 'omitnan');
    ecal_s0_rr = median(res.S0_Static.E_CAL.phase_data.NORMAL.R_eff_R_vb, 'omitnan');
    
    ecal_s2_m_norm = median(res.S2_Fade.E_CAL.phase_data.PRE.m_reliability, 'omitnan');
    ecal_s2_m_fade = median(res.S2_Fade.E_CAL.phase_data.FADE.m_reliability, 'omitnan');
    ecal_s2_rr_norm = median(res.S2_Fade.E_CAL.phase_data.PRE.R_eff_R_vb, 'omitnan');
    ecal_s2_rr_fade = median(res.S2_Fade.E_CAL.phase_data.FADE.R_eff_R_vb, 'omitnan');
    
    ecal_s1_rmse = median(res.S1_Warp.E_CAL.rmse, 'omitnan');
    c_s1_rmse = median(res.S1_Warp.C.rmse, 'omitnan');
    e_s1_rmse = median(res.S1_Warp.E.rmse, 'omitnan');
    
    ecal_s3_rmse = median(res.S3_Warp_Fade.E_CAL.rmse, 'omitnan');
    c_s3_rmse = median(res.S3_Warp_Fade.C.rmse, 'omitnan');
    e_s3_rmse = median(res.S3_Warp_Fade.E.rmse, 'omitnan');
    
    pass_normal = (ecal_s0_m >= 0.90) && (ecal_s0_rr <= 1.15);
    pass_fade = (ecal_s2_m_fade < ecal_s2_m_norm) && (ecal_s2_rr_fade > ecal_s2_rr_norm);
    
    % For K fade:
    ecal_s2_k_norm = median(res.S2_Fade.E_CAL.phase_data.PRE.K_delay, 'omitnan');
    ecal_s2_k_fade = median(res.S2_Fade.E_CAL.phase_data.FADE.K_delay, 'omitnan');
    pass_fade_k = (ecal_s2_k_fade < ecal_s2_k_norm);
    
    pass_warp = (ecal_s1_rmse <= 1.25 * c_s1_rmse);
    pass_warp_fade = (ecal_s3_rmse <= 1.25 * c_s3_rmse);
    
    fprintf('Normal Behavior (S0): m=%.3f (>=0.90), Reff/Rvb=%.3f (<=1.15) -> %d\n', ecal_s0_m, ecal_s0_rr, pass_normal);
    fprintf('Fade Response (S2): m_fade(%.3f) < m_norm(%.3f), Reff/Rvb_fade(%.3f) > Reff/Rvb_norm(%.3f), K_fade(%.3f) < K_norm(%.3f) -> %d\n', ...
        ecal_s2_m_fade, ecal_s2_m_norm, ecal_s2_rr_fade, ecal_s2_rr_norm, ecal_s2_k_fade, ecal_s2_k_norm, pass_fade && pass_fade_k);
    fprintf('Dynamic Tracking S1: E-CAL_RMSE(%.3f) <= 1.25 * C_RMSE(%.3f) -> %d\n', ecal_s1_rmse, c_s1_rmse, pass_warp);
    fprintf('Dynamic Tracking S3: E-CAL_RMSE(%.3f) <= 1.25 * C_RMSE(%.3f) -> %d\n', ecal_s3_rmse, c_s3_rmse, pass_warp_fade);
    
    fprintf('\nE-CAL vs E-original in S1 Warp: %.3f vs %.3f\n', ecal_s1_rmse, e_s1_rmse);
    
    fprintf('\nRMSE ratios E-CAL/C:\n');
    fprintf('  S1 (Warp): %.3f\n', ecal_s1_rmse / c_s1_rmse);
    fprintf('  S3 (Warp+Fade): %.3f\n', ecal_s3_rmse / c_s3_rmse);
    
    all_pass = pass_normal && pass_fade && pass_fade_k && pass_warp && pass_warp_fade && (ecal_s1_rmse < e_s1_rmse);
    
    if all_pass
        fprintf('\nECAL_MECHANISM_GATE_PASS\n');
    else
        fprintf('\nECAL_NOT_ACCEPTED_FOR_FINAL_METHOD\n');
    end
    
    decision = struct();
    decision.passed = all_pass;
    
    save(fullfile(out_dir, 'hvb_diagnostic_raw.mat'), 'res', 'scenarios', 'variants');
    fprintf('Saved diagnostics to %s\n', out_dir);
end
