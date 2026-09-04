function [csv_file, run_meta] = main_WUWNET_Paper_Stress(mode, snr_override, mc_override)
% MAIN_WUWNET_PAPER_STRESS Reliability-ablation stress test.
% Usage: [csv_file, run_meta] = main_WUWNET_Paper_Stress('quick', 15, 20)

    if nargin < 1
        mode = 'quick';
    end
    
    cfg = paper2_config(mode);
    
    if nargin >= 2 && ~isempty(snr_override)
        snr_db = snr_override(1);
    else
        snr_db = cfg.stress_snr_db;
    end
    
    if nargin >= 3 && ~isempty(mc_override)
        cfg.mc_trials_stress = mc_override;
    end
    
    variants = {'A', 'VB-FQ', 'R-FQ', 'E-FQ'};
    csv_labels = {'IAE', 'VB-FQ', 'R-FQ', 'E-FQ'};
    num_variants = length(variants);
    
    num_mc = cfg.mc_trials_stress;
    num_channels = size(cfg.channels, 1);
    
    fprintf('\n=== Starting Stress Test (%s) ===\n', upper(mode));
    fprintf('MC Trials: %d | Channels: %d | SNR: %d dB\n', num_mc, num_channels, snr_db);
    
    % Strengthening artifacts are isolated from all frozen result folders.
    out_dir = fullfile('results', 'paper_strengthening', 'RFQ_ablation');
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end
    
    num_syms = cfg.num_diff_symbols;
    
    results = struct();
    for ch_idx = 1:num_channels
        ch_key = sprintf('CH%d', ch_idx);
        for v = 1:num_variants
            vc = strrep(variants{v}, '-', '_');
            results.(ch_key).(vc).rmse_pre = NaN(1, num_mc);
            results.(ch_key).(vc).rmse_fade = NaN(1, num_mc);
            results.(ch_key).(vc).rmse_post = NaN(1, num_mc);
            results.(ch_key).(vc).rmse_overall = NaN(1, num_mc);
            
            results.(ch_key).(vc).m_pre = NaN(1, num_mc);
            results.(ch_key).(vc).m_fade = NaN(1, num_mc);
            results.(ch_key).(vc).m_post = NaN(1, num_mc);
            
            results.(ch_key).(vc).mean_Reff_Rvb_pre = NaN(1, num_mc);
            results.(ch_key).(vc).mean_Reff_Rvb_fade = NaN(1, num_mc);
            results.(ch_key).(vc).mean_Reff_Rvb_post = NaN(1, num_mc);
            
            results.(ch_key).(vc).mean_K_pre = NaN(1, num_mc);
            results.(ch_key).(vc).mean_K_fade = NaN(1, num_mc);
            results.(ch_key).(vc).mean_K_post = NaN(1, num_mc);
            
            results.(ch_key).(vc).Q11_pre = NaN(1, num_mc);
            results.(ch_key).(vc).Q11_fade = NaN(1, num_mc);
            results.(ch_key).(vc).Q11_post = NaN(1, num_mc);
            
            results.(ch_key).(vc).Q22_pre = NaN(1, num_mc);
            results.(ch_key).(vc).Q22_fade = NaN(1, num_mc);
            results.(ch_key).(vc).Q22_post = NaN(1, num_mc);
            
            % Legacy summary fields kept for CSV compatibility
            results.(ch_key).(vc).mean_Reff_fade = NaN(1, num_mc);
            results.(ch_key).(vc).Ppred11_fade = NaN(1, num_mc);
            results.(ch_key).(vc).Ppred22_fade = NaN(1, num_mc);
            results.(ch_key).(vc).ber = NaN(1, num_mc);
            results.(ch_key).(vc).valid = false(1, num_mc);
            results.(ch_key).(vc).raw_errors = NaN(1, num_mc);
        end
    end
    
    total_iters = num_channels * num_mc;
    iter_count = 0;
    
    for ch_idx = 1:num_channels
        ch_file = cfg.channels{ch_idx, 1};
        ch_key = sprintf('CH%d', ch_idx);
        [h_cir, ~] = select_bellhop_local_cluster(ch_file, cfg);
        
        fprintf('Processing %s at %d dB...\n', cfg.channels{ch_idx, 2}, snr_db);
        
        for mc = 1:num_mc
            iter_count = iter_count + 1;
            if mod(iter_count, 10) == 0 || total_iters < 100
                fprintf('  Prog: %d/%d (%.1f%%)\n', iter_count, total_iters, 100*iter_count/total_iters);
            end
            
            % Deterministic Seed
            rng_seed = cfg.master_seed + mc + 999000 + ch_idx*10000;
            rng(rng_seed, 'twister');
            
            % 1. Generate Signal
            [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
            
            % 2. Apply Channel
            rx_multi = conv(tx_pb, h_cir, 'full');
            
            % 3. Apply Continuous Time-Warping
            t = (0:length(rx_multi)-1) / cfg.fs;
            
            warp_cfg.v0_mps = 0.5;
            warp_cfg.velocity_amp_mps = 1.5;
            warp_cfg.velocity_freq_hz = 0.2;
            warp_cfg.phase_rad = 0;
            
            [rx_warp, warp_meta] = apply_paper2_time_warp(rx_multi, cfg, warp_cfg);
            epsilon_true_samples = warp_meta.epsilon_true_samples;
            
            % 4. Add Deep Fades (Amplitude Modulation)
            packet_duration = length(rx_warp) / cfg.fs;
            fade_center = packet_duration / 2;
            fade_width = 0.1; % 100ms fade
            
            fade_env = 1 - 0.9 * exp(-0.5 * ((t - fade_center) / (fade_width / 3)).^2);
            rx_fade = rx_warp .* fade_env;
            
            % 5. Add Noise
            rx_power = norm(rx_fade)^2 / length(rx_fade);
            noise_power = rx_power / (10^(snr_db / 10));
            noise = sqrt(noise_power/2) * (randn(size(rx_fade)) + 1j * randn(size(rx_fade)));
            rx_final = rx_fade + noise;
            
            % 6. Coarse Sync
            [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_final, preamble, cfg);
            sync_meta.peak_idx = peak_idx;
            sync_meta.preamble_start = p_start;
            sync_meta.payload_start = pay_start;
            sync_meta.mf = mf;
            
            % Ground truth at symbol centers
            sym_centers = pay_start + (0:num_syms-1) * cfg.symbol_samples + round(cfg.symbol_samples/2);
            sym_centers = min(length(epsilon_true_samples), max(1, sym_centers));
            eps_true_per_symbol = epsilon_true_samples(sym_centers);
            eps_true_rel = eps_true_per_symbol - eps_true_per_symbol(1);
            
            fade_env_at_centers = fade_env(sym_centers);
            fmask = fade_env_at_centers < 0.5;
            first_fade = find(fmask, 1, 'first');
            last_fade = find(fmask, 1, 'last');
            
            pre_idx = 1:(first_fade-1);
            fade_idx = first_fade:last_fade;
            post_idx = (last_fade+1):cfg.num_diff_symbols;
            
            % 7. Run Trackers
            for v = 1:num_variants
                vc_key = strrep(variants{v}, '-', '_');
                
                try
                    [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_final, preamble, mseq_os, sync_meta, cfg, variants{v});
                    
                    if strcmp(meta.status, 'SUCCESS') && length(decoded_bits) == cfg.num_data_bits
                        errors = sum(decoded_bits ~= data_bits(1:length(decoded_bits)));
                        results.(ch_key).(vc_key).ber(mc) = errors / cfg.num_data_bits;
                        results.(ch_key).(vc_key).raw_errors(mc) = errors;
                        results.(ch_key).(vc_key).valid(mc) = true;
                        
                        eps_est_rel = meta.delay_est_samples - meta.delay_est_samples(1);
                        err = eps_est_rel - eps_true_rel;
                        
                        results.(ch_key).(vc_key).rmse_pre(mc) = sqrt(mean(err(pre_idx).^2));
                        results.(ch_key).(vc_key).rmse_fade(mc) = sqrt(mean(err(fade_idx).^2));
                        results.(ch_key).(vc_key).rmse_post(mc) = sqrt(mean(err(post_idx).^2));
                        results.(ch_key).(vc_key).rmse_overall(mc) = sqrt(mean(err.^2));
                        
                        if isfield(meta, 'm_reliability')
                            results.(ch_key).(vc_key).m_pre(mc) = median(meta.m_reliability(pre_idx), 'omitnan');
                            results.(ch_key).(vc_key).m_fade(mc) = median(meta.m_reliability(fade_idx), 'omitnan');
                            results.(ch_key).(vc_key).m_post(mc) = median(meta.m_reliability(post_idx), 'omitnan');
                        end
                        
                        if isfield(meta, 'R_eff') && isfield(meta, 'R_vb')
                            ratio = meta.R_eff ./ max(meta.R_vb, eps);
                            results.(ch_key).(vc_key).mean_Reff_Rvb_pre(mc) = median(ratio(pre_idx), 'omitnan');
                            results.(ch_key).(vc_key).mean_Reff_Rvb_fade(mc) = median(ratio(fade_idx), 'omitnan');
                            results.(ch_key).(vc_key).mean_Reff_Rvb_post(mc) = median(ratio(post_idx), 'omitnan');
                        end
                        
                        if isfield(meta, 'K_gain')
                            results.(ch_key).(vc_key).mean_K_pre(mc) = median(meta.K_gain(1, pre_idx), 'omitnan');
                            results.(ch_key).(vc_key).mean_K_fade(mc) = median(meta.K_gain(1, fade_idx), 'omitnan');
                            results.(ch_key).(vc_key).mean_K_post(mc) = median(meta.K_gain(1, post_idx), 'omitnan');
                        end
                        
                        if isfield(meta, 'Q_diag')
                            results.(ch_key).(vc_key).Q11_pre(mc) = median(meta.Q_diag(1, pre_idx), 'omitnan');
                            results.(ch_key).(vc_key).Q11_fade(mc) = median(meta.Q_diag(1, fade_idx), 'omitnan');
                            results.(ch_key).(vc_key).Q11_post(mc) = median(meta.Q_diag(1, post_idx), 'omitnan');
                            
                            results.(ch_key).(vc_key).Q22_pre(mc) = median(meta.Q_diag(2, pre_idx), 'omitnan');
                            results.(ch_key).(vc_key).Q22_fade(mc) = median(meta.Q_diag(2, fade_idx), 'omitnan');
                            results.(ch_key).(vc_key).Q22_post(mc) = median(meta.Q_diag(2, post_idx), 'omitnan');
                        end
                        
                        if isfield(meta, 'R_eff')
                            results.(ch_key).(vc_key).mean_Reff_fade(mc) = mean(meta.R_eff(fade_idx));
                        end
                        
                        if isfield(meta, 'P_pred_diag')
                            results.(ch_key).(vc_key).Ppred11_fade(mc) = mean(meta.P_pred_diag(1, fade_idx));
                            results.(ch_key).(vc_key).Ppred22_fade(mc) = mean(meta.P_pred_diag(2, fade_idx));
                        end
                    end
                catch ME
                    if ~strcmp(ME.identifier, 'Paper2:SyncFail')
                        rethrow(ME);
                    end
                end
            end
        end
    end
    
    % Metrics and CSV Export
    fprintf('\n--- Stress Test Summary ---\n');
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    csv_file = fullfile(out_dir, sprintf('RFQ_ablation_summary_%s.csv', timestamp));
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'Channel,Variant,Trials_Valid,SyncFailRate,FER_Overall,FER_Valid,BER_Valid,RMSE,RMSE_CI95_Lower,RMSE_CI95_Upper,fade_RMSE,fade_RMSE_CI95_Lower,fade_RMSE_CI95_Upper,RMSE_Pre,RMSE_Post,Mean_K_Fade,Mean_Reff_Fade,Mean_Reff_Rvb_Fade,Median_Q11_Fade,Median_Q22_Fade,Median_Ppred11_Fade,Median_Ppred22_Fade\n');

    % A separate deterministic stream makes CI values reproducible without
    % affecting any paired signal/channel/noise realization above.
    ci_seed = cfg.master_seed + 424242;
    rng(ci_seed, 'twister');
    ci_resamples = 2000;
    
    for ch_idx = 1:num_channels
        ch_key = sprintf('CH%d', ch_idx);
        for v = 1:num_variants
            vc_key = strrep(variants{v}, '-', '_');
            label = csv_labels{v};
            
            valid_mask = results.(ch_key).(vc_key).valid;
            
            stats = compute_paper2_ber_statistics(results.(ch_key).(vc_key).raw_errors, valid_mask, cfg.num_data_bits);
            
            m_rmse = median(results.(ch_key).(vc_key).rmse_overall(valid_mask), 'omitnan');
            m_pre = median(results.(ch_key).(vc_key).rmse_pre(valid_mask), 'omitnan');
            m_fade = median(results.(ch_key).(vc_key).rmse_fade(valid_mask), 'omitnan');
            m_post = median(results.(ch_key).(vc_key).rmse_post(valid_mask), 'omitnan');
            m_k = median(results.(ch_key).(vc_key).mean_K_fade(valid_mask), 'omitnan');
            m_reff = median(results.(ch_key).(vc_key).mean_Reff_fade(valid_mask), 'omitnan');
            m_rr = median(results.(ch_key).(vc_key).mean_Reff_Rvb_fade(valid_mask), 'omitnan');
            m_q11 = median(results.(ch_key).(vc_key).Q11_fade(valid_mask), 'omitnan');
            m_q22 = median(results.(ch_key).(vc_key).Q22_fade(valid_mask), 'omitnan');
            m_p11 = median(results.(ch_key).(vc_key).Ppred11_fade(valid_mask), 'omitnan');
            m_p22 = median(results.(ch_key).(vc_key).Ppred22_fade(valid_mask), 'omitnan');

            rmse_ci = bootstrap_median_ci(results.(ch_key).(vc_key).rmse_overall(valid_mask), ci_resamples);
            fade_rmse_ci = bootstrap_median_ci(results.(ch_key).(vc_key).rmse_fade(valid_mask), ci_resamples);
            
            fprintf(fid, '%s,%s,%d,%.4f,%.4f,%.4f,%.6f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
                cfg.channels{ch_idx, 2}, label, stats.Trials_Valid, stats.SyncFailRate, ...
                stats.FER_Overall, stats.FER_Valid, stats.BER_Valid, m_rmse, rmse_ci(1), rmse_ci(2), ...
                m_fade, fade_rmse_ci(1), fade_rmse_ci(2), m_pre, m_post, m_k, m_reff, m_rr, m_q11, m_q22, m_p11, m_p22);
        end
    end
    fclose(fid);
    
    save_file = fullfile(out_dir, sprintf('RFQ_ablation_raw_%s_%s.mat', mode, timestamp));
    save(save_file, 'results', 'cfg', 'variants', 'csv_labels', 'mode', 'ci_seed', 'ci_resamples');
    fprintf('Stress results saved to:\n  %s\n  %s\n', save_file, csv_file);
    
    run_meta.variants_internal = variants;
    run_meta.variant_labels = csv_labels;
    run_meta.stress_snr_db = snr_db;
    run_meta.num_mc = cfg.mc_trials_stress;
    run_meta.frontend_use_trm = cfg.frontend.use_trm;
    run_meta.equalizer_enabled = cfg.equalizer.enabled;
    run_meta.final_tracker_variant = cfg.final_tracker_variant;
    run_meta.c2 = cfg.c2;
    run_meta.Q = cfg.final_Q;
    run_meta.has_all_profiles = (num_channels == 3);
    run_meta.output_dir = out_dir;
    run_meta.raw_file = save_file;
    run_meta.summary_file = csv_file;
    run_meta.ci_seed = ci_seed;
    run_meta.ci_resamples = ci_resamples;
end

function ci = bootstrap_median_ci(values, n_resamples)
% BOOTSTRAP_MEDIAN_CI Deterministic percentile 95% CI for the median.
    values = values(isfinite(values));
    n = numel(values);
    if n == 0
        ci = [NaN, NaN];
        return;
    elseif n == 1
        ci = [values(1), values(1)];
        return;
    end

    boot_medians = zeros(n_resamples, 1);
    for b = 1:n_resamples
        sample_idx = randi(n, n, 1);
        boot_medians(b) = median(values(sample_idx));
    end
    ci = prctile(boot_medians, [2.5, 97.5]);
end
