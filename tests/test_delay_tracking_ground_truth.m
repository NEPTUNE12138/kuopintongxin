function test_delay_tracking_ground_truth()
% TEST_DELAY_TRACKING_GROUND_TRUTH Gate 5: Verified tracking RMSE against ground truth
    
    cfg = paper2_config('quick');
    cfg.num_data_bits = 100;
    cfg.num_diff_symbols = 101;
    
    [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
    
    % True time warp
    t = (0:length(tx_pb)-1) / cfg.fs;
    v0 = 0; 
    A_v = 1.0; % 1 m/s variation
    f_v = 0.5; % 0.5 Hz
    c_sound = 1500;
    
    alpha = 1 + (v0 + A_v * sin(2 * pi * f_v * t)) / c_sound;
    t_src = cumtrapz(t, alpha);
    t_src = t_src - t_src(1);
    
    rx_pb = interp1(t, tx_pb, t_src, 'linear', 0);
    
    % The true delay in samples:
    % t_src maps to t, so receiver at t gets source at t_src.
    % delay(t) = t_src - t; 
    % in samples: epsilon_true_samples = (t_src - t) * fs;
    epsilon_true_samples = (t_src - t) * cfg.fs;
    
    [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_pb, preamble, cfg);
    
    sync_meta.peak_idx = peak_idx;
    sync_meta.preamble_start = p_start;
    sync_meta.payload_start = pay_start;
    sync_meta.mf = mf;
    
    [decoded_bits, ~, meta_E] = run_paper2_receiver_variant(rx_pb, preamble, mseq_os, sync_meta, cfg, 'E');
    [~, ~, meta_A] = run_paper2_receiver_variant(rx_pb, preamble, mseq_os, sync_meta, cfg, 'A');
    
    assert(strcmp(meta_E.status, 'SUCCESS'), 'Variant E failed ground truth test.');
    
    % Compute RMSE
    % Sample centers for symbols
    sym_centers = sync_meta.payload_start + (0:cfg.num_diff_symbols-1) * cfg.symbol_samples + round(cfg.symbol_samples/2);
    sym_centers = min(length(epsilon_true_samples), max(1, sym_centers));
    
    eps_true_k = epsilon_true_samples(sym_centers);
    eps_true_rel = eps_true_k - eps_true_k(1);
    
    eps_est_rel_E = meta_E.delay_est_samples - meta_E.delay_est_samples(1);
    err_E = eps_est_rel_E - eps_true_rel;
    rmse_E = sqrt(mean(err_E.^2));
    
    eps_est_rel_A = meta_A.delay_est_samples - meta_A.delay_est_samples(1);
    err_A = eps_est_rel_A - eps_true_rel;
    rmse_A = sqrt(mean(err_A.^2));
    
    fprintf('\n--- Delay Tracking Ground Truth ---\n');
    fprintf('True Delay Variation: ~%.2f samples\n', max(eps_true_rel)-min(eps_true_rel));
    fprintf('Variant E RMSE: %.4f samples\n', rmse_E);
    fprintf('Variant A RMSE: %.4f samples\n', rmse_A);
    
    assert(rmse_E < 10, 'Proposed variant E tracking RMSE is too large (> 10 samples) under simple warp.');
    
    disp('test_delay_tracking_ground_truth passed.');
end
