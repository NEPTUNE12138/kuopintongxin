function decision = diagnose_cfar_detection(mode)
% DIAGNOSE_CFAR_DETECTION Calibrates OS-CFAR parameters for HFM preamble TRM.
% Uses the selected TRUE Bellhop local cluster.

    if nargin < 1, mode = 'quick'; end
    
    config_mode = mode;
    if strcmp(mode, 'freeze')
        config_mode = 'quick';
    end
    
    this_file = mfilename('fullpath');
    src_dir = fileparts(this_file);
    project_root = fileparts(src_dir);
    addpath(fullfile(project_root, 'lib'));
    addpath(fullfile(project_root, 'config'));
    
    cfg = paper2_config(config_mode);
    num_mc = 30; % Enforce 30 MC for falsification
    
    out_dir = fullfile(project_root, 'results', 'diagnostic');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    csv_file = fullfile(out_dir, sprintf('cfar_calibration_%s_%s.csv', mode, datestr(now, 'yyyymmdd_HHMMSS')));
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'Profile,SNR_dB,Pfa,OrderIdx,Recall_Median,FP_Median,Precision_Median,Fallback_Rate\n');
    
    pfa_set = [1e-2, 1e-3, 1e-4];
    order_set = [0.50, 0.75];
    snr_set = [-10, 0];
    profiles = 1:size(cfg.channels, 1);
    
    fprintf('\n=== CFAR Detection Calibration ===\n');
    
    results = struct();
    
    for pi = 1:length(profiles)
        ch_file = cfg.channels{pi, 1};
        [h_cluster, cluster_meta] = select_bellhop_local_cluster(ch_file, cfg);
        
        true_taps = cluster_meta.selected_delays - cluster_meta.selected_delays(1);
        true_tap_samples = round(true_taps * cfg.fs) + 1;
        
        fprintf('Profile %d [%s]:\n', pi, cfg.channels{pi, 2});
        
        for si = 1:length(snr_set)
            snr_db = snr_set(si);
            fprintf('  SNR = %d dB\n', snr_db);
            
            for pf_idx = 1:length(pfa_set)
                for ord_idx = 1:length(order_set)
                    pfa = pfa_set(pf_idx);
                    order = order_set(ord_idx);
                    
                    cfg_test = cfg;
                    cfg_test.os_cfar.pfa = pfa;
                    cfg_test.os_cfar.order_idx = order;
                    cfg_test.kappa_side = 0; % OS-CFAR only for this diagnostic
                    
                    recalls = NaN(1, num_mc);
                    fps = NaN(1, num_mc);
                    precs = NaN(1, num_mc);
                    fallback_count = 0;
                    
                    for mc = 1:num_mc
                        rng_seed = cfg.master_seed + 5000000 + pi*1000 + si*100 + pf_idx*10 + ord_idx*5 + mc;
                        rng(rng_seed, 'twister');
                        
                        preamble = generate_hfm_preamble(cfg_test);
                        rx_clean = conv(preamble, h_cluster, 'full');
                        
                        sig_pwr = norm(rx_clean)^2 / length(rx_clean);
                        noise_pwr = sig_pwr / (10^(snr_db/10));
                        noise = sqrt(noise_pwr/2) * (randn(size(rx_clean)) + 1j*randn(size(rx_clean)));
                        rx_noisy = rx_clean + noise;
                        
                        g_raw = conv(rx_noisy, conj(fliplr(preamble)));
                        
                        [~, peak_idx] = max(abs(g_raw));
                        [g_win, win_start, win_end] = extract_mf_local_window(g_raw, peak_idx, 50, 200);
                        
                        % The true peak of path p occurs at length(preamble) + true_tap_samples(p) - 1
                        % Relative to g_win:
                        expected_peaks = (length(preamble) + true_tap_samples - 1) - win_start + 1;
                        
                        [h_ext, ~, ~, ~, ~, ext_meta] = extract_cir_hybrid(g_win, preamble, cfg_test);
                        
                        if ext_meta.fallback_used
                            fallback_count = fallback_count + 1;
                            recalls(mc) = 0; fps(mc) = 0; precs(mc) = 0;
                            continue;
                        end
                        
                        % Evaluate detection vs true_taps
                        detected_indices = find(ext_meta.raw_os_mask);
                        
                        % Estimate mainlobe width
                        B = cfg_test.preamble_band(2) - cfg_test.preamble_band(1);
                        tol = ceil(cfg_test.fs / B);
                        
                        hits = 0;
                        for p = 1:length(expected_peaks)
                            ep = expected_peaks(p);
                            if any(abs(detected_indices - ep) <= tol)
                                hits = hits + 1;
                            end
                        end
                        
                        recall = hits / length(expected_peaks);
                        fp = length(detected_indices) - hits;
                        if fp < 0, fp = 0; end
                        prec = hits / max(1, length(detected_indices));
                        
                        recalls(mc) = recall;
                        fps(mc) = fp;
                        precs(mc) = prec;
                    end
                    
                    m_recall = median(recalls, 'omitnan');
                    m_fp = median(fps, 'omitnan');
                    m_prec = median(precs, 'omitnan');
                    fb_rate = fallback_count / num_mc;
                    
                    config_name = sprintf('Pfa=%.0e,Ord=%.2f', pfa, order);
                    fprintf('    %s -> Recall: %.3f, FP: %.1f, Prec: %.3f, Fallback: %.1f%%\n', ...
                        config_name, m_recall, m_fp, m_prec, fb_rate*100);
                        
                    fprintf(fid, '%d,%d,%e,%.2f,%.4f,%.4f,%.4f,%.4f\n', ...
                        pi, snr_db, pfa, order, m_recall, m_fp, m_prec, fb_rate);
                        
                    results(pi).snr(si).pfa(pf_idx).order(ord_idx).recall = m_recall;
                    results(pi).snr(si).pfa(pf_idx).order(ord_idx).fp = m_fp;
                    results(pi).snr(si).pfa(pf_idx).order(ord_idx).fb = fb_rate;
                end
            end
        end
    end
    fclose(fid);
    
    % Selection Rule
    % 1. median recall >= 0.90 across ALL profiles at 0 dB;
    % 2. among those, lowest median false detections at 0 dB;
    
    fprintf('\n--- CFAR Selection (0 dB) ---\n');
    best_pfa = NaN; best_order = NaN;
    best_fp = Inf;
    
    for pf_idx = 1:length(pfa_set)
        for ord_idx = 1:length(order_set)
            % Check across all profiles at SNR index 2 (0 dB)
            min_recall_0db = Inf;
            avg_fp_0db = 0;
            for pi = 1:length(profiles)
                r = results(pi).snr(2).pfa(pf_idx).order(ord_idx).recall;
                f = results(pi).snr(2).pfa(pf_idx).order(ord_idx).fp;
                min_recall_0db = min(min_recall_0db, r);
                avg_fp_0db = avg_fp_0db + f;
            end
            avg_fp_0db = avg_fp_0db / length(profiles);
            
            if min_recall_0db >= 0.90
                if avg_fp_0db < best_fp
                    best_fp = avg_fp_0db;
                    best_pfa = pfa_set(pf_idx);
                    best_order = order_set(ord_idx);
                end
            end
        end
    end
    
    decision = struct();
    if isnan(best_pfa)
        fprintf('[!] OS-CFAR unsuitable: No configuration reaches 0.90 recall at 0 dB.\n');
        fprintf('CFAR_EXTRACTION_FAILURE\n');
        fprintf('HYBRID_TRM_NOT_SUPPORTED_AS_PRIMARY_CONTRIBUTION\n');
        decision.passed = false;
    else
        fprintf('[SUCCESS] Best OS-CFAR Config: Pfa = %e, Order = %.2f (Avg FP = %.1f)\n', best_pfa, best_order, best_fp);
        decision.passed = true;
    end
    
    decision.best_pfa = best_pfa;
    decision.best_order = best_order;
    decision.best_fp = best_fp;
    
    % Save decision
    save(fullfile(out_dir, 'cfar_decision.mat'), 'best_pfa', 'best_order', 'best_fp');
end
