function quick_snr_boundary_scan(mode)
% QUICK_SNR_BOUNDARY_SCAN Scans low SNR to find BER waterfall crossing.
% Uses frozen candidates.

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
    
    out_dir = fullfile(project_root, 'results', 'diagnostic');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    % Load frozen decisions if they exist
    cfar_file = fullfile(out_dir, 'cfar_decision.mat');
    if exist(cfar_file, 'file')
        cfar_dat = load(cfar_file);
        if ~isnan(cfar_dat.best_pfa)
            cfg.os_cfar.pfa = cfar_dat.best_pfa;
            cfg.os_cfar.order_idx = cfar_dat.best_order;
        end
    end
    
    c2_file = fullfile(out_dir, 'c2_minimax_decision.mat');
    if exist(c2_file, 'file')
        c2_dat = load(c2_file);
        cfg.c2 = c2_dat.final_c2;
    end
    
    % We expect E-CAL to be the promoted variant. Just evaluate C and E-CAL.
    variants = {'C', 'E-CAL'};
    
    csv_file = fullfile(out_dir, sprintf('snr_boundary_scan_%s_%s.csv', mode, datestr(now, 'yyyymmdd_HHMMSS')));
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'Profile,SNR_dB,Variant,ValidTrials,MeanBER,SyncFailRate\n');
    
    fprintf('\n=== Final SNR Boundary Scan ===\n');
    
    res = struct();
    for pi = 1:length(profiles)
        ch_file = cfg.channels{pi, 1};
        [h_chan, ~] = select_bellhop_local_cluster(ch_file, cfg);
        
        fprintf('Profile %d [%s]:\n', pi, cfg.channels{pi, 2});
        
        for vi = 1:length(variants)
            vn = variants{vi};
            vn_safe = strrep(vn, '-', '_');
            res(pi).(vn_safe).ber = NaN(1, length(snr_set));
            
            for si = 1:length(snr_set)
                snr_db = snr_set(si);
                
                trial_errs = 0;
                trial_bits = 0;
                valid_trials = 0;
                sync_fails = 0;
                
                for mc = 1:num_mc
                    rng_seed = cfg.master_seed + 4000000 + pi*1000 + si*100 + mc;
                    rng(rng_seed, 'twister');
                    
                    [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
                    rx_clean = conv(tx_pb, h_chan, 'full');
                    
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
                        else
                            sync_fails = sync_fails + 1;
                        end
                    catch ME
                        if strcmp(ME.identifier, 'Paper2:SyncFail')
                            sync_fails = sync_fails + 1;
                        else
                            rethrow(ME);
                        end
                    end
                end
                
                if valid_trials > 0
                    m_ber = trial_errs / trial_bits;
                else
                    m_ber = NaN;
                end
                
                sync_fail_rate = sync_fails / num_mc;
                res(pi).(vn_safe).ber(si) = m_ber;
                
                fprintf(fid, '%d,%d,%s,%d,%.6f,%.6f\n', pi, snr_db, vn, valid_trials, m_ber, sync_fail_rate);
            end
            
            % Find bracket for 1e-3
            bers = res(pi).(vn_safe).ber;
            target = 1e-3;
            
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
