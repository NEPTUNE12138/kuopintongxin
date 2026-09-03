function main_WUWNET_Paper_Strengthening_Stage1_v2(mc_override)
% MAIN_WUWNET_PAPER_STRENGTHENING_STAGE1_V2 Extract measurement telemetry
% Extracts z_k, m_k, epsilon_true,k, and e_meas,k for E-FQ variant.
% Modified to output to paper_strengthening_v2 and perform robust
% per-profile and per-trial statistics as requested by Codex.

    mode = 'paper';
    cfg = paper2_config(mode);
    snr_db = cfg.stress_snr_db; % 15 dB default
    
    if nargin >= 1 && ~isempty(mc_override)
        num_mc = mc_override;
    else
        num_mc = 200; % Start with 200 trials for pilot/validation
    end
    
    variant = 'E-FQ';
    num_channels = size(cfg.channels, 1);
    num_syms = cfg.num_diff_symbols;
    
    fprintf('\n=== Starting STAGE 1 V2: Reliability Validity ===\n');
    fprintf('MC Trials: %d | Channels: %d | SNR: %d dB | Variant: %s\n', num_mc, num_channels, snr_db, variant);
    
    out_dir = fullfile('results', 'paper_strengthening_v2');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    total_samples = num_channels * num_mc * num_syms;
    
    % Preallocate data arrays for table
    out_ProfileID = cell(total_samples, 1);
    out_Trial = zeros(total_samples, 1);
    out_SymbolIdx = zeros(total_samples, 1);
    out_Phase = cell(total_samples, 1);
    out_m_k = zeros(total_samples, 1);
    out_z_k = zeros(total_samples, 1);
    out_eps_true = zeros(total_samples, 1);
    out_e_meas = zeros(total_samples, 1);
    
    row_idx = 0;
    
    for ch_idx = 1:num_channels
        ch_file = cfg.channels{ch_idx, 1};
        profile_id = sprintf('P%d', ch_idx);
        [h_cir, ~] = select_bellhop_local_cluster(ch_file, cfg);
        
        fprintf('Processing %s at %d dB...\n', cfg.channels{ch_idx, 2}, snr_db);
        
        for mc = 1:num_mc
            if mod(mc, 10) == 0, fprintf('  Prog: %d/%d (%.1f%%)\n', mc, num_mc, 100*mc/num_mc); end
            
            % Deterministic Seed
            rng_seed = cfg.master_seed + mc + 999000 + ch_idx*10000;
            rng(rng_seed, 'twister');
            
            % 1. Generate Signal
            [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
            
            % 2. Apply Channel
            rx_multi = conv(tx_pb, h_cir, 'full');
            
            % 3. Apply Continuous Time-Warping
            t = (0:length(rx_multi)-1) / cfg.fs;
            warp_cfg.v0_mps = 0.5;
            warp_cfg.velocity_amp_mps = 1.5;
            warp_cfg.velocity_freq_hz = 0.2;
            warp_cfg.phase_rad = 0;
            [rx_warp, warp_meta] = apply_paper2_time_warp(rx_multi, cfg, warp_cfg);
            epsilon_true_samples = warp_meta.epsilon_true_samples;
            
            % 4. Add Deep Fades (Amplitude Modulation)
            packet_duration = length(rx_warp) / cfg.fs;
            fade_center = packet_duration / 2;
            fade_width = 0.1; % 100ms fade
            fade_env = 1 - 0.9 * exp(-0.5 * ((t - fade_center) / (fade_width / 3)).^2);
            rx_fade = rx_warp .* fade_env;
            
            % 5. Add Noise
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
            
            fade_env_at_centers = fade_env(sym_centers);
            fmask = fade_env_at_centers < 0.5;
            first_fade = find(fmask, 1, 'first');
            last_fade = find(fmask, 1, 'last');
            
            pre_idx = 1:(first_fade-1);
            fade_idx = first_fade:last_fade;
            post_idx = (last_fade+1):cfg.num_diff_symbols;
            
            % 7. Run Tracker
            try
                [~, ~, meta] = run_paper2_receiver_variant(rx_final, preamble, mseq_os, sync_meta, cfg, variant);
                
                if strcmp(meta.status, 'SUCCESS')
                    z_k = meta.delay_measurement_z;
                    z_k_rel = z_k - z_k(1);
                    e_meas = z_k_rel - eps_true_rel;
                    m_k = meta.m_reliability;
                    
                    for k = 1:num_syms
                        row_idx = row_idx + 1;
                        out_ProfileID{row_idx} = profile_id;
                        out_Trial(row_idx) = mc;
                        out_SymbolIdx(row_idx) = k;
                        if k < first_fade
                            out_Phase{row_idx} = 'PRE';
                        elseif k > last_fade
                            out_Phase{row_idx} = 'POST';
                        else
                            out_Phase{row_idx} = 'FADE';
                        end
                        out_m_k(row_idx) = m_k(k);
                        out_z_k(row_idx) = z_k(k);
                        out_eps_true(row_idx) = eps_true_per_symbol(k);
                        out_e_meas(row_idx) = e_meas(k);
                    end
                end
            catch ME
                if ~strcmp(ME.identifier, 'Paper2:SyncFail')
                    rethrow(ME);
                end
            end
        end
    end
    
    % Trim arrays
    out_ProfileID = out_ProfileID(1:row_idx);
    out_Trial = out_Trial(1:row_idx);
    out_SymbolIdx = out_SymbolIdx(1:row_idx);
    out_Phase = out_Phase(1:row_idx);
    out_m_k = out_m_k(1:row_idx);
    out_z_k = out_z_k(1:row_idx);
    out_eps_true = out_eps_true(1:row_idx);
    out_e_meas = out_e_meas(1:row_idx);
    
    % Save to CSV
    T = table(out_ProfileID, out_Trial, out_SymbolIdx, out_Phase, out_m_k, out_z_k, out_eps_true, out_e_meas, ...
        'VariableNames', {'ProfileID', 'Trial', 'SymbolIdx', 'Phase', 'm_k', 'z_k', 'epsilon_true_k', 'e_meas_k'});
    
    csv_file = fullfile(out_dir, 'reliability_measurement_samples_v2.csv');
    writetable(T, csv_file);
    fprintf('Saved %d samples to %s\n', row_idx, csv_file);
    
    % Run analysis
    analyze_reliability_validity_v2(T, out_dir);
end

function analyze_reliability_validity_v2(T, out_dir)
    fprintf('\n--- Analyzing Reliability Validity (V2) ---\n');
    
    abs_e = abs(T.e_meas_k);
    
    %% 1. Tie-aware fixed bins
    num_bins = 4;
    bin_labels = {'< 0.95', '[0.95, 0.98)', '[0.98, 1.00)', '= 1.00'}';
    
    bin_counts = zeros(num_bins, 1);
    bin_median = zeros(num_bins, 1);
    bin_var = zeros(num_bins, 1);
    bin_ci_low = zeros(num_bins, 1);
    bin_ci_high = zeros(num_bins, 1);
    
    for i = 1:num_bins
        if i == 1
            idx = T.m_k < 0.95;
        elseif i == 2
            idx = T.m_k >= 0.95 & T.m_k < 0.98;
        elseif i == 3
            idx = T.m_k >= 0.98 & T.m_k < 1.00;
        elseif i == 4
            idx = T.m_k == 1.00;
        end
        
        bin_counts(i) = sum(idx);
        
        if bin_counts(i) > 0
            err_vals = abs_e(idx);
            bin_median(i) = median(err_vals);
            bin_var(i) = var(T.e_meas_k(idx));
            
            if bin_counts(i) > 20
                boot_med = bootstrp(500, @median, err_vals);
                ci = prctile(boot_med, [2.5, 97.5]);
                bin_ci_low(i) = ci(1);
                bin_ci_high(i) = ci(2);
            else
                bin_ci_low(i) = bin_median(i);
                bin_ci_high(i) = bin_median(i);
            end
        end
    end
    
    % Print bin statistics
    fprintf('\n[Quantile Bins of Reliability]\n');
    bin_summary_table = table(bin_labels, bin_counts, bin_median, bin_var, bin_ci_low, bin_ci_high, ...
        'VariableNames', {'ReliabilityBin', 'Count', 'MedianAbsError', 'EmpiricalVariance', 'CI95_Lower', 'CI95_Upper'});
    disp(bin_summary_table);
    writetable(bin_summary_table, fullfile(out_dir, 'reliability_measurement_bin_summary_v2.csv'));
    
    %% 2. Per-profile Spearman correlation
    profiles = unique(T.ProfileID);
    prof_corr = struct();
    
    fprintf('\n[Per-Profile Spearman Correlation]\n');
    for p = 1:length(profiles)
        pid = profiles{p};
        idx = strcmp(T.ProfileID, pid);
        m_k_sub = T.m_k(idx);
        abs_e_sub = abs_e(idx);
        e_sq_sub = T.e_meas_k(idx).^2;
        
        rho_abs = corr(m_k_sub, abs_e_sub, 'type', 'Spearman');
        rho_sq = corr(m_k_sub, e_sq_sub, 'type', 'Spearman');
        
        fprintf('  %s: m_k vs |e_meas| = %.4f | m_k vs e_meas^2 = %.4f\n', pid, rho_abs, rho_sq);
        
        prof_corr(p).Profile = pid;
        prof_corr(p).Rho_abs = rho_abs;
        prof_corr(p).Rho_sq = rho_sq;
    end
    
    prof_corr_table = struct2table(prof_corr);
    writetable(prof_corr_table, fullfile(out_dir, 'reliability_measurement_profile_summary_v2.csv'));
    
    %% 3. Per-trial Spearman correlation (Trial-level bootstrap)
    % Calculate trial-level correlations
    fprintf('\n[Per-Trial Spearman Correlation & Bootstrap CI]\n');
    trials_ids = unique(T.Trial);
    rho_trial_abs = zeros(length(trials_ids) * length(profiles), 1);
    
    t_idx = 1;
    for p = 1:length(profiles)
        pid = profiles{p};
        for t = 1:length(trials_ids)
            tid = trials_ids(t);
            idx = strcmp(T.ProfileID, pid) & T.Trial == tid;
            if sum(idx) > 10 % Need enough samples to correlate
                rho_trial_abs(t_idx) = corr(T.m_k(idx), abs_e(idx), 'type', 'Spearman');
            else
                rho_trial_abs(t_idx) = NaN;
            end
            t_idx = t_idx + 1;
        end
    end
    
    rho_trial_abs = rho_trial_abs(~isnan(rho_trial_abs));
    med_rho_trial = median(rho_trial_abs);
    
    boot_rho = bootstrp(1000, @median, rho_trial_abs);
    ci_rho = prctile(boot_rho, [2.5, 97.5]);
    fprintf('  Median Per-Trial Rho(m_k, |e_meas|): %.4f (95%% CI: %.4f, %.4f)\n', med_rho_trial, ci_rho(1), ci_rho(2));
    
    % Save trial summary
    fileID = fopen(fullfile(out_dir, 'reliability_measurement_trial_summary_v2.csv'), 'w');
    fprintf(fileID, 'Metric,Value,CI95_Lower,CI95_Upper\n');
    fprintf(fileID, 'Median_Trial_Rho_abs,%.4f,%.4f,%.4f\n', med_rho_trial, ci_rho(1), ci_rho(2));
    fclose(fileID);
    
    %% 4. PRE / FADE / POST conditional results
    fprintf('\n[Conditional Results by Phase]\n');
    phases = {'PRE', 'FADE', 'POST'};
    for ph = 1:length(phases)
        idx = strcmp(T.Phase, phases{ph});
        if sum(idx) > 0
            m_k_sub = T.m_k(idx);
            abs_e_sub = abs_e(idx);
            rho_abs = corr(m_k_sub, abs_e_sub, 'type', 'Spearman');
            med_e = median(abs_e_sub);
            fprintf('  Phase: %-4s | Count: %5d | Rho(m_k, |e_meas|): %.4f | Median |e_meas|: %.4f\n', phases{ph}, sum(idx), rho_abs, med_e);
        end
    end
    
    %% 5. Plot
    f = figure('Name', 'Reliability Validity V2', 'Position', [100 100 600 400]);
    bar(1:num_bins, bin_median, 'FaceColor', [0.2 0.6 0.8]); hold on;
    errorbar(1:num_bins, bin_median, bin_median - bin_ci_low, bin_ci_high - bin_median, 'k.', 'LineWidth', 1.5);
    set(gca, 'XTick', 1:num_bins, 'XTickLabel', bin_labels);
    xlabel('Reliability (m_k) Quantile Bins');
    ylabel('Median Absolute Measurement Error |e_{meas}| (samples)');
    title('DLL Measurement Error vs Reliability Metric (V2)');
    grid on;
    
    exportgraphics(f, fullfile(out_dir, 'Fig_Reliability_vs_DLL_Error_v2.png'), 'Resolution', 300);
    exportgraphics(f, fullfile(out_dir, 'Fig_Reliability_vs_DLL_Error_v2.pdf'), 'ContentType', 'vector', 'BackgroundColor', 'w');
    savefig(f, fullfile(out_dir, 'Fig_Reliability_vs_DLL_Error_v2.fig'));
    close(f);
end
