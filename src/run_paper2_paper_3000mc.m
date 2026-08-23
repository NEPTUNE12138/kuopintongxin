function run_paper2_paper_3000mc()
% RUN_PAPER2_PAPER_3000MC End-to-end Final Paper 3000-MC Execution
    
    cfg = paper2_config('paper');
    
    % 1. Integrity Block
    assert(cfg.final_architecture_frozen == true, 'Architecture must be frozen');
    assert(strcmp(cfg.final_tracker_variant, 'E-FQ'), 'Final tracker must be E-FQ');
    assert(cfg.c2_frozen == true, 'c2 must be frozen');
    assert(abs(cfg.c2 - 1/50) < 1e-12, 'c2 must be 1/50');
    assert(isequal(cfg.final_Q, diag([0.05, 0.002])), 'Q must be [0.05, 0.002]');
    assert(cfg.reliability.calibration_symbols == 8, 'Kcal must be 8');
    assert(strcmp(cfg.reliability.mode, 'relative_calibrated'), 'reliability mode mismatch');
    assert(strcmp(cfg.hvb.q_adaptation_mode, 'fixed'), 'q mode mismatch');
    assert(cfg.frontend.use_trm == false, 'TRM must be disabled');
    assert(cfg.trm_primary_contribution == false, 'TRM must be disabled');
    assert(cfg.equalizer.enabled == false, 'EQ must be disabled');
    assert(cfg.equalizer.adopted == false, 'EQ must be disabled');
    assert(isequal(cfg.snr_range, -16:1:-10), 'BER SNR grid mismatch');
    assert(isequal(cfg.pilot_snr_range, -16:1:-10), 'Pilot SNR grid mismatch');
    assert(cfg.stress_snr_db == 15, 'Stress SNR mismatch');
    assert(cfg.mc_trials_ber == 3000, 'BER MC must be 3000');
    assert(cfg.mc_trials_stress == 3000, 'Stress MC must be 3000');
    
    % Note: SHA check happens conceptually here; we save dummy SHA if git not available from MATLAB
    paper_basis_sha = '01521c6d3bc2f3d9455b87e01898869fb635b37a';
    execution_worktree_sha = 'N/A'; % Can be extracted via system('git rev-parse HEAD')
    [status, cmdout] = system('git rev-parse HEAD');
    if status == 0
        execution_worktree_sha = strtrim(cmdout);
    end
    
    variants = {'A', 'VB-FQ', 'E-FQ'};
    csv_labels = {'IAE', 'VB-FQ', 'E-FQ'};
    num_variants = length(variants);
    
    num_snr = length(cfg.snr_range);
    num_channels = size(cfg.channels, 1);
    num_mc_ber = cfg.mc_trials_ber;
    num_mc_stress = cfg.mc_trials_stress;
    
    out_dir = fullfile('results', 'paper');
    chk_dir = fullfile(out_dir, 'checkpoints');
    if ~exist(chk_dir, 'dir')
        mkdir(chk_dir);
    end
    
    fprintf('\n=== Starting Final 3000-MC Paper Execution ===\n');
    
    % --- BER EXECUTION ---
    raw_errors = NaN(num_channels, num_snr, num_variants, num_mc_ber);
    
    for ch_idx = 1:num_channels
        ch_file = cfg.channels{ch_idx, 1};
        [h_cir, ~] = select_bellhop_local_cluster(ch_file, cfg);
        
        for snr_idx = 1:num_snr
            snr_db = cfg.snr_range(snr_idx);
            chk_file = fullfile(chk_dir, sprintf('chk_ber_CH%d_SNR%d.mat', ch_idx, round(snr_db)));
            
            if exist(chk_file, 'file')
                fprintf('Resuming BER Checkpoint: CH%d SNR%d\n', ch_idx, round(snr_db));
                load(chk_file, 'raw_errors_slice', 'cfg_snap');
                assert(isequal(cfg_snap.snr_range, cfg.snr_range), 'PAPER_RESUME_INTEGRITY_FAILURE');
                raw_errors(ch_idx, snr_idx, :, :) = raw_errors_slice;
                continue;
            end
            
            fprintf('Processing BER: Channel %d/%d at SNR %d dB\n', ch_idx, num_channels, snr_db);
            raw_errors_slice = NaN(num_variants, num_mc_ber);
            
            for mc = 1:num_mc_ber
                rng_seed = cfg.master_seed + mc + snr_idx*10000 + ch_idx*100000;
                rng(rng_seed, 'twister');
                
                [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
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
                
                for v = 1:num_variants
                    var_char = variants{v};
                    try
                        [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_noisy, preamble, mseq_os, sync_meta, cfg, var_char);
                        if strcmp(meta.status, 'SYNC_FAIL') || isempty(decoded_bits)
                            raw_errors_slice(v, mc) = NaN;
                        else
                            errors = sum(decoded_bits ~= data_bits(1:length(decoded_bits)));
                            raw_errors_slice(v, mc) = errors;
                        end
                    catch ME
                        if strcmp(ME.identifier, 'Paper2:SyncFail')
                            raw_errors_slice(v, mc) = NaN;
                        else
                            rethrow(ME);
                        end
                    end
                end
            end
            
            % Save slice
            cfg_snap = cfg;
            save(chk_file, 'raw_errors_slice', 'cfg_snap', 'paper_basis_sha');
            raw_errors(ch_idx, snr_idx, :, :) = raw_errors_slice;
        end
    end
    
    % Save final BER MAT
    ber_results = NaN(num_channels, num_snr, num_variants, num_mc_ber);
    for ch_idx = 1:num_channels
        for snr_idx = 1:num_snr
            for v = 1:num_variants
                ber_results(ch_idx, snr_idx, v, :) = squeeze(raw_errors(ch_idx, snr_idx, v, :))' / cfg.num_data_bits;
            end
        end
    end
    save_file_ber = fullfile(out_dir, 'paper2_ber_validation_3000mc.mat');
    mode = 'paper';
    save(save_file_ber, 'raw_errors', 'ber_results', 'cfg', 'variants', 'csv_labels', 'mode', 'paper_basis_sha', 'execution_worktree_sha');
    
    
    % --- STRESS EXECUTION ---
    results_stress = struct();
    for ch_idx = 1:num_channels
        ch_key = sprintf('CH%d', ch_idx);
        for v = 1:num_variants
            vc = strrep(variants{v}, '-', '_');
            results_stress.(ch_key).(vc).rmse_pre = NaN(1, num_mc_stress);
            results_stress.(ch_key).(vc).rmse_fade = NaN(1, num_mc_stress);
            results_stress.(ch_key).(vc).rmse_post = NaN(1, num_mc_stress);
            results_stress.(ch_key).(vc).rmse_overall = NaN(1, num_mc_stress);
            
            results_stress.(ch_key).(vc).m_pre = NaN(1, num_mc_stress);
            results_stress.(ch_key).(vc).m_fade = NaN(1, num_mc_stress);
            results_stress.(ch_key).(vc).m_post = NaN(1, num_mc_stress);
            
            results_stress.(ch_key).(vc).mean_Reff_Rvb_pre = NaN(1, num_mc_stress);
            results_stress.(ch_key).(vc).mean_Reff_Rvb_fade = NaN(1, num_mc_stress);
            results_stress.(ch_key).(vc).mean_Reff_Rvb_post = NaN(1, num_mc_stress);
            
            results_stress.(ch_key).(vc).mean_K_pre = NaN(1, num_mc_stress);
            results_stress.(ch_key).(vc).mean_K_fade = NaN(1, num_mc_stress);
            results_stress.(ch_key).(vc).mean_K_post = NaN(1, num_mc_stress);
            
            results_stress.(ch_key).(vc).Q11_pre = NaN(1, num_mc_stress);
            results_stress.(ch_key).(vc).Q11_fade = NaN(1, num_mc_stress);
            results_stress.(ch_key).(vc).Q11_post = NaN(1, num_mc_stress);
            
            results_stress.(ch_key).(vc).Q22_pre = NaN(1, num_mc_stress);
            results_stress.(ch_key).(vc).Q22_fade = NaN(1, num_mc_stress);
            results_stress.(ch_key).(vc).Q22_post = NaN(1, num_mc_stress);
            
            results_stress.(ch_key).(vc).ber = NaN(1, num_mc_stress);
            results_stress.(ch_key).(vc).valid = false(1, num_mc_stress);
            results_stress.(ch_key).(vc).raw_errors = NaN(1, num_mc_stress);
        end
    end
    
    num_syms = cfg.num_diff_symbols;
    snr_db = cfg.stress_snr_db;
    
    for ch_idx = 1:num_channels
        ch_file = cfg.channels{ch_idx, 1};
        ch_key = sprintf('CH%d', ch_idx);
        chk_file = fullfile(chk_dir, sprintf('chk_stress_CH%d.mat', ch_idx));
        
        if exist(chk_file, 'file')
            fprintf('Resuming Stress Checkpoint: CH%d\n', ch_idx);
            load(chk_file, 'res_slice', 'cfg_snap');
            assert(isequal(cfg_snap.stress_snr_db, cfg.stress_snr_db), 'PAPER_RESUME_INTEGRITY_FAILURE');
            for v = 1:num_variants
                vc = strrep(variants{v}, '-', '_');
                results_stress.(ch_key).(vc) = res_slice.(vc);
            end
            continue;
        end
        
        [h_cir, ~] = select_bellhop_local_cluster(ch_file, cfg);
        fprintf('Processing Stress: Channel %d/%d\n', ch_idx, num_channels);
        
        res_slice = struct();
        for v = 1:num_variants
            vc = strrep(variants{v}, '-', '_');
            res_slice.(vc) = results_stress.(ch_key).(vc); % initialize empty
        end
        
        for mc = 1:num_mc_stress
            if mod(mc, 100) == 0 || mc < 10
                fprintf('  Stress Prog: %d/%d (%.1f%%) [CH%d]\n', mc, num_mc_stress, 100*mc/num_mc_stress, ch_idx);
            end
            rng_seed = cfg.master_seed + mc + 999000 + ch_idx*10000;
            rng(rng_seed, 'twister');
            
            [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
            rx_multi = conv(tx_pb, h_cir, 'full');
            
            t = (0:length(rx_multi)-1) / cfg.fs;
            warp_cfg.v0_mps = 0.5;
            warp_cfg.velocity_amp_mps = 1.5;
            warp_cfg.velocity_freq_hz = 0.2;
            warp_cfg.phase_rad = 0;
            
            [rx_warp, warp_meta] = apply_paper2_time_warp(rx_multi, cfg, warp_cfg);
            epsilon_true_samples = warp_meta.epsilon_true_samples;
            
            packet_duration = length(rx_warp) / cfg.fs;
            fade_center = packet_duration / 2;
            fade_width = 0.1;
            
            fade_env = 1 - 0.9 * exp(-0.5 * ((t - fade_center) / (fade_width / 3)).^2);
            rx_fade = rx_warp .* fade_env;
            
            rx_power = norm(rx_fade)^2 / length(rx_fade);
            noise_power = rx_power / (10^(snr_db / 10));
            noise = sqrt(noise_power/2) * (randn(size(rx_fade)) + 1j * randn(size(rx_fade)));
            rx_final = rx_fade + noise;
            
            [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_final, preamble, cfg);
            sync_meta.peak_idx = peak_idx;
            sync_meta.preamble_start = p_start;
            sync_meta.payload_start = pay_start;
            sync_meta.mf = mf;
            
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
            
            for v = 1:num_variants
                vc_key = strrep(variants{v}, '-', '_');
                
                try
                    [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_final, preamble, mseq_os, sync_meta, cfg, variants{v});
                    
                    if strcmp(meta.status, 'SUCCESS') && length(decoded_bits) == cfg.num_data_bits
                        errors = sum(decoded_bits ~= data_bits(1:length(decoded_bits)));
                        res_slice.(vc_key).ber(mc) = errors / cfg.num_data_bits;
                        res_slice.(vc_key).raw_errors(mc) = errors;
                        res_slice.(vc_key).valid(mc) = true;
                        
                        eps_est_rel = meta.delay_est_samples - meta.delay_est_samples(1);
                        err = eps_est_rel - eps_true_rel;
                        
                        res_slice.(vc_key).rmse_pre(mc) = sqrt(mean(err(pre_idx).^2));
                        res_slice.(vc_key).rmse_fade(mc) = sqrt(mean(err(fade_idx).^2));
                        res_slice.(vc_key).rmse_post(mc) = sqrt(mean(err(post_idx).^2));
                        res_slice.(vc_key).rmse_overall(mc) = sqrt(mean(err.^2));
                        
                        if isfield(meta, 'm_reliability')
                            res_slice.(vc_key).m_pre(mc) = median(meta.m_reliability(pre_idx), 'omitnan');
                            res_slice.(vc_key).m_fade(mc) = median(meta.m_reliability(fade_idx), 'omitnan');
                            res_slice.(vc_key).m_post(mc) = median(meta.m_reliability(post_idx), 'omitnan');
                        end
                        
                        if isfield(meta, 'R_eff') && isfield(meta, 'R_vb')
                            ratio = meta.R_eff ./ max(meta.R_vb, eps);
                            res_slice.(vc_key).mean_Reff_Rvb_pre(mc) = median(ratio(pre_idx), 'omitnan');
                            res_slice.(vc_key).mean_Reff_Rvb_fade(mc) = median(ratio(fade_idx), 'omitnan');
                            res_slice.(vc_key).mean_Reff_Rvb_post(mc) = median(ratio(post_idx), 'omitnan');
                        end
                        
                        if isfield(meta, 'K_gain')
                            res_slice.(vc_key).mean_K_pre(mc) = median(meta.K_gain(1, pre_idx), 'omitnan');
                            res_slice.(vc_key).mean_K_fade(mc) = median(meta.K_gain(1, fade_idx), 'omitnan');
                            res_slice.(vc_key).mean_K_post(mc) = median(meta.K_gain(1, post_idx), 'omitnan');
                        end
                        
                        if isfield(meta, 'Q_diag')
                            res_slice.(vc_key).Q11_pre(mc) = median(meta.Q_diag(1, pre_idx), 'omitnan');
                            res_slice.(vc_key).Q11_fade(mc) = median(meta.Q_diag(1, fade_idx), 'omitnan');
                            res_slice.(vc_key).Q11_post(mc) = median(meta.Q_diag(1, post_idx), 'omitnan');
                            
                            res_slice.(vc_key).Q22_pre(mc) = median(meta.Q_diag(2, pre_idx), 'omitnan');
                            res_slice.(vc_key).Q22_fade(mc) = median(meta.Q_diag(2, fade_idx), 'omitnan');
                            res_slice.(vc_key).Q22_post(mc) = median(meta.Q_diag(2, post_idx), 'omitnan');
                        end
                    end
                catch ME
                    if ~strcmp(ME.identifier, 'Paper2:SyncFail')
                        rethrow(ME);
                    end
                end
            end
        end
        
        cfg_snap = cfg;
        save(chk_file, 'res_slice', 'cfg_snap', 'paper_basis_sha');
        
        for v = 1:num_variants
            vc = strrep(variants{v}, '-', '_');
            results_stress.(ch_key).(vc) = res_slice.(vc);
        end
    end
    
    save_file_stress = fullfile(out_dir, 'paper2_stress_pilot_3000mc.mat');
    results = results_stress; % rename back to results for consistency
    save(save_file_stress, 'results', 'cfg', 'variants', 'csv_labels', 'mode', 'paper_basis_sha', 'execution_worktree_sha');
    
    fprintf('\n=== Execution Completed ===\n');
end
