function main_WUWNET_Paper_Validation(mode)
% MAIN_WUWNET_PAPER_VALIDATION End-to-end BER Validation over SNR
% Usage: main_WUWNET_Paper_Validation('quick')

    if nargin < 1
        mode = 'quick';
    end
    
    cfg = paper2_config(mode);
    variants = {'A', 'B', 'C', 'D', 'E'};
    num_variants = length(variants);
    
    num_snr = length(cfg.snr_range);
    num_channels = size(cfg.channels, 1);
    num_mc = cfg.mc_trials_ber;
    
    % Dimensions: [Channel, SNR, Variant, MC]
    ber_results = NaN(num_channels, num_snr, num_variants, num_mc);
    
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
        [h_cir, ~] = load_bellhop_cir(ch_file, cfg.fs);
        
        fprintf('Processing Channel %d/%d: %s\n', ch_idx, num_channels, cfg.channels{ch_idx, 2});
        
        for snr_idx = 1:num_snr
            snr_db = cfg.snr_range(snr_idx);
            
            for mc = 1:num_mc
                iter_count = iter_count + 1;
                if mod(iter_count, 10) == 0 || total_iters < 100
                    fprintf('  Prog: %d/%d (%.1f%%) [SNR %d dB, MC %d]\n', iter_count, total_iters, 100*iter_count/total_iters, snr_db, mc);
                end
                
                % 1. Generate Signal
                [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
                
                % 2. Apply Channel & Noise
                rx_clean = filter(h_cir, 1, tx_pb);
                
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
                        
                        if strcmp(meta.status, 'SYNC_FAIL')
                            ber_results(ch_idx, snr_idx, v, mc) = NaN; % Sync fail tracked as NaN
                        elseif isempty(decoded_bits)
                            ber_results(ch_idx, snr_idx, v, mc) = NaN;
                        else
                            errors = sum(decoded_bits ~= data_bits(1:length(decoded_bits)));
                            ber = errors / max(1, length(decoded_bits));
                            ber_results(ch_idx, snr_idx, v, mc) = ber;
                        end
                    catch ME
                        if strcmp(ME.identifier, 'Paper2:SyncFail')
                            ber_results(ch_idx, snr_idx, v, mc) = NaN;
                        else
                            rethrow(ME); % Unexpected exceptions MUST be rethrown
                        end
                    end
                end
            end
        end
    end
    
    % Metrics computation
    % For each variant, channel, SNR: calculate mean BER, FER, valid trials
    fprintf('\n--- BER Validation Summary ---\n');
    for ch_idx = 1:num_channels
        fprintf('Channel %d:\n', ch_idx);
        for v = 1:num_variants
            total_trials = num_mc * num_snr;
            all_bers = squeeze(ber_results(ch_idx, :, v, :));
            valid_mask = ~isnan(all_bers);
            num_valid = sum(valid_mask(:));
            sync_fail_rate = 1 - (num_valid / total_trials);
            
            % Compute aggregate BER over all SNRs just for console print
            % Actually, it's better to print per SNR, but for brevity we print sync fail.
            fprintf('  Variant %s: Valid Trials %d/%d (Fail Rate %.2f%%)\n', ...
                variants{v}, num_valid, total_trials, sync_fail_rate * 100);
        end
    end
    
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    save_file = fullfile(out_dir, sprintf('paper2_ber_validation_%s.mat', timestamp));
    save(save_file, 'ber_results', 'cfg', 'variants', 'mode');
    fprintf('Validation results saved to: %s\n', save_file);
end
