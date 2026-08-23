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
    
    results = struct();
    for v = 1:num_variants
        vc = variants{v};
        results.(vc).rmse = NaN(1, num_mc);
        results.(vc).ber = NaN(1, num_mc);
        
        % We only save the last valid trial's meta for plotting (to save space)
        results.(vc).sample_meta = [];
        results.(vc).sample_eps_true = [];
    end
    
    [h_cir, ~] = load_bellhop_cir(ch_file, cfg.fs);
    
    for mc = 1:num_mc
        if mod(mc, 10) == 0 || num_mc < 100
            fprintf('  Prog: %d/%d (%.1f%%)\n', mc, num_mc, 100*mc/num_mc);
        end
        
        % 1. Generate Signal
        [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
        
        % 2. Apply Channel
        rx_multi = filter(h_cir, 1, tx_pb);
        
        % 3. Apply Continuous Time-Warping
        t = (0:length(rx_multi)-1) / cfg.fs;
        
        % Dynamic Profile: Sinusoidal speed variation
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
        % Apply a severe fade in the middle of the packet
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
                    
                    eps_est_rel = meta.delay_est_samples - meta.delay_est_samples(1);
                    err = eps_est_rel - eps_true_rel;
                    results.(vc).rmse(mc) = sqrt(mean(err.^2));
                    
                    % Save one valid sample
                    results.(vc).sample_meta = meta;
                    results.(vc).sample_eps_true = eps_true_rel;
                else
                    results.(vc).ber(mc) = NaN;
                    results.(vc).rmse(mc) = NaN;
                end
            catch ME
                if strcmp(ME.identifier, 'Paper2:SyncFail')
                    results.(vc).ber(mc) = NaN;
                    results.(vc).rmse(mc) = NaN;
                else
                    rethrow(ME);
                end
            end
        end
    end
    
    % Metrics
    fprintf('\n--- Stress Test Summary ---\n');
    for v = 1:num_variants
        vc = variants{v};
        valid_mask = ~isnan(results.(vc).ber);
        valid_count = sum(valid_mask);
        
        fprintf('Variant %s:\n', vc);
        fprintf('  Valid Trials: %d/%d (%.1f%%)\n', valid_count, num_mc, 100*valid_count/num_mc);
        if valid_count > 0
            fprintf('  Mean BER: %.4f\n', mean(results.(vc).ber(valid_mask)));
            fprintf('  Mean RMSE: %.4f samples\n', mean(results.(vc).rmse(valid_mask)));
        end
    end
    
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    save_file = fullfile(out_dir, sprintf('paper2_stress_%s_%s.mat', mode, timestamp));
    save(save_file, 'results', 'cfg', 'variants', 'mode');
    fprintf('Stress results saved to: %s\n', save_file);
end
