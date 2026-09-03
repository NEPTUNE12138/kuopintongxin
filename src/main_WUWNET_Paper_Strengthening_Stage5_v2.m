function main_WUWNET_Paper_Strengthening_Stage5_v2(mc_override)
% MAIN_WUWNET_PAPER_STRENGTHENING_STAGE5_V2 Sensitivity analysis
    mode = 'paper';
    cfg_base = paper2_config(mode);
    snr_db = 15;
    
    if nargin >= 1 && ~isempty(mc_override)
        num_mc = mc_override;
    else
        num_mc = 200;
    end
    
    variant = 'E-FQ';
    num_channels = size(cfg_base.channels, 1);
    num_syms = cfg_base.num_diff_symbols;
    
    fprintf('\n=== Starting STAGE 5 V2: Sensitivity Analysis ===\n');
    fprintf('MC Trials: %d | Channels: %d | SNR: %d dB | Variant: %s\n', num_mc, num_channels, snr_db, variant);
    
    out_dir = fullfile('results', 'paper_strengthening_v2');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    c2_vals = [0.01, 0.02, 0.05, 0.10];
    Kcal_fixed = 8;
    
    Kcal_vals = [4, 8, 16];
    c2_fixed = 0.02;
    
    fprintf('\n--- Running Sweep A: c2 ---\n');
    res_c2 = run_sweep(cfg_base, snr_db, num_mc, num_channels, variant, c2_vals, repmat(Kcal_fixed, 1, length(c2_vals)), 'c2');
    export_sweep_results(res_c2, c2_vals, cfg_base.channels, 'c2', fullfile(out_dir, 'Sensitivity_C2_200mc.csv'));
    
    fprintf('\n--- Running Sweep B: Kcal ---\n');
    res_Kcal = run_sweep(cfg_base, snr_db, num_mc, num_channels, variant, repmat(c2_fixed, 1, length(Kcal_vals)), Kcal_vals, 'Kcal');
    export_sweep_results(res_Kcal, Kcal_vals, cfg_base.channels, 'Kcal', fullfile(out_dir, 'Sensitivity_Kcal_200mc.csv'));
    
    plot_sensitivity(res_c2, c2_vals, res_Kcal, Kcal_vals, out_dir);
end

function res = run_sweep(cfg_base, snr_db, num_mc, num_channels, variant, c2_list, Kcal_list, sweep_name)
    num_vals = length(c2_list);
    num_syms = cfg_base.num_diff_symbols;
    
    res.rmse_fade = NaN(num_channels, num_vals, num_mc);
    res.rmse_overall = NaN(num_channels, num_vals, num_mc);
    res.valid = false(num_channels, num_vals, num_mc);
    
    for ch_idx = 1:num_channels
        ch_file = cfg_base.channels{ch_idx, 1};
        [h_cir, ~] = select_bellhop_local_cluster(ch_file, cfg_base);
        
        fprintf('Channel %d (%s)...\n', ch_idx, cfg_base.channels{ch_idx, 2});
        
        for val_idx = 1:num_vals
            fprintf('  Testing %s = %.2f...\n', sweep_name, ifelse(strcmp(sweep_name, 'c2'), c2_list(val_idx), Kcal_list(val_idx)));
            
            cfg = cfg_base;
            cfg.c2 = c2_list(val_idx);
            cfg.reliability.calibration_symbols = Kcal_list(val_idx);
            
            for mc = 1:num_mc
                rng_seed = cfg.master_seed + mc + 999000 + ch_idx*10000 + val_idx*100;
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
                fade_idx = first_fade:last_fade;
                
                try
                    [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_final, preamble, mseq_os, sync_meta, cfg, variant);
                    
                    if strcmp(meta.status, 'SUCCESS') && length(decoded_bits) == cfg.num_data_bits
                        res.valid(ch_idx, val_idx, mc) = true;
                        
                        eps_est_rel = meta.delay_est_samples - meta.delay_est_samples(1);
                        err = eps_est_rel - eps_true_rel;
                        
                        res.rmse_fade(ch_idx, val_idx, mc) = sqrt(mean(err(fade_idx).^2));
                        res.rmse_overall(ch_idx, val_idx, mc) = sqrt(mean(err.^2));
                    end
                catch ME
                    if ~strcmp(ME.identifier, 'Paper2:SyncFail')
                        rethrow(ME);
                    end
                end
            end
        end
    end
end

