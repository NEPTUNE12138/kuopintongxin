function run_paper2_full_pipeline(mode)
% RUN_PAPER2_FULL_PIPELINE End-to-end execution of the Paper 2 evaluation.
% Usage: run_paper2_full_pipeline('quick') or ('pilot') or ('paper')

    if nargin < 1
        mode = 'quick';
    end
    
    cfg = paper2_config(mode);
    variants = {'A', 'B', 'C', 'D', 'E'};
    num_variants = length(variants);
    
    num_snr = length(cfg.snr_db_range);
    num_channels = size(cfg.channels, 1);
    num_mc = cfg.mc_trials;
    
    ber_results = zeros(num_channels, num_snr, num_variants, num_mc);
    
    fprintf('Starting Pipeline in %s mode\n', upper(mode));
    fprintf('Channels: %d | SNRs: %d | MC Trials: %d\n', num_channels, num_snr, num_mc);
    
    out_dir = 'results';
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
            snr_db = cfg.snr_db_range(snr_idx);
            
            for mc = 1:num_mc
                iter_count = iter_count + 1;
                if mod(iter_count, 10) == 0 || total_iters < 100
                    fprintf('  Prog: %d/%d (%.1f%%) [SNR %d dB, MC %d]\n', iter_count, total_iters, 100*iter_count/total_iters, snr_db, mc);
                end
                
                % 1. Generate Signal
                [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
                
                % 2. Apply Channel
                rx_clean = filter(h_cir, 1, tx_pb);
                
                % 3. Add Noise
                sig_power = norm(tx_pb)^2 / length(tx_pb); % Using TX power as reference or rx_clean power
                % Actually, standard is to use rx_clean power to set precise SNR at receiver
                rx_power = norm(rx_clean)^2 / length(rx_clean);
                noise_power = rx_power / (10^(snr_db / 10));
                
                noise = sqrt(noise_power/2) * (randn(size(rx_clean)) + 1j * randn(size(rx_clean)));
                rx_noisy = rx_clean + noise;
                
                % 4. Coarse Sync (Once per realization to ensure fairness)
                [peak_idx, p_start, pay_start, mf, sync_metric] = coarse_sync_from_preamble(rx_noisy, preamble, cfg);
                sync_meta.peak_idx = peak_idx;
                sync_meta.preamble_start = p_start;
                sync_meta.payload_start = pay_start;
                sync_meta.mf = mf;
                
                % 5. Evaluate Variants
                for v = 1:num_variants
                    var_char = variants{v};
                    
                    try
                        [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_noisy, preamble, mseq_os, sync_meta, cfg, var_char);
                        
                        if strcmp(meta.status, 'SUCCESS') && length(decoded_bits) == cfg.num_data_bits
                            errors = sum(decoded_bits ~= data_bits(1:length(decoded_bits)));
                            ber = errors / cfg.num_data_bits;
                        else
                            ber = 0.5; % Sync fail or tracking loss
                        end
                    catch
                        ber = 0.5;
                    end
                    
                    ber_results(ch_idx, snr_idx, v, mc) = ber;
                end
            end
        end
    end
    
    % Save results
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    save_file = fullfile(out_dir, sprintf('paper2_results_%s_%s.mat', mode, timestamp));
    save(save_file, 'ber_results', 'cfg', 'variants', 'mode');
    
    fprintf('Results saved to: %s\n', save_file);
    
    % Plot
    plot_paper2_ber(save_file);
end
