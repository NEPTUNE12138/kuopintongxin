function [csv_file, run_meta] = main_WUWNET_Paper_Strengthening_Stage4_v2(mc_override)
% MAIN_WUWNET_PAPER_STRENGTHENING_STAGE4_V2 Standard KF Baseline
    mode = 'paper';
    cfg = paper2_config(mode);
    snr_db = cfg.stress_snr_db; % 15 dB default
    
    if nargin >= 1 && ~isempty(mc_override)
        num_mc = mc_override;
    else
        num_mc = 200; % Start with 200 trials for pilot
    end
    
    variants = {'A', 'KF-FQ', 'VB-FQ', 'E-FQ'};
    csv_labels = {'IAE', 'KF-FQ', 'VB-FQ', 'E-FQ'};
    num_variants = length(variants);
    
    num_channels = size(cfg.channels, 1);
    
    fprintf('\n=== Starting STAGE 4 V2: Standard KF Baseline ===\n');
    fprintf('MC Trials: %d | Channels: %d | SNR: %d dB\n', num_mc, num_channels, snr_db);
    
    out_dir = fullfile('results', 'paper_strengthening_v2');
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
            
            results.(ch_key).(vc).mean_Reff_fade = NaN(1, num_mc);
            results.(ch_key).(vc).mean_K_fade = NaN(1, num_mc);
            results.(ch_key).(vc).Q11_fade = NaN(1, num_mc);
            results.(ch_key).(vc).Q22_fade = NaN(1, num_mc);
            
            results.(ch_key).(vc).ber = NaN(1, num_mc);
            results.(ch_key).(vc).valid = false(1, num_mc);
            results.(ch_key).(vc).raw_errors = NaN(1, num_mc);
        end
    end
    
    for ch_idx = 1:num_channels
        ch_file = cfg.channels{ch_idx, 1};
        ch_key = sprintf('CH%d', ch_idx);
        [h_cir, ~] = select_bellhop_local_cluster(ch_file, cfg);
        
        fprintf('Processing %s at %d dB...\n', cfg.channels{ch_idx, 2}, snr_db);
        
        for mc = 1:num_mc
            if mod(mc, 10) == 0, fprintf('  Prog: %d/%d (%.1f%%)\n', mc, num_mc, 100*mc/num_mc); end
            
            rng_seed = cfg.master_seed + mc + 999000 + ch_idx*10000;
            rng(rng_seed, 'twister');
            
            [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
            rx_multi = conv(tx_pb, h_cir, 'full');
            
            t = (0:length(rx_multi)-1) / cfg.fs;
            warp_cfg.v0_mps = 0.5;
            warp_cfg.velocity_amp_mps = 1.5;
            warp_cfg.velocity_freq_hz = 0.2;
            warp_cfg.phase_rad = 0;
            [rx_warp, warp_meta] = apply_paper2_time_warp(rx_multi, cfg, warp_cfg);
            epsilon_true_samples = warp_meta.epsilon_true_samples;
            
            packet_duration = length(rx_warp) / cfg.fs;
            fade_center = packet_duration / 2;
            fade_width = 0.1;
            fade_env = 1 - 0.9 * exp(-0.5 * ((t - fade_center) / (fade_width / 3)).^2);
            rx_fade = rx_warp .* fade_env;
            
            rx_power = norm(rx_fade)^2 / length(rx_fade);
            noise_power = rx_power / (10^(snr_db / 10));
            noise = sqrt(noise_power/2) * (randn(size(rx_fade)) + 1j * randn(size(rx_fade)));
            rx_final = rx_fade + noise;
            
            [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_final, preamble, cfg);
            sync_meta.peak_idx = peak_idx;
            sync_meta.preamble_start = p_start;
            sync_meta.payload_start = pay_start;
            sync_meta.mf = mf;
            
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
                    end
                catch ME
                    if ~strcmp(ME.identifier, 'Paper2:SyncFail')
                        rethrow(ME);
                    end
                end
            end
        end
    end
    
    csv_file = fullfile(out_dir, 'KF_extended_stress_200mc.csv');
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'Channel,Variant,Trials_Valid,SyncFailRate,BER_Valid,RMSE_Overall,RMSE_Pre,RMSE_Fade,RMSE_Post\n');
    
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
            
            fprintf(fid, '%s,%s,%d,%.4f,%.6f,%.4f,%.4f,%.4f,%.4f\n', ...
                cfg.channels{ch_idx, 2}, label, stats.Trials_Valid, stats.SyncFailRate, ...
                stats.BER_Valid, m_rmse, m_pre, m_fade, m_post);
        end
    end
    fclose(fid);
    
    % Paired Difference
    diff_file = fullfile(out_dir, 'KF_extended_paired_effects_200mc.csv');
    fid2 = fopen(diff_file, 'w');
    fprintf(fid2, 'ProfileID,Paired_Diff_EFQ_minus_KFFQ_FadeRMSE,CI95_Lower,CI95_Upper,EFQ_WinRate\n');
    
    for ch_idx = 1:num_channels
        ch_key = sprintf('CH%d', ch_idx);
        valid_both = results.(ch_key).E_FQ.valid & results.(ch_key).KF_FQ.valid;
        if sum(valid_both) > 10
            diffs = results.(ch_key).E_FQ.rmse_fade(valid_both) - results.(ch_key).KF_FQ.rmse_fade(valid_both);
            med_diff = median(diffs);
            boot_diff = bootstrp(1000, @median, diffs);
            ci = prctile(boot_diff, [2.5, 97.5]);
            win_rate = sum(diffs < 0) / length(diffs);
            
            fprintf(fid2, 'P%d,%.4f,%.4f,%.4f,%.4f\n', ch_idx, med_diff, ci(1), ci(2), win_rate);
        else
            fprintf(fid2, 'P%d,NaN,NaN,NaN,NaN\n', ch_idx);
        end
    end
    fclose(fid2);
end
