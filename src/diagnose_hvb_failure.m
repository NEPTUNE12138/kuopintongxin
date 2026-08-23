function diagnose_hvb_failure(mode)
% DIAGNOSE_HVB_FAILURE Scientific diagnostic for Variant E dynamic tracking failure.

    if nargin < 1, mode = 'quick'; end
    
    % Use diagnostic parameters, but quick mode for fast execution
    cfg = paper2_config(mode);
    if strcmp(mode, 'quick')
        num_mc = 20; % 20 per scenario for quick
    else
        num_mc = 50; % 50 per scenario for full diagnostics
    end
    
    ch_file = cfg.channels{1, 1}; % Profile P1
    [h_chan, ~] = load_bellhop_cir(ch_file, cfg.fs);
    
    scenarios = {'S0_Static', 'S1_Warp', 'S2_Fade', 'S3_Warp_Fade'};
    variants = {'C', 'E', 'E-VB-only'};
    if strcmp(mode, 'E-CAL_Test') % Or if we want to run E-CAL
        variants{end+1} = 'E-CAL';
    end
    
    fprintf('\n=== Running HVB Diagnostic ===\n');
    fprintf('MC Trials/Scenario: %d\n', num_mc);
    
    % Preallocate results struct
    res = struct();
    for s = 1:length(scenarios)
        for v = 1:length(variants)
            vn = strrep(variants{v}, '-', '_');
            res.(scenarios{s}).(vn).rmse = NaN(1, num_mc);
            res.(scenarios{s}).(vn).rho_mean = NaN(1, num_mc);
            res.(scenarios{s}).(vn).m_mean = NaN(1, num_mc);
            res.(scenarios{s}).(vn).Lambda_mean = NaN(1, num_mc);
            res.(scenarios{s}).(vn).R_vb_mean = NaN(1, num_mc);
            res.(scenarios{s}).(vn).R_eff_R_vb_mean = NaN(1, num_mc);
            res.(scenarios{s}).(vn).K_mean = NaN(1, num_mc);
        end
    end
    
    out_dir = fullfile('results', 'diagnostic');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    for s = 1:length(scenarios)
        scen_name = scenarios{s};
        fprintf('\n--- Scenario: %s ---\n', scen_name);
        
        do_warp = contains(scen_name, 'Warp');
        do_fade = contains(scen_name, 'Fade');
        
        warp_cfg.v0_mps = 0.5;
        warp_cfg.velocity_amp_mps = 1.5;
        warp_cfg.velocity_freq_hz = 0.2;
        warp_cfg.phase_rad = 0;
        
        for mc = 1:num_mc
            if mod(mc, 10) == 0, fprintf('  Trial %d/%d\n', mc, num_mc); end
            
            % Diagnostic Seed (offset to avoid pilot overlap)
            rng_seed = cfg.master_seed + 1000000 + s*10000 + mc;
            rng(rng_seed, 'twister');
            
            [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
            rx_clean = filter(h_chan, 1, tx_pb);
            
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
                
                % Determine Fade Mask based on symbol centers
                sym_centers = pay_start + (0:cfg.num_diff_symbols-1) * cfg.symbol_samples + round(cfg.symbol_samples/2);
                sym_centers = min(length(rx_warp), max(1, sym_centers));
                if do_fade
                    fade_env_at_centers = fade_env(sym_centers);
                    fade_mask = fade_env_at_centers < 0.5;
                else
                    fade_mask = false(1, cfg.num_diff_symbols);
                end
                
                % Epsilon True
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
                            
                            res.(scen_name).(vn).rho_mean(mc) = mean(meta.rho);
                            res.(scen_name).(vn).m_mean(mc) = mean(meta.m_reliability);
                            res.(scen_name).(vn).Lambda_mean(mc) = mean(meta.Lambda);
                            if isfield(meta, 'R_vb')
                                res.(scen_name).(vn).R_vb_mean(mc) = mean(meta.R_vb);
                                res.(scen_name).(vn).R_eff_R_vb_mean(mc) = mean(meta.R_eff ./ max(meta.R_vb, eps));
                                res.(scen_name).(vn).K_mean(mc) = mean(meta.K_gain(1, :));
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
    end
    
    % Classification Logic
    fprintf('\n=== HVB Diagnostic Classification ===\n');
    
    % Check S1 (Warp) non-fade metrics
    % We compute medians over the valid trials for S1
    s1_C_rmse = median(res.S1_Warp.C.rmse, 'omitnan');
    s1_E_rmse = median(res.S1_Warp.E.rmse, 'omitnan');
    s1_EVB_rmse = median(res.S1_Warp.E_VB_only.rmse, 'omitnan');
    
    s1_E_m = median(res.S1_Warp.E.m_mean, 'omitnan');
    s1_E_Reff_ratio = median(res.S1_Warp.E.R_eff_R_vb_mean, 'omitnan');
    
    % RELIABILITY_SCALE_SUSPECT
    if s1_E_m < 0.8 || s1_E_Reff_ratio > 1.5
        fprintf('[!] RELIABILITY_SCALE_SUSPECT: yes\n');
        fprintf('    S1 median m = %.3f (threshold < 0.8)\n', s1_E_m);
        fprintf('    S1 median Reff/Rvb = %.3f (threshold > 1.5)\n', s1_E_Reff_ratio);
    else
        fprintf('[ ] RELIABILITY_SCALE_SUSPECT: no\n');
    end
    
    % VB_RECURSION_SUSPECT
    if s1_EVB_rmse > 1.5 * s1_C_rmse
        fprintf('[!] VB_RECURSION_SUSPECT: yes\n');
        fprintf('    S1 E-VB-only RMSE (%.3f) > 1.5 * C RMSE (%.3f)\n', s1_EVB_rmse, s1_C_rmse);
    else
        fprintf('[ ] VB_RECURSION_SUSPECT: no\n');
    end
    
    % HETERO_PENALTY_SUSPECT
    if (s1_EVB_rmse <= 1.5 * s1_C_rmse) && (s1_E_rmse > 1.5 * s1_EVB_rmse)
        fprintf('[!] HETERO_PENALTY_SUSPECT: yes\n');
        fprintf('    S1 E-VB-only is close to C, but E-original RMSE (%.3f) is much worse than E-VB-only (%.3f)\n', s1_E_rmse, s1_EVB_rmse);
    else
        fprintf('[ ] HETERO_PENALTY_SUSPECT: no\n');
    end
    
    csv_file = fullfile(out_dir, 'hvb_diagnostic_summary.csv');
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'Scenario,Variant,RMSE_Median,RMSE_Mean,m_Median,Reff_Rvb_Median\n');
    for s = 1:length(scenarios)
        for v = 1:length(variants)
            vn = strrep(variants{v}, '-', '_');
            fprintf(fid, '%s,%s,%.4f,%.4f,%.4f,%.4f\n', ...
                scenarios{s}, variants{v}, ...
                median(res.(scenarios{s}).(vn).rmse, 'omitnan'), ...
                mean(res.(scenarios{s}).(vn).rmse, 'omitnan'), ...
                median(res.(scenarios{s}).(vn).m_mean, 'omitnan'), ...
                median(res.(scenarios{s}).(vn).R_eff_R_vb_mean, 'omitnan'));
        end
    end
    fclose(fid);
    
    save(fullfile(out_dir, 'hvb_diagnostic_raw.mat'), 'res', 'scenarios', 'variants');
    fprintf('Saved diagnostics to %s\n', out_dir);
end