function export_sweep_results(res, vals, channels, sweep_name, csv_path)
    num_channels = size(channels, 1);
    num_vals = length(vals);
    
    out_ProfileID = cell(num_channels * num_vals, 1);
    out_Setting = zeros(num_channels * num_vals, 1);
    out_ValidRate = zeros(num_channels * num_vals, 1);
    out_MedianRMSEFade = zeros(num_channels * num_vals, 1);
    out_MedianRMSEOverall = zeros(num_channels * num_vals, 1);
    out_RelDev_Fade = zeros(num_channels * num_vals, 1);
    
    % Find nominal val index
    if strcmp(sweep_name, 'c2')
        nom_idx = find(vals == 0.02, 1);
    else
        nom_idx = find(vals == 8, 1);
    end
    
    row = 0;
    for ch = 1:num_channels
        mask_nom = squeeze(res.valid(ch, nom_idx, :));
        if sum(mask_nom) > 0
            nom_fade = median(res.rmse_fade(ch, nom_idx, mask_nom));
        else
            nom_fade = NaN;
        end
        
        for v = 1:num_vals
            row = row + 1;
            out_ProfileID{row} = sprintf('P%d', ch);
            out_Setting(row) = vals(v);
            
            mask = squeeze(res.valid(ch, v, :));
            out_ValidRate(row) = sum(mask) / length(mask);
            
            if sum(mask) > 0
                med_fade = median(res.rmse_fade(ch, v, mask));
                out_MedianRMSEFade(row) = med_fade;
                out_MedianRMSEOverall(row) = median(res.rmse_overall(ch, v, mask));
                out_RelDev_Fade(row) = (med_fade - nom_fade) / (nom_fade + eps);
            else
                out_MedianRMSEFade(row) = NaN;
                out_MedianRMSEOverall(row) = NaN;
                out_RelDev_Fade(row) = NaN;
            end
        end
    end
    
    T = table(out_ProfileID, out_Setting, out_MedianRMSEFade, out_MedianRMSEOverall, out_ValidRate, out_RelDev_Fade, ...
        'VariableNames', {'ProfileID', sweep_name, 'MedianRMSE_Fade', 'MedianRMSE_Overall', 'ValidRate', 'RelDev_from_Nominal_FadeRMSE'});
    
    writetable(T, csv_path);
    fprintf('Exported %s\n', csv_path);
end

function plot_sensitivity(res_c2, c2_vals, res_Kcal, Kcal_vals, out_dir)
    f = figure('Name', 'Sensitivity', 'Position', [100 100 800 400]);
    
    subplot(1, 2, 1);
    med_c2 = zeros(length(c2_vals), 1);
    for v = 1:length(c2_vals)
        all_fade = [];
        for ch = 1:3
            mask = squeeze(res_c2.valid(ch, v, :));
            vals = squeeze(res_c2.rmse_fade(ch, v, mask));
            all_fade = [all_fade; vals(:)];
        end
        if isempty(all_fade), med_c2(v) = NaN; else, med_c2(v) = median(all_fade, 'omitnan'); end
    end
    plot(c2_vals, med_c2, '-o', 'LineWidth', 2);
    xlabel('c_2 (Theory Penalty Factor)');
    ylabel('Median Fade RMSE (samples)');
    title('Sensitivity to c_2 (K_{cal} = 8)');
    grid on;
    
    subplot(1, 2, 2);
    med_K = zeros(length(Kcal_vals), 1);
    for v = 1:length(Kcal_vals)
        all_fade = [];
        for ch = 1:3
            mask = squeeze(res_Kcal.valid(ch, v, :));
            vals = squeeze(res_Kcal.rmse_fade(ch, v, mask));
            all_fade = [all_fade; vals(:)];
        end
        if isempty(all_fade), med_K(v) = NaN; else, med_K(v) = median(all_fade, 'omitnan'); end
    end
    plot(Kcal_vals, med_K, '-s', 'LineWidth', 2);
    xlabel('K_{cal} (Calibration Symbols)');
    ylabel('Median Fade RMSE (samples)');
    title('Sensitivity to K_{cal} (c_2 = 0.02)');
    grid on;
    
    exportgraphics(f, fullfile(out_dir, 'Fig_Sensitivity_C2_Kcal_v2.png'), 'Resolution', 300);
    close(f);
end

function out = ifelse(cond, a, b)
    if cond, out = a; else, out = b; end
end
