function main_WUWNET_Paper_Stress(mode)
% MAIN_WUWNET_PAPER_STRESS End-to-end Tracking Stress Test (Delay Variation & Fading)
% Usage: main_WUWNET_Paper_Stress('quick')

    if nargin < 1
        mode = 'quick';
    end
    
    cfg = paper2_config(mode);
    variants = {'C', 'D', 'E'}; % Stress test focuses on dynamic trackers
    num_variants = length(variants);
    
    num_mc = cfg.mc_trials_stress;
    ch_file = cfg.channels{1, 1}; % Usually run on Profile 1
    
    fprintf('\n=== Starting Stress Test (%s) ===\n', upper(mode));
    fprintf('MC Trials: %d | Channel: %s\n', num_mc, cfg.channels{1, 2});
    
    out_dir = fullfile('results', mode);
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end
    
    % Data structures to save per variant
    num_syms = cfg.num_diff_symbols;
    
    % Zones for stats
    z1_start = 1; z1_end = floor(num_syms/3);
    z2_start = z1_end + 1; z2_end = floor(2*num_syms/3);
    z3_start = z2_end + 1; z3_end = num_syms;
    
    results = struct();
    for v = 1:num_variants
        vc = variants{v};
        results.(vc).rmse_pre = NaN(1, num_mc);
        results.(vc).rmse_fade = NaN(1, num_mc);
        results.(vc).rmse_post = NaN(1, num_mc);
        results.(vc).mean_K_fade = NaN(1, num_mc);
        results.(vc).mean_Reff_fade = NaN(1, num_mc);
        results.(vc).ber = NaN(1, num_mc);
        results.(vc).valid = false(1, num_mc);
        
        % We only save the last valid trial's meta for plotting (to save space)
        results.(vc).sample_meta = [];
        results.(vc).sample_eps_true = [];
    end
    
    [h_cir, ~] = select_bellhop_local_cluster(ch_file, cfg);
    
    for mc = 1:num_mc
        if mod(mc, 10) == 0 || num_mc < 100
            fprintf('  Prog: %d/%d (%.1f%%)\n', mc, num_mc, 100*mc/num_mc);
        end
        
        % Deterministic Seed
        rng_seed = cfg.master_seed + mc + 999000;
        rng(rng_seed, 'twister');
        
        % 1. Generate Signal
        [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
        
        % 2. Apply Channel
        rx_multi = conv(tx_pb, h_cir, 'full');
        
        % 3. Apply Continuous Time-Warping
        t = (0:length(rx_multi)-1) / cfg.fs;
        
        v0 = 0.5; % 0.5 m/s mean
        A_v = 1.5; % 1.5 m/s amplitude
        f_v = 0.2; % 0.2 Hz
        c_sound = 1500;
        
        alpha = 1 + (v0 + A_v * sin(2 * pi * f_v * t)) / c_sound;
        t_src = cumtrapz(t, alpha);
        t_src = t_src - t_src(1);
        
        rx_warp = interp1(t, rx_multi, t_src, 'linear', 0);
        
        % Calculate Ground Truth Delay
        epsilon_true_samples = (t - t_src) * cfg.fs;
        
        % 4. Add Deep Fades (Amplitude Modulation)
        fade_mask = ones(size(rx_warp));
        packet_duration = length(rx_warp) / cfg.fs;
        fade_center = packet_duration / 2;
        fade_width = 0.1; % 100ms fade
        
        fade_env = 1 - 0.9 * exp(-0.5 * ((t - fade_center) / (fade_width / 3)).^2);
        rx_fade = rx_warp .* fade_env;
        
        % 5. Add Noise
        snr_db = 15; % High SNR to isolate tracking errors
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
        
        % 7. Run Trackers
        for v = 1:num_variants
            vc = variants{v};
            
            try
                [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_final, preamble, mseq_os, sync_meta, cfg, vc);
                
                if strcmp(meta.status, 'SUCCESS') && length(decoded_bits) == cfg.num_data_bits
                    errors = sum(decoded_bits ~= data_bits(1:length(decoded_bits)));
                    results.(vc).ber(mc) = errors / cfg.num_data_bits;
                    results.(vc).valid(mc) = true;
                    
                    eps_est_rel = meta.delay_est_samples - meta.delay_est_samples(1);
                    err = eps_est_rel - eps_true_rel;
                    
                    results.(vc).rmse_pre(mc) = sqrt(mean(err(z1_start:z1_end).^2));
                    results.(vc).rmse_fade(mc) = sqrt(mean(err(z2_start:z2_end).^2));
                    results.(vc).rmse_post(mc) = sqrt(mean(err(z3_start:z3_end).^2));
                    results.(vc).mean_K_fade(mc) = mean(meta.K_gain(1, z2_start:z2_end));
                    results.(vc).mean_Reff_fade(mc) = mean(meta.R_eff(z2_start:z2_end));
                    
                    % Save one valid sample
                    results.(vc).sample_meta = meta;
                    results.(vc).sample_eps_true = eps_true_rel;
                end
            catch ME
                if ~strcmp(ME.identifier, 'Paper2:SyncFail')
                    rethrow(ME);
                end
            end
        end
    end
    
    % Metrics and CSV Export
    fprintf('\n--- Stress Test Summary ---\n');
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    csv_file = fullfile(out_dir, sprintf('paper2_stress_summary_%s.csv', timestamp));
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'Variant,Valid_Rate,Mean_BER,RMSE_Pre,RMSE_Fade,RMSE_Post,Mean_K_Fade,Mean_Reff_Fade\n');
    
    for v = 1:num_variants
        vc = variants{v};
        valid_mask = results.(vc).valid;
        valid_count = sum(valid_mask);
        valid_rate = valid_count / num_mc;
        
        m_ber = mean(results.(vc).ber(valid_mask));
        m_pre = mean(results.(vc).rmse_pre(valid_mask));
        m_fade = mean(results.(vc).rmse_fade(valid_mask));
        m_post = mean(results.(vc).rmse_post(valid_mask));
        m_k = mean(results.(vc).mean_K_fade(valid_mask));
        m_reff = mean(results.(vc).mean_Reff_fade(valid_mask));
        
        fprintf('Variant %s:\n', vc);
        fprintf('  Valid Trials: %d/%d (%.1f%%)\n', valid_count, num_mc, 100*valid_rate);
        if valid_count > 0
            fprintf('  Mean BER: %.4f\n', m_ber);
            fprintf('  RMSE Pre/Fade/Post: %.4f / %.4f / %.4f samples\n', m_pre, m_fade, m_post);
        end
        
        fprintf(fid, '%s,%.4f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n', ...
            vc, valid_rate, m_ber, m_pre, m_fade, m_post, m_k, m_reff);
    end
    fclose(fid);
    
    save_file = fullfile(out_dir, sprintf('paper2_stress_%s_%s.mat', mode, timestamp));
    save(save_file, 'results', 'cfg', 'variants', 'mode');
    fprintf('Stress results saved to:\n  %s\n  %s\n', save_file, csv_file);
end
