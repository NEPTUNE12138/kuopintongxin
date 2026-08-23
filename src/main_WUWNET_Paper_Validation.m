function [csv_file, run_meta] = main_WUWNET_Paper_Validation(mode, snr_override, mc_override)
% MAIN_WUWNET_PAPER_VALIDATION End-to-end BER Validation over SNR
% Usage: [csv_file, run_meta] = main_WUWNET_Paper_Validation('quick', -16:1:-10, 20)

    if nargin < 1
        mode = 'quick';
    end
    
    cfg = paper2_config(mode);
    
    if nargin >= 2 && ~isempty(snr_override)
        cfg.snr_range = snr_override;
    end
    if nargin >= 3 && ~isempty(mc_override)
        cfg.mc_trials_ber = mc_override;
    end
    
    variants = {'A', 'VB-FQ', 'E-FQ'};
    csv_labels = {'IAE', 'VB-FQ', 'E-FQ'};
    num_variants = length(variants);
    
    num_snr = length(cfg.snr_range);
    num_channels = size(cfg.channels, 1);
    num_mc = cfg.mc_trials_ber;
    
    % Store raw bit errors (NaN for sync failure)
    % Dimensions: [Channel, SNR, Variant, MC]
    raw_errors = NaN(num_channels, num_snr, num_variants, num_mc);
    
    fprintf('\n=== Starting BER Validation (%s) ===\n', upper(mode));
    fprintf('Channels: %d | SNRs: %d | MC Trials: %d\n', num_channels, num_snr, num_mc);
    
    out_dir = fullfile('results', mode);
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end
    
    total_iters = num_channels * num_snr * num_mc;
    iter_count = 0;
    
    for ch_idx = 1:num_channels
        ch_file = cfg.channels{ch_idx, 1};
        [h_cir, ~] = select_bellhop_local_cluster(ch_file, cfg);
        
        fprintf('Processing Channel %d/%d: %s\n', ch_idx, num_channels, cfg.channels{ch_idx, 2});
        
        for snr_idx = 1:num_snr
            snr_db = cfg.snr_range(snr_idx);
            
            for mc = 1:num_mc
                iter_count = iter_count + 1;
                if mod(iter_count, 10) == 0 || total_iters < 100
                    fprintf('  Prog: %d/%d (%.1f%%) [SNR %d dB, MC %d]\n', iter_count, total_iters, 100*iter_count/total_iters, snr_db, mc);
                end
                
                % Deterministic Seed
                rng_seed = cfg.master_seed + mc + snr_idx*10000 + ch_idx*100000;
                rng(rng_seed, 'twister');
                
                % 1. Generate Signal
                [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
                
                % 2. Apply Channel & Noise
                rx_clean = conv(tx_pb, h_cir, 'full');
                
                rx_power = norm(rx_clean)^2 / length(rx_clean);
                noise_power = rx_power / (10^(snr_db / 10));
                noise = sqrt(noise_power/2) * (randn(size(rx_clean)) + 1j * randn(size(rx_clean)));
                
                rx_noisy = rx_clean + noise;
                
                % 3. Common Coarse Sync
                [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_noisy, preamble, cfg);
                sync_meta.peak_idx = peak_idx;
                sync_meta.preamble_start = p_start;
                sync_meta.payload_start = pay_start;
                sync_meta.mf = mf;
                
                % 4. Evaluate Variants (Identical conditions)
                for v = 1:num_variants
                    var_char = variants{v};
                    
                    try
                        [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_noisy, preamble, mseq_os, sync_meta, cfg, var_char);
                        
                        if strcmp(meta.status, 'SYNC_FAIL') || isempty(decoded_bits)
                            raw_errors(ch_idx, snr_idx, v, mc) = NaN; % Sync fail tracked as NaN
                        else
                            errors = sum(decoded_bits ~= data_bits(1:length(decoded_bits)));
                            raw_errors(ch_idx, snr_idx, v, mc) = errors;
                        end
                    catch ME
                        if strcmp(ME.identifier, 'Paper2:SyncFail')
                            raw_errors(ch_idx, snr_idx, v, mc) = NaN;
                        else
                            rethrow(ME); % Unexpected exceptions MUST be rethrown
                        end
                    end
                end
            end
        end
    end
    
    % Metrics computation and CSV export
    fprintf('\n--- BER Validation Summary ---\n');
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    csv_file = fullfile(out_dir, sprintf('paper2_ber_validation_%s.csv', timestamp));
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'Channel,SNR_dB,Variant,Trials_Total,Trials_Valid,SyncFailCount,SyncFailRate,BitErrors_Valid,Bits_Valid,BER_Valid,FrameErrors_Valid,FER_Valid,FrameErrors_Overall,FER_Overall,Wilson_Lower_ValidBER,Wilson_Upper_ValidBER\n');
    
    % Legacy wrapper output
    ber_results = NaN(num_channels, num_snr, num_variants, num_mc);
    
    for ch_idx = 1:num_channels
        fprintf('Channel %d:\n', ch_idx);
        for v = 1:num_variants
            label = csv_labels{v};
            
            total_valid_across_snrs = 0;
            total_trials_across_snrs = num_mc * num_snr;
            
            for snr_idx = 1:num_snr
                snr_db = cfg.snr_range(snr_idx);
                trial_errs = squeeze(raw_errors(ch_idx, snr_idx, v, :))';
                valid_flags = ~isnan(trial_errs);
                
                ber_results(ch_idx, snr_idx, v, :) = trial_errs / cfg.num_data_bits;
                
                stats = compute_paper2_ber_statistics(trial_errs, valid_flags, cfg.num_data_bits);
                
                total_valid_across_snrs = total_valid_across_snrs + stats.Trials_Valid;
                
                fprintf(fid, '%s,%d,%s,%d,%d,%d,%.4f,%d,%d,%.6f,%d,%.4f,%d,%.4f,%.6f,%.6f\n', ...
                    cfg.channels{ch_idx, 2}, snr_db, label, ...
                    stats.Trials_Total, stats.Trials_Valid, stats.SyncFailCount, stats.SyncFailRate, ...
                    stats.BitErrors_Valid, stats.Bits_Valid, stats.BER_Valid, ...
                    stats.FrameErrors_Valid, stats.FER_Valid, stats.FrameErrors_Overall, stats.FER_Overall, ...
                    stats.Wilson_Lower_ValidBER, stats.Wilson_Upper_ValidBER);
            end
            
            sync_fail_rate = 1 - (total_valid_across_snrs / total_trials_across_snrs);
            fprintf('  Variant %s: Valid Trials %d/%d (Fail Rate %.2f%%)\n', ...
                label, total_valid_across_snrs, total_trials_across_snrs, sync_fail_rate * 100);
        end
    end
    fclose(fid);
    
    save_file = fullfile(out_dir, sprintf('paper2_ber_validation_%s.mat', timestamp));
    save(save_file, 'raw_errors', 'ber_results', 'cfg', 'variants', 'csv_labels', 'mode');
    fprintf('Validation results saved to:\n  %s\n  %s\n', save_file, csv_file);
    
    run_meta.variants_internal = variants;
    run_meta.variant_labels = csv_labels;
    run_meta.snr_range = cfg.snr_range;
    run_meta.num_mc = cfg.mc_trials_ber;
    run_meta.frontend_use_trm = cfg.frontend.use_trm;
    run_meta.equalizer_enabled = cfg.equalizer.enabled;
    run_meta.final_tracker_variant = cfg.final_tracker_variant;
    run_meta.c2 = cfg.c2;
    run_meta.Q = cfg.final_Q;
end
