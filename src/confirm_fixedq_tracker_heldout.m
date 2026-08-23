function confirm_fixedq_tracker_heldout(mode)
% CONFIRM_FIXEDQ_TRACKER_HELDOUT  Held-out confirmatory experiment for E-FQ candidate.
%
% Held-out conditions (NOT used in Round-5 diagnostic):
%   Profiles: P2, P3
%   SNRs: 0, 15 dB
%   Scenarios: S0_Static, S1_Warp, S2_Fade, S3_Warp_Fade
%   Variants: A (IAE baseline), VB-FQ (ablation), E-FQ (candidate)
%   Trials: 50 MC per condition
%
% Pre-declared acceptance gates (Section 7 of Round-6 spec):
%   7.1 Validity: valid_rate >= 0.95 for E-FQ in every condition
%   7.2 Dynamic safety: median RMSE_EFQ <= 1.10 * median RMSE_IAE (S1,S3)
%   7.3 Generalization: median(RMSE_EFQ/RMSE_IAE) <= 0.95 across 16 conditions,
%                        and at least 12/16 have RMSE_EFQ <= RMSE_IAE
%   7.4 Reliability mechanism: fade Reff/Rvb > pre Reff/Rvb; fade K < pre K; static Reff/Rvb <= 1.15
%   7.5 Bayesian ablation: median held-out RMSE ratio E-FQ/VB-FQ < 1

    if nargin < 1, mode = 'quick'; end

    this_file = mfilename('fullpath');
    src_dir = fileparts(this_file);
    project_root = fileparts(src_dir);
    addpath(fullfile(project_root, 'config'));
    addpath(fullfile(project_root, 'lib'));

    cfg = paper2_config(mode);
    num_mc = 50;

    % Override: no TRM for any variant in this confirmatory test
    cfg.frontend.use_trm = false;

    profiles = [2, 3]; % P2, P3 only (held-out)
    snr_set = [0, 15];
    scenarios = {'S0_Static', 'S1_Warp', 'S2_Fade', 'S3_Warp_Fade'};
    variants = {'A', 'VB-FQ', 'E-FQ'};

    warp_cfg.v0_mps = 0.5;
    warp_cfg.velocity_amp_mps = 1.5;
    warp_cfg.velocity_freq_hz = 0.2;
    warp_cfg.phase_rad = 0;

    out_dir = fullfile(project_root, 'results', 'confirmatory');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end

    fid_sum = fopen(fullfile(out_dir, 'fixedq_heldout_summary.csv'), 'w');
    fprintf(fid_sum, 'Profile,SNR_dB,Scenario,Variant,ValidRate,RMSE_Median,RMSE_Mean,Bias_Median,BER,SyncFailRate\n');

    fid_phase = fopen(fullfile(out_dir, 'fixedq_heldout_phase_stats.csv'), 'w');
    fprintf(fid_phase, 'Profile,SNR_dB,Scenario,Variant,Phase,Metric,Mean,Median,P10,P90\n');

    metrics_list = {'m_reliability', 'rho_raw', 'rho_relative', 'Lambda', ...
        'R_vb', 'R_eff', 'R_eff_R_vb', 'K_delay', 'Q11', 'Q22', ...
        'innovation', 'abs_innovation', 'S', 'NIS', 'Ppred11', 'Ppred22', 'tracking_error'};

    res_all = struct();

    fprintf('\n=== Fixed-Q Held-Out Confirmatory Experiment ===\n');
    fprintf('MC Trials/Condition: %d\n', num_mc);

    for pi = 1:length(profiles)
        prof_idx = profiles(pi);
        ch_file = cfg.channels{prof_idx, 1};
        [h_chan, ~] = select_bellhop_local_cluster(ch_file, cfg);

        for si = 1:length(snr_set)
            snr_db = snr_set(si);

            for sc = 1:length(scenarios)
                scen_name = scenarios{sc};
                do_warp = contains(scen_name, 'Warp');
                do_fade = contains(scen_name, 'Fade');

                cond_key = sprintf('P%d_SNR%d_%s', prof_idx, snr_db, scen_name);
                fprintf('\n--- %s ---\n', cond_key);

                for v = 1:length(variants)
                    vn = variants{v};
                    res_all.(cond_key).(strrep(vn, '-', '_')).rmse = NaN(1, num_mc);
                    res_all.(cond_key).(strrep(vn, '-', '_')).bias = NaN(1, num_mc);
                    res_all.(cond_key).(strrep(vn, '-', '_')).ber = NaN(1, num_mc);
                    res_all.(cond_key).(strrep(vn, '-', '_')).sync_fail = 0;
                    res_all.(cond_key).(strrep(vn, '-', '_')).phase_data = struct();
                end

                for mc = 1:num_mc
                    if mod(mc, 10) == 0, fprintf('  Trial %d/%d\n', mc, num_mc); end

                    % Deterministic seed: shared across all variants for this trial
                    rng_seed = cfg.master_seed + 6000000 + prof_idx*100000 + si*10000 + sc*1000 + mc;
                    rng(rng_seed, 'twister');

                    [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
                    rx_clean = conv(tx_pb, h_chan, 'full');

                    if do_warp
                        [rx_warp, warp_meta] = apply_paper2_time_warp(rx_clean, cfg, warp_cfg);
                    else
                        rx_warp = rx_clean;
                        warp_meta.epsilon_true_samples = zeros(size(rx_warp));
                    end

                    if do_fade
                        t = (0:length(rx_warp)-1) / cfg.fs;
                        packet_duration = length(rx_warp) / cfg.fs;
                        fade_center = packet_duration / 2;
                        fade_width = 0.1;
                        fade_env = 1 - 0.9 * exp(-0.5 * ((t - fade_center) / (fade_width / 3)).^2);
                        rx_fade = rx_warp .* fade_env;
                    else
                        rx_fade = rx_warp;
                    end

                    rx_power = norm(rx_fade)^2 / length(rx_fade);
                    noise_power = rx_power / (10^(snr_db / 10));
                    noise = sqrt(noise_power/2) * (randn(size(rx_fade)) + 1j * randn(size(rx_fade)));
                    rx_final = rx_fade + noise;

                    try
                        [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_final, preamble, cfg);
                        sync_meta_shared.peak_idx = peak_idx;
                        sync_meta_shared.preamble_start = p_start;
                        sync_meta_shared.payload_start = pay_start;
                        sync_meta_shared.mf = mf;

                        sym_centers = pay_start + (0:cfg.num_diff_symbols-1) * cfg.symbol_samples + round(cfg.symbol_samples/2);
                        sym_centers = min(length(rx_warp), max(1, sym_centers));

                        phases = struct();
                        if do_fade
                            fade_env_at_centers = fade_env(sym_centers);
                            fade_mask = fade_env_at_centers < 0.5;
                            first_fade = find(fade_mask, 1, 'first');
                            last_fade = find(fade_mask, 1, 'last');
                            if ~isempty(first_fade) && ~isempty(last_fade)
                                phases.PRE = 1:(first_fade-1);
                                phases.FADE = first_fade:last_fade;
                                phases.POST = (last_fade+1):cfg.num_diff_symbols;
                            else
                                phases.NORMAL = 1:cfg.num_diff_symbols;
                            end
                        else
                            phases.NORMAL = 1:cfg.num_diff_symbols;
                        end

                        eps_true_per_symbol = warp_meta.epsilon_true_samples(sym_centers);
                        eps_true_rel = eps_true_per_symbol - eps_true_per_symbol(1);

                        for v = 1:length(variants)
                            vn = variants{v};
                            vn_safe = strrep(vn, '-', '_');
                            cfg_run = cfg;

                            try
                                [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_final, preamble, mseq_os, sync_meta_shared, cfg_run, vn);

                                if strcmp(meta.status, 'SUCCESS')
                                    eps_est_rel = meta.delay_est_samples - meta.delay_est_samples(1);
                                    err = eps_est_rel - eps_true_rel;
                                    res_all.(cond_key).(vn_safe).rmse(mc) = sqrt(mean(err.^2));
                                    res_all.(cond_key).(vn_safe).bias(mc) = mean(err);
                                    res_all.(cond_key).(vn_safe).ber(mc) = sum(decoded_bits ~= data_bits) / cfg.num_data_bits;

                                    % Collect phase-level telemetry
                                    phase_names = fieldnames(phases);
                                    for p_i = 1:length(phase_names)
                                        p_name = phase_names{p_i};
                                        p_idx = phases.(p_name);
                                        if isempty(p_idx), continue; end

                                        dt = struct();
                                        dt.m_reliability = safe_extract(meta, 'm_reliability', p_idx);
                                        dt.rho_raw = safe_extract_field(meta, 'rho_raw', p_idx);
                                        dt.rho_relative = safe_extract_field(meta, 'rho_relative', p_idx);
                                        dt.Lambda = safe_extract(meta, 'Lambda', p_idx);
                                        dt.R_vb = safe_extract(meta, 'R_vb', p_idx);
                                        dt.R_eff = safe_extract(meta, 'R_eff', p_idx);
                                        dt.R_eff_R_vb = dt.R_eff ./ max(dt.R_vb, eps);
                                        dt.K_delay = safe_extract_2d(meta, 'K_gain', 1, p_idx);
                                        dt.Q11 = safe_extract_2d(meta, 'Q_diag', 1, p_idx);
                                        dt.Q22 = safe_extract_2d(meta, 'Q_diag', 2, p_idx);
                                        dt.innovation = safe_extract(meta, 'innovation', p_idx);
                                        dt.abs_innovation = safe_extract(meta, 'abs_innovation', p_idx);
                                        dt.S = safe_extract(meta, 'S', p_idx);
                                        dt.NIS = safe_extract(meta, 'NIS', p_idx);
                                        dt.Ppred11 = safe_extract_2d(meta, 'P_pred_diag', 1, p_idx);
                                        dt.Ppred22 = safe_extract_2d(meta, 'P_pred_diag', 2, p_idx);
                                        dt.tracking_error = err(p_idx);

                                        if ~isfield(res_all.(cond_key).(vn_safe).phase_data, p_name)
                                            for m_i = 1:length(metrics_list)
                                                res_all.(cond_key).(vn_safe).phase_data.(p_name).(metrics_list{m_i}) = [];
                                            end
                                        end
                                        for m_i = 1:length(metrics_list)
                                            m_str = metrics_list{m_i};
                                            res_all.(cond_key).(vn_safe).phase_data.(p_name).(m_str) = ...
                                                [res_all.(cond_key).(vn_safe).phase_data.(p_name).(m_str), dt.(m_str)];
                                        end
                                    end
                                else
                                    res_all.(cond_key).(vn_safe).sync_fail = res_all.(cond_key).(vn_safe).sync_fail + 1;
                                end
                            catch ME_v
                                if strcmp(ME_v.identifier, 'Paper2:SyncFail')
                                    res_all.(cond_key).(vn_safe).sync_fail = res_all.(cond_key).(vn_safe).sync_fail + 1;
                                else
                                    rethrow(ME_v);
                                end
                            end
                        end
                    catch ME_sync
                        if strcmp(ME_sync.identifier, 'Paper2:SyncFail')
                            for v = 1:length(variants)
                                vn_safe = strrep(variants{v}, '-', '_');
                                res_all.(cond_key).(vn_safe).sync_fail = res_all.(cond_key).(vn_safe).sync_fail + 1;
                            end
                        else
                            rethrow(ME_sync);
                        end
                    end
                end

                % Write summary for this condition
                for v = 1:length(variants)
                    vn = variants{v};
                    vn_safe = strrep(vn, '-', '_');
                    r = res_all.(cond_key).(vn_safe);
                    valid = sum(~isnan(r.rmse));
                    valid_rate = valid / num_mc;
                    sync_fail_rate = r.sync_fail / num_mc;

                    fprintf(fid_sum, '%d,%d,%s,%s,%.4f,%.4f,%.4f,%.4f,%.6f,%.4f\n', ...
                        prof_idx, snr_db, scen_name, vn, valid_rate, ...
                        median(r.rmse, 'omitnan'), mean(r.rmse, 'omitnan'), ...
                        median(r.bias, 'omitnan'), mean(r.ber, 'omitnan'), sync_fail_rate);

                    % Phase stats
                    if isfield(r, 'phase_data')
                        pn = fieldnames(r.phase_data);
                        for p_i = 1:length(pn)
                            for m_i = 1:length(metrics_list)
                                m_str = metrics_list{m_i};
                                if ~isfield(r.phase_data.(pn{p_i}), m_str), continue; end
                                arr = r.phase_data.(pn{p_i}).(m_str);
                                if isempty(arr) || all(isnan(arr)), continue; end
                                fprintf(fid_phase, '%d,%d,%s,%s,%s,%s,%.6f,%.6f,%.6f,%.6f\n', ...
                                    prof_idx, snr_db, scen_name, vn, pn{p_i}, m_str, ...
                                    mean(arr,'omitnan'), median(arr,'omitnan'), prctile(arr,10), prctile(arr,90));
                            end
                        end
                    end
                end
            end
        end
    end

    fclose(fid_sum);
    fclose(fid_phase);
    save(fullfile(out_dir, 'fixedq_heldout_raw.mat'), 'res_all', 'profiles', 'snr_set', 'scenarios', 'variants');
    fprintf('\nSaved held-out results to %s\n', out_dir);

    % ========= ACCEPTANCE GATE EVALUATION =========
    fprintf('\n=== ACCEPTANCE GATE EVALUATION ===\n');

    fid_dec = fopen(fullfile(out_dir, 'fixedq_heldout_decision.txt'), 'w');
    all_pass = true;

    % Collect per-condition results for gates
    cond_keys = {};
    rmse_efq = [];
    rmse_iae = [];
    rmse_vbfq = [];
    valid_efq = [];

    for pi = 1:length(profiles)
        prof_idx = profiles(pi);
        for si = 1:length(snr_set)
            snr_db = snr_set(si);
            for sc = 1:length(scenarios)
                scen_name = scenarios{sc};
                cond_key = sprintf('P%d_SNR%d_%s', prof_idx, snr_db, scen_name);
                cond_keys{end+1} = cond_key;

                r_efq = res_all.(cond_key).E_FQ;
                r_iae = res_all.(cond_key).A;
                r_vbfq = res_all.(cond_key).VB_FQ;

                rmse_efq(end+1) = median(r_efq.rmse, 'omitnan');
                rmse_iae(end+1) = median(r_iae.rmse, 'omitnan');
                rmse_vbfq(end+1) = median(r_vbfq.rmse, 'omitnan');
                valid_efq(end+1) = sum(~isnan(r_efq.rmse)) / num_mc;
            end
        end
    end

    % Gate 7.1: Validity
    gate71 = all(valid_efq >= 0.95);
    fprintf('Gate 7.1 (Validity >= 0.95): %s\n', gate_str(gate71));
    fprintf(fid_dec, 'Gate 7.1 (Validity >= 0.95): %s\n', gate_str(gate71));
    if ~gate71
        fprintf('  Min valid rate: %.4f\n', min(valid_efq));
        fprintf(fid_dec, '  Min valid rate: %.4f\n', min(valid_efq));
    end
    all_pass = all_pass && gate71;

    % Gate 7.2: Dynamic safety (S1, S3 conditions only)
    gate72 = true;
    for i = 1:length(cond_keys)
        if contains(cond_keys{i}, 'S1_') || contains(cond_keys{i}, 'S3_')
            ratio = rmse_efq(i) / max(rmse_iae(i), eps);
            if ratio > 1.10
                gate72 = false;
                fprintf('  Gate 7.2 FAIL: %s  E-FQ/IAE = %.4f\n', cond_keys{i}, ratio);
                fprintf(fid_dec, '  Gate 7.2 FAIL: %s  E-FQ/IAE = %.4f\n', cond_keys{i}, ratio);
            end
        end
    end
    fprintf('Gate 7.2 (Dynamic Safety <= 1.10): %s\n', gate_str(gate72));
    fprintf(fid_dec, 'Gate 7.2 (Dynamic Safety <= 1.10): %s\n', gate_str(gate72));
    all_pass = all_pass && gate72;

    % Gate 7.3: Overall generalization
    ratios = rmse_efq ./ max(rmse_iae, eps);
    med_ratio = median(ratios);
    wins = sum(rmse_efq <= rmse_iae);
    gate73a = med_ratio <= 0.95;
    gate73b = wins >= 12;
    gate73 = gate73a && gate73b;
    fprintf('Gate 7.3a (median E-FQ/IAE <= 0.95): %s (%.4f)\n', gate_str(gate73a), med_ratio);
    fprintf('Gate 7.3b (wins >= 12/16): %s (%d/16)\n', gate_str(gate73b), wins);
    fprintf(fid_dec, 'Gate 7.3a (median E-FQ/IAE <= 0.95): %s (%.4f)\n', gate_str(gate73a), med_ratio);
    fprintf(fid_dec, 'Gate 7.3b (wins >= 12/16): %s (%d/16)\n', gate_str(gate73b), wins);
    all_pass = all_pass && gate73;

    % Gate 7.4: Reliability mechanism
    gate74 = true;
    for pi = 1:length(profiles)
        prof_idx = profiles(pi);
        for si = 1:length(snr_set)
            snr_db = snr_set(si);

            % Static S0: median Reff/Rvb <= 1.15
            ck_s0 = sprintf('P%d_SNR%d_S0_Static', prof_idx, snr_db);
            if isfield(res_all.(ck_s0).E_FQ.phase_data, 'NORMAL')
                rr_s0 = median(res_all.(ck_s0).E_FQ.phase_data.NORMAL.R_eff_R_vb, 'omitnan');
                if rr_s0 > 1.15
                    gate74 = false;
                    fprintf('  Gate 7.4 FAIL: %s static Reff/Rvb = %.4f > 1.15\n', ck_s0, rr_s0);
                    fprintf(fid_dec, '  Gate 7.4 FAIL: %s static Reff/Rvb = %.4f > 1.15\n', ck_s0, rr_s0);
                end
            end

            % Fade scenarios S2, S3
            for fade_sc = {'S2_Fade', 'S3_Warp_Fade'}
                ck_fade = sprintf('P%d_SNR%d_%s', prof_idx, snr_db, fade_sc{1});
                pd = res_all.(ck_fade).E_FQ.phase_data;
                if isfield(pd, 'PRE') && isfield(pd, 'FADE')
                    rr_pre = median(pd.PRE.R_eff_R_vb, 'omitnan');
                    rr_fade = median(pd.FADE.R_eff_R_vb, 'omitnan');
                    k_pre = median(pd.PRE.K_delay, 'omitnan');
                    k_fade = median(pd.FADE.K_delay, 'omitnan');

                    if ~(rr_fade > rr_pre)
                        gate74 = false;
                        fprintf('  Gate 7.4 FAIL: %s Reff/Rvb FADE=%.4f not > PRE=%.4f\n', ck_fade, rr_fade, rr_pre);
                        fprintf(fid_dec, '  Gate 7.4 FAIL: %s Reff/Rvb FADE=%.4f not > PRE=%.4f\n', ck_fade, rr_fade, rr_pre);
                    end
                    if ~(k_fade < k_pre)
                        gate74 = false;
                        fprintf('  Gate 7.4 FAIL: %s K FADE=%.4f not < PRE=%.4f\n', ck_fade, k_fade, k_pre);
                        fprintf(fid_dec, '  Gate 7.4 FAIL: %s K FADE=%.4f not < PRE=%.4f\n', ck_fade, k_fade, k_pre);
                    end
                end
            end
        end
    end
    fprintf('Gate 7.4 (Reliability Mechanism): %s\n', gate_str(gate74));
    fprintf(fid_dec, 'Gate 7.4 (Reliability Mechanism): %s\n', gate_str(gate74));
    all_pass = all_pass && gate74;

    % Gate 7.5: Bayesian ablation
    ablation_ratios = rmse_efq ./ max(rmse_vbfq, eps);
    med_ablation = median(ablation_ratios);
    gate75 = med_ablation < 1;
    fprintf('Gate 7.5 (Bayesian Ablation E-FQ/VB-FQ < 1): %s (%.4f)\n', gate_str(gate75), med_ablation);
    fprintf(fid_dec, 'Gate 7.5 (Bayesian Ablation E-FQ/VB-FQ < 1): %s (%.4f)\n', gate_str(gate75), med_ablation);
    all_pass = all_pass && gate75;

    % Final Decision
    fprintf('\n');
    if all_pass
        fprintf('FIXEDQ_TRACKER_HELDOUT_PASS\n');
        fprintf('CANDIDATE_READY_FOR_FINAL_PARAMETER_FREEZE\n');
        fprintf('PILOT_STILL_NOT_RUN\n');
        fprintf(fid_dec, '\nFIXEDQ_TRACKER_HELDOUT_PASS\n');
        fprintf(fid_dec, 'CANDIDATE_READY_FOR_FINAL_PARAMETER_FREEZE\n');
        fprintf(fid_dec, 'PILOT_STILL_NOT_RUN\n');
    else
        fprintf('FIXEDQ_TRACKER_HELDOUT_FAIL\n');
        fprintf('FINAL_TRACKER_UNRESOLVED\n');
        fprintf('PILOT_BLOCKED\n');
        fprintf(fid_dec, '\nFIXEDQ_TRACKER_HELDOUT_FAIL\n');
        fprintf(fid_dec, 'FINAL_TRACKER_UNRESOLVED\n');
        fprintf(fid_dec, 'PILOT_BLOCKED\n');
    end
    fclose(fid_dec);

    fprintf('\nPILOT NOT RUN — waiting for scientific review.\n');
end

% ---- Helper functions ----
function s = gate_str(b)
    if b, s = 'PASS'; else, s = 'FAIL'; end
end

function v = safe_extract(meta, field, idx)
    if isfield(meta, field)
        v = meta.(field)(idx);
    else
        v = NaN(size(idx));
    end
end

function v = safe_extract_field(meta, field, idx)
    if isfield(meta, field) && ~isempty(meta.(field))
        v = meta.(field)(idx);
    else
        v = NaN(size(idx));
    end
end

function v = safe_extract_2d(meta, field, row, idx)
    if isfield(meta, field) && size(meta.(field), 1) >= row
        v = meta.(field)(row, idx);
    else
        v = NaN(size(idx));
    end
end
