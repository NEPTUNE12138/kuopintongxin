function quick_snr_boundary_scan(mode)
% QUICK_SNR_BOUNDARY_SCAN Scans low SNR to find BER waterfall crossing.

    if nargin < 1, mode = 'quick'; end
    
    this_file = mfilename('fullpath');
    src_dir = fileparts(this_file);
    project_root = fileparts(src_dir);
    addpath(fullfile(project_root, 'lib'));
    addpath(fullfile(project_root, 'config'));
    
    cfg = paper2_config(mode);
    num_mc = 20; % strictly 20 MC
    
    snr_set = -22:1:-8;
    profiles = 1:size(cfg.channels, 1);
    
    % Only test C and E (or E-CAL if it exists, let's just do C and E for now, we will add E-CAL if needed)
    variants = {'C', 'E'};
    
    out_dir = fullfile(project_root, 'results', 'diagnostic');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    csv_file = fullfile(out_dir, sprintf('snr_boundary_scan_%s_%s.csv', mode, datestr(now, 'yyyymmdd_HHMMSS')));
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'Profile,SNR_dB,Variant,ValidTrials,MeanBER\n');
    
    fprintf('\n=== Quick SNR Boundary Scan ===\n');
    
    res = struct();
    for pi = 1:length(profiles)
        ch_file = cfg.channels{pi, 1};
        [h_chan, ~] = load_bellhop_cir(ch_file, cfg.fs);
        
        fprintf('Profile %d [%s]:\n', pi, cfg.channels{pi, 2});
        
        for vi = 1:length(variants)
            vn = variants{vi};
            res(pi).(vn).ber = NaN(1, length(snr_set));
            
            for si = 1:length(snr_set)
                snr_db = snr_set(si);
                
                trial_errs = 0;
                trial_bits = 0;
                valid_trials = 0;
                
                for mc = 1:num_mc
                    rng_seed = cfg.master_seed + 4000000 + pi*1000 + si*100 + mc;
                    rng(rng_seed, 'twister');
                    
                    [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
                    rx_clean = filter(h_chan, 1, tx_pb);
                    
                    sig_pwr = norm(rx_clean)^2 / length(rx_clean);
                    noise_pwr = sig_pwr / (10^(snr_db/10));
                    noise = sqrt(noise_pwr/2) * (randn(size(rx_clean)) + 1j*randn(size(rx_clean)));
                    rx_noisy = rx_clean + noise;
                    
                    try
                        [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_noisy, preamble, cfg);
                        sync_meta.peak_idx = peak_idx;
                        sync_meta.preamble_start = p_start;
                        sync_meta.payload_start = pay_start;
                        sync_meta.mf = mf;
                        
                        [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_noisy, preamble, mseq_os, sync_meta, cfg, vn);
                        
                        if strcmp(meta.status, 'SUCCESS')
                            errs = sum(decoded_bits ~= data_bits);
                            trial_errs = trial_errs + errs;
                            trial_bits = trial_bits + cfg.num_data_bits;
                            valid_trials = valid_trials + 1;
                        end
                    catch ME
                        if ~strcmp(ME.identifier, 'Paper2:SyncFail')
                            rethrow(ME);
                        end
                    end
                end
                
                if valid_trials > 0
                    m_ber = trial_errs / trial_bits;
                else
                    m_ber = NaN;
                end
                res(pi).(vn).ber(si) = m_ber;
                
                fprintf(fid, '%d,%d,%s,%d,%.6f\n', pi, snr_db, vn, valid_trials, m_ber);
            end
            
            % Find bracket for 1e-3
            bers = res(pi).(vn).ber;
            target = 1e-3;
            
            % If NaN, it means 100% fail -> high BER effectively.
            % Just consider valid points
            valid_idx = find(~isnan(bers));
            if isempty(valid_idx)
                fprintf('  %s: All Sync Fails\n', vn);
            elseif bers(valid_idx(1)) <= target
                fprintf('  %s: crossing < %d dB\n', vn, snr_set(valid_idx(1)));
            elseif bers(valid_idx(end)) > target
                fprintf('  %s: crossing > %d dB\n', vn, snr_set(valid_idx(end)));
            else
                for i = 1:length(valid_idx)-1
                    idx1 = valid_idx(i);
                    idx2 = valid_idx(i+1);
                    if bers(idx1) > target && bers(idx2) <= target
                        fprintf('  %s: crossing bracket [%d, %d] dB\n', vn, snr_set(idx1), snr_set(idx2));
                        break;
                    end
                end
            end
        end
    end
    fclose(fid);
end
