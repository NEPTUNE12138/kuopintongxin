function diagnose_trm_contribution(mode)
% DIAGNOSE_TRM_CONTRIBUTION Quantifies OS vs Hybrid TRM extraction vs h_true.
    
    if nargin < 1, mode = 'quick'; end
    
    this_file = mfilename('fullpath');
    src_dir = fileparts(this_file);
    project_root = fileparts(src_dir);
    addpath(fullfile(project_root, 'lib'));
    addpath(fullfile(project_root, 'config'));
    
    cfg = paper2_config(mode);
    if strcmp(mode, 'quick')
        num_mc = 5; % Keep it fast for quick mode
    else
        num_mc = 30;
    end
    
    snr_set = [-10, 0];
    profiles = 1:size(cfg.channels, 1);
    
    out_dir = fullfile(project_root, 'results', 'diagnostic');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    csv_file = fullfile(out_dir, sprintf('trm_diagnostic_%s_%s.csv', mode, datestr(now, 'yyyymmdd_HHMMSS')));
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'Profile,SNR_dB,OS_PathCount,Hyb_PathCount,Jaccard,ACF_Floor_Frac,RMS_True,RMS_OS,RMS_Hyb,Peak_True,Peak_OS,Peak_Hyb,PSLR_True,PSLR_OS,PSLR_Hyb\n');
    
    fprintf('\n=== TRM Contribution Diagnostic ===\n');
    
    results = struct();
    all_jaccards = [];
    all_rmses = []; % OS vs Hyb
    
    for pi = 1:length(profiles)
        ch_file = cfg.channels{pi, 1};
        [h_true, ~] = load_bellhop_cir(ch_file, cfg.fs);
        
        % Pre-compute true metrics
        h_true_norm = h_true / norm(h_true);
        [rms_true, peak_true, pslr_true] = compute_focusing_metrics(h_true_norm, cfg);
        
        fprintf('Profile %d [%s]:\n', pi, cfg.channels{pi, 2});
        
        for si = 1:length(snr_set)
            snr_db = snr_set(si);
            fprintf('  SNR = %d dB ', snr_db);
            
            % Arrays for 30 MC
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
                
                [~, ~, preamble, ~, ~, ~] = generate_paper2_tx_signal(cfg);
                
                rx_clean = filter(h_true, 1, preamble);
                sig_pwr = norm(rx_clean)^2 / length(rx_clean);
                noise_pwr = sig_pwr / (10^(snr_db/10));
                noise = sqrt(noise_pwr/2) * (randn(size(rx_clean)) + 1j*randn(size(rx_clean)));
                rx_noisy = rx_clean + noise;
                
                g_raw = conv(rx_noisy, conj(fliplr(preamble)));
                
                % OS-only extraction
                cfg_os = cfg;
                cfg_os.kappa_side = 0; % Force OS only
                [h_os, ~, ~, ~, mask_os, meta_os] = extract_cir_hybrid(g_raw, preamble, cfg_os);
                
                % Hybrid extraction
                cfg_hyb = cfg; % uses default kappa_side = 1.5
                [h_hyb, ~, ~, ~, mask_hyb, meta_hyb] = extract_cir_hybrid(g_raw, preamble, cfg_hyb);
                
                os_cnt(mc) = meta_hyb.os_path_count;
                hy_cnt(mc) = meta_hyb.hybrid_path_count;
                
                intersection = sum(mask_os & mask_hyb);
                union_m = sum(mask_os | mask_hyb);
                jaccards(mc) = intersection / max(1, union_m);
                acf_frac(mc) = meta_hyb.acf_floor_active_fraction;
                
                % Metrics using TRUE CIR
                q_os = conj(fliplr(h_os));
                if norm(q_os) > 0, q_os = q_os / norm(q_os); end
                h_eq_os = conv(h_true, q_os);
                
                q_hy = conj(fliplr(h_hyb));
                if norm(q_hy) > 0, q_hy = q_hy / norm(q_hy); end
                h_eq_hy = conv(h_true, q_hy);
                
                [rms_os(mc), peak_os(mc), pslr_os(mc)] = compute_focusing_metrics(h_eq_os, cfg);
                [rms_hy(mc), peak_hy(mc), pslr_hy(mc)] = compute_focusing_metrics(h_eq_hy, cfg);
            end
            
            m_os_cnt = mean(os_cnt);
            m_hy_cnt = mean(hy_cnt);
            m_jac = mean(jaccards);
            m_acf = mean(acf_frac);
            
            m_rms_os = mean(rms_os); m_rms_hy = mean(rms_hy);
            m_peak_os = mean(peak_os); m_peak_hy = mean(peak_hy);
            m_pslr_os = mean(pslr_os); m_pslr_hy = mean(pslr_hy);
            
            fprintf('| Jac: %.3f | Act: %.3f | RMS OS/Hy: %.1f/%.1f\n', m_jac, m_acf, m_rms_os, m_rms_hy);
            
            fprintf(fid, '%d,%d,%.1f,%.1f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f\n', ...
                pi, snr_db, m_os_cnt, m_hy_cnt, m_jac, m_acf, ...
                rms_true, m_rms_os, m_rms_hy, ...
                peak_true, m_peak_os, m_peak_hy, ...
                pslr_true, m_pslr_os, m_pslr_hy);
                
            all_jaccards = [all_jaccards, m_jac];
        end
    end
    fclose(fid);
    
    fprintf('\n--- Diagnostic Classification ---\n');
    med_jac = median(all_jaccards);
    fprintf('Median Jaccard across all conditions: %.4f\n', med_jac);
    if med_jac > 0.95
        fprintf('[!] HYBRID_ACF_CONSTRAINT_MOSTLY_INACTIVE\n');
    else
        fprintf('[ ] Hybrid threshold actively constrains OS-CFAR.\n');
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
