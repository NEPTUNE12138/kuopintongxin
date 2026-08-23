function diagnose_trm_contribution(mode)
% DIAGNOSE_TRM_CONTRIBUTION Quantifies OS vs Hybrid TRM extraction vs true local cluster.
    
    if nargin < 1, mode = 'quick'; end
    
    this_file = mfilename('fullpath');
    src_dir = fileparts(this_file);
    project_root = fileparts(src_dir);
    addpath(fullfile(project_root, 'lib'));
    addpath(fullfile(project_root, 'config'));
    
    cfg = paper2_config(mode);
    if strcmp(mode, 'quick')
        num_mc = 5;
    else
        num_mc = 30;
    end
    
    % Try to load frozen CFAR decision
    cfar_decision_file = fullfile(project_root, 'results', 'diagnostic', 'cfar_decision.mat');
    if exist(cfar_decision_file, 'file')
        cfar_dat = load(cfar_decision_file);
        if ~isnan(cfar_dat.best_pfa)
            cfg.os_cfar.pfa = cfar_dat.best_pfa;
            cfg.os_cfar.order_idx = cfar_dat.best_order;
        end
    end
    
    snr_set = [-10, 0];
    profiles = 1:size(cfg.channels, 1);
    
    out_dir = fullfile(project_root, 'results', 'diagnostic');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    csv_file = fullfile(out_dir, sprintf('trm_diagnostic_%s_%s.csv', mode, datestr(now, 'yyyymmdd_HHMMSS')));
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'Profile,SNR_dB,OS_Recall,Hyb_Recall,OS_FP,Hyb_FP,OS_RawCount,Hyb_RawCount,Jaccard,ACF_Floor_Frac,RMS_True,RMS_OS,RMS_Hyb,Peak_True,Peak_OS,Peak_Hyb,PSLR_True,PSLR_OS,PSLR_Hyb\n');
    
    fprintf('\n=== TRM Contribution Diagnostic ===\n');
    
    results = struct();
    all_jaccards = [];
    all_os_recalls = [];
    all_hyb_recalls = [];
    all_os_fps = [];
    all_hyb_fps = [];
    
    for pi = 1:length(profiles)
        ch_file = cfg.channels{pi, 1};
        [h_true, cluster_meta] = select_bellhop_local_cluster(ch_file, cfg);
        
        true_taps = cluster_meta.selected_delays - cluster_meta.selected_delays(1);
        true_tap_samples = round(true_taps * cfg.fs) + 1;
        
        % Pre-compute true metrics
        h_true_norm = h_true / norm(h_true);
        [rms_true, peak_true, pslr_true] = compute_focusing_metrics(h_true_norm, cfg);
        
        fprintf('Profile %d [%s]:\n', pi, cfg.channels{pi, 2});
        
        for si = 1:length(snr_set)
            snr_db = snr_set(si);
            fprintf('  SNR = %d dB ', snr_db);
            
            % Arrays for MC
            os_rec = zeros(1, num_mc);
            hy_rec = zeros(1, num_mc);
            os_fp = zeros(1, num_mc);
            hy_fp = zeros(1, num_mc);
            os_cnt = zeros(1, num_mc);
            hy_cnt = zeros(1, num_mc);
            jaccards = zeros(1, num_mc);
            acf_frac = zeros(1, num_mc);
            rms_os = zeros(1, num_mc);
            rms_hy = zeros(1, num_mc);
            peak_os = zeros(1, num_mc);
            peak_hy = zeros(1, num_mc);
            pslr_os = zeros(1, num_mc);
            pslr_hy = zeros(1, num_mc);
            
            for mc = 1:num_mc
                rng_seed = cfg.master_seed + 3000000 + pi*1000 + si*100 + mc;
                rng(rng_seed, 'twister');
                
                preamble = generate_hfm_preamble(cfg);
                
                rx_clean = conv(preamble, h_true, 'full');
                sig_pwr = norm(rx_clean)^2 / length(rx_clean);
                noise_pwr = sig_pwr / (10^(snr_db/10));
                noise = sqrt(noise_pwr/2) * (randn(size(rx_clean)) + 1j*randn(size(rx_clean)));
                rx_noisy = rx_clean + noise;
                
                g_raw = conv(rx_noisy, conj(fliplr(preamble)));
                
                [~, peak_idx] = max(abs(g_raw));
                win_start = max(1, peak_idx - 50);
                win_end   = min(length(rx_noisy), peak_idx + 200);
                g_win = g_raw(win_start:win_end);
                
                expected_peaks = (length(preamble) + true_tap_samples - 1) - win_start + 1;
                
                B = cfg.preamble_band(2) - cfg.preamble_band(1);
                tol = ceil(cfg.fs / B);
                
                % OS-only extraction
                cfg_os = cfg;
                cfg_os.kappa_side = 0; % Force OS only
                [h_os, ~, ~, ~, ~, meta_os] = extract_cir_hybrid(g_win, preamble, cfg_os);
                
                % Hybrid extraction
                cfg_hyb = cfg; % uses default kappa_side = 1.5
                [h_hyb, ~, ~, ~, ~, meta_hyb] = extract_cir_hybrid(g_win, preamble, cfg_hyb);
                
                os_raw_idx = find(meta_os.raw_os_mask);
                hy_raw_idx = find(meta_hyb.raw_hybrid_mask);
                
                os_cnt(mc) = length(os_raw_idx);
                hy_cnt(mc) = length(hy_raw_idx);
                
                intersection = sum(meta_os.raw_os_mask & meta_hyb.raw_hybrid_mask);
                union_m = sum(meta_os.raw_os_mask | meta_hyb.raw_hybrid_mask);
                jaccards(mc) = intersection / max(1, union_m);
                acf_frac(mc) = meta_hyb.acf_floor_active_fraction;
                
                % Compute recall and FP for OS
                hits_os = 0;
                for p = 1:length(expected_peaks)
                    if any(abs(os_raw_idx - expected_peaks(p)) <= tol), hits_os = hits_os + 1; end
                end
                os_rec(mc) = hits_os / length(expected_peaks);
                os_fp(mc) = max(0, length(os_raw_idx) - hits_os);
                
                % Compute recall and FP for Hybrid
                hits_hy = 0;
                for p = 1:length(expected_peaks)
                    if any(abs(hy_raw_idx - expected_peaks(p)) <= tol), hits_hy = hits_hy + 1; end
                end
                hy_rec(mc) = hits_hy / length(expected_peaks);
                hy_fp(mc) = max(0, length(hy_raw_idx) - hits_hy);
                
                % Metrics using TRUE CIR and detected q
                % Do not use fallback q! Use raw mask q.
                if sum(meta_os.raw_os_mask) == 0
                    rms_os(mc) = NaN; peak_os(mc) = NaN; pslr_os(mc) = NaN;
                else
                    q_os = zeros(size(g_win)); q_os(meta_os.raw_os_mask) = g_win(meta_os.raw_os_mask);
                    q_os = conj(fliplr(q_os));
                    q_os = q_os / norm(q_os);
                    h_eq_os = conv(h_true, q_os);
                    [rms_os(mc), peak_os(mc), pslr_os(mc)] = compute_focusing_metrics(h_eq_os, cfg);
                end
                
                if sum(meta_hyb.raw_hybrid_mask) == 0
                    rms_hy(mc) = NaN; peak_hy(mc) = NaN; pslr_hy(mc) = NaN;
                else
                    q_hy = zeros(size(g_win)); q_hy(meta_hyb.raw_hybrid_mask) = g_win(meta_hyb.raw_hybrid_mask);
                    q_hy = conj(fliplr(q_hy));
                    q_hy = q_hy / norm(q_hy);
                    h_eq_hy = conv(h_true, q_hy);
                    [rms_hy(mc), peak_hy(mc), pslr_hy(mc)] = compute_focusing_metrics(h_eq_hy, cfg);
                end
            end
            
            m_os_rec = median(os_rec); m_hy_rec = median(hy_rec);
            m_os_fp = median(os_fp); m_hy_fp = median(hy_fp);
            m_os_cnt = median(os_cnt); m_hy_cnt = median(hy_cnt);
            m_jac = median(jaccards); m_acf = median(acf_frac);
            
            m_rms_os = median(rms_os); m_rms_hy = median(rms_hy);
            m_peak_os = median(peak_os); m_peak_hy = median(peak_hy);
            m_pslr_os = median(pslr_os); m_pslr_hy = median(pslr_hy);
            
            fprintf('| Rec OS/Hy: %.2f/%.2f | FP OS/Hy: %.1f/%.1f | Jac: %.3f\n', m_os_rec, m_hy_rec, m_os_fp, m_hy_fp, m_jac);
            
            fprintf(fid, '%d,%d,%.4f,%.4f,%.1f,%.1f,%.1f,%.1f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', ...
                pi, snr_db, m_os_rec, m_hy_rec, m_os_fp, m_hy_fp, m_os_cnt, m_hy_cnt, m_jac, m_acf, ...
                rms_true, m_rms_os, m_rms_hy, ...
                peak_true, m_peak_os, m_peak_hy, ...
                pslr_true, m_pslr_os, m_pslr_hy);
                
            all_jaccards = [all_jaccards, m_jac];
            all_os_recalls = [all_os_recalls, m_os_rec];
            all_hyb_recalls = [all_hyb_recalls, m_hy_rec];
            all_os_fps = [all_os_fps, m_os_fp];
            all_hyb_fps = [all_hyb_fps, m_hy_fp];
        end
    end
    fclose(fid);
    
    fprintf('\n--- Diagnostic Classification ---\n');
    med_jac = median(all_jaccards);
    fprintf('Median Jaccard across all conditions: %.4f\n', med_jac);
    
    % Evaluation of Hybrid
    % "preserves true-path recall within 5% of OS"
    % "reduces false detections or improves focusing in a consistent predefined set of conditions"
    
    recall_preserved = all((all_hyb_recalls + 0.05) >= all_os_recalls);
    fp_reduced = median(all_hyb_fps) < median(all_os_fps);
    % Let's keep it simple: if Jaccard is 1, they are identical, so it doesn't reduce FP or change anything.
    if med_jac == 1
        fp_reduced = false;
    end
    
    if recall_preserved && fp_reduced
        fprintf('[SUCCESS] HYBRID_TRM_SUPPORTED\n');
    else
        fprintf('[!] HYBRID_TRM_NOT_SUPPORTED_AS_PRIMARY_CONTRIBUTION\n');
    end
    
    fprintf('\nTRM Diagnostic saved to CSV.\n');
end

function [rms_ds, peak_ratio, pslr] = compute_focusing_metrics(h_eq, cfg)
    p_eq = abs(h_eq).^2;
    total_energy = sum(p_eq) + eps;
    
    % RMS Delay Spread
    t_idx = (1:length(p_eq)) - 1;
    mean_delay = sum(t_idx .* p_eq) / total_energy;
    mean_sq_delay = sum((t_idx.^2) .* p_eq) / total_energy;
    rms_ds = sqrt(max(0, mean_sq_delay - mean_delay^2));
    
    % Peak concentration (±1 chip)
    [~, max_idx] = max(p_eq);
    window = cfg.samples_per_chip;
    idx_start = max(1, max_idx - window);
    idx_end = min(length(p_eq), max_idx + window);
    
    peak_energy = sum(p_eq(idx_start:idx_end));
    peak_ratio = peak_energy / total_energy;
    
    % PSLR
    sidelobe_region = true(size(p_eq));
    sidelobe_region(idx_start:idx_end) = false;
    max_sl = max(p_eq(sidelobe_region));
    if max_sl > 0
        pslr = 10 * log10(p_eq(max_idx) / max_sl);
    else
        pslr = 100; % arbitrary high
    end
end
