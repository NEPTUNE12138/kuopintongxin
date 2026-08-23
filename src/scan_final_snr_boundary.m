function scan_final_snr_boundary()
% SCAN_FINAL_SNR_BOUNDARY Execute the final pilot admission SNR boundary scan.
    
    cfg = paper2_config('quick');
    variants = {'A', 'VB-FQ', 'E-FQ'};
    csv_labels = {'IAE', 'VB-FQ', 'E-FQ'};
    num_variants = length(variants);
    
    num_mc = 30;
    snr_grid = -20:1:2;
    num_channels = size(cfg.channels, 1);
    
    fprintf('\n=== Final SNR Boundary Scan ===\n');
    fprintf('Initial Grid: %d to %d dB, %d MC/point\n', min(snr_grid), max(snr_grid), num_mc);
    
    out_dir = fullfile('results', 'final_freeze');
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end
    
    function stats = eval_snr(ch_idx, snr_db, v_idx)
        ch_file = cfg.channels{ch_idx, 1};
        [h_cir, ~] = select_bellhop_local_cluster(ch_file, cfg);
        
        raw_errors = NaN(1, num_mc);
        valid_flags = false(1, num_mc);
        
        for mc = 1:num_mc
            rng_seed = cfg.master_seed + mc + 888000 + snr_db*1000 + ch_idx*100000;
            rng(rng_seed, 'twister');
            
            [tx_pb, data_bits, preamble, mseq, mseq_os, ~] = generate_paper2_tx_signal(cfg);
            rx_clean = conv(tx_pb, h_cir, 'full');
            
            rx_power = norm(rx_clean)^2 / length(rx_clean);
            noise_power = rx_power / (10^(snr_db / 10));
            noise = sqrt(noise_power/2) * (randn(size(rx_clean)) + 1j * randn(size(rx_clean)));
            rx_noisy = rx_clean + noise;
            
            [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_noisy, preamble, cfg);
            sync_meta.peak_idx = peak_idx;
            sync_meta.preamble_start = p_start;
            sync_meta.payload_start = pay_start;
            sync_meta.mf = mf;
            
            try
                [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_noisy, preamble, mseq_os, sync_meta, cfg, variants{v_idx});
                if strcmp(meta.status, 'SUCCESS') && length(decoded_bits) == cfg.num_data_bits
                    raw_errors(mc) = sum(decoded_bits ~= data_bits(1:length(decoded_bits)));
                    valid_flags(mc) = true;
                end
            catch
                % Sync fail
            end
        end
        stats = compute_paper2_ber_statistics(raw_errors, valid_flags, cfg.num_data_bits);
    end

    all_stats = struct();
    
    % Initial pass
    for snr_idx = 1:length(snr_grid)
        snr_db = snr_grid(snr_idx);
        fprintf('Scanning SNR = %d dB...\n', snr_db);
        for ch_idx = 1:num_channels
            for v = 1:num_variants
                s = eval_snr(ch_idx, snr_db, v);
                ck = sprintf('CH%d_SNR%d', ch_idx, snr_db);
                ck = strrep(ck, '-', 'minus');
                safe_label = strrep(csv_labels{v}, '-', '_');
                all_stats.(ck).(safe_label) = s;
                all_stats.(ck).snr = snr_db;
                all_stats.(ck).ch = ch_idx;
            end
        end
    end
    
    % Find boundaries using E-FQ
    lower_pts = NaN(1, num_channels);
    upper_pts = NaN(1, num_channels);
    
    for ch_idx = 1:num_channels
        found_lower = false;
        curr_snr = max(snr_grid);
        while curr_snr >= -26
            ck = sprintf('CH%d_SNR%d', ch_idx, curr_snr);
            ck = strrep(ck, '-', 'minus');
            if ~isfield(all_stats, ck)
                fprintf('  Expanding scan down to %d dB for P%d (lower)\n', curr_snr, ch_idx);
                for v = 1:num_variants
                    s = eval_snr(ch_idx, curr_snr, v);
                    safe_label = strrep(csv_labels{v}, '-', '_');
                    all_stats.(ck).(safe_label) = s;
                    all_stats.(ck).snr = curr_snr;
                    all_stats.(ck).ch = ch_idx;
                end
            end
            if all_stats.(ck).E_FQ.FER_Overall >= 0.50
                lower_pts(ch_idx) = curr_snr;
                found_lower = true;
                break;
            end
            curr_snr = curr_snr - 1;
        end
        
        found_upper = false;
        curr_snr = min(snr_grid);
        while curr_snr <= 6
            ck = sprintf('CH%d_SNR%d', ch_idx, curr_snr);
            ck = strrep(ck, '-', 'minus');
            if ~isfield(all_stats, ck)
                fprintf('  Expanding scan up to %d dB for P%d (upper)\n', curr_snr, ch_idx);
                for v = 1:num_variants
                    s = eval_snr(ch_idx, curr_snr, v);
                    safe_label = strrep(csv_labels{v}, '-', '_');
                    all_stats.(ck).(safe_label) = s;
                    all_stats.(ck).snr = curr_snr;
                    all_stats.(ck).ch = ch_idx;
                end
            end
            if all_stats.(ck).E_FQ.FER_Overall <= 0.05 && all_stats.(ck).E_FQ.SyncFailRate <= 0.05
                upper_pts(ch_idx) = curr_snr;
                found_upper = true;
                break;
            end
            curr_snr = curr_snr + 1;
        end
    end
    
    fprintf('\nBoundary Results:\n');
    for ch_idx = 1:num_channels
        fprintf('  Profile %d: Lower >= 0.50 at %d dB | Upper <= 0.05 at %d dB\n', ...
            ch_idx, lower_pts(ch_idx), upper_pts(ch_idx));
    end
    
    pilot_snr_min = min(lower_pts);
    pilot_snr_max = max(upper_pts);
    
    fprintf('\nCommon Pilot SNR Range: [%d, %d] dB\n', pilot_snr_min, pilot_snr_max);
    
    % Save outputs
    csv_file = fullfile(out_dir, 'final_snr_boundary.csv');
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'Channel,SNR_dB,Variant,Trials_Valid,SyncFailRate,FER_Overall,FER_Valid,BER_Valid\n');
    
    fields = fieldnames(all_stats);
    for i = 1:length(fields)
        k = fields{i};
        for v = 1:num_variants
            label = csv_labels{v};
            safe_label = strrep(label, '-', '_');
            s = all_stats.(k).(safe_label);
            fprintf(fid, '%d,%d,%s,%d,%.4f,%.4f,%.4f,%.6f\n', ...
                all_stats.(k).ch, all_stats.(k).snr, label, ...
                s.Trials_Valid, s.SyncFailRate, s.FER_Overall, s.FER_Valid, s.BER_Valid);
        end
    end
    fclose(fid);
    
    range_file = fullfile(out_dir, 'final_snr_range.txt');
    fid_r = fopen(range_file, 'w');
    fprintf(fid_r, '%d:%d\n', pilot_snr_min, pilot_snr_max);
    fclose(fid_r);
end
