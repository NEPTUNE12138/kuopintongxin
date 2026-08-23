function test_reliability_calibration()
    cfg = paper2_config('quick');
    cfg.reliability.calibration_symbols = 8;
    
    sync_meta.peak_idx = 100;
    sync_meta.preamble_start = 50;
    sync_meta.payload_start = 200;
    sync_meta.mf = randn(1, 500);
    
    [~, ~, preamble, ~, mseq_os, ~] = generate_paper2_tx_signal(cfg);
    
    % Dummy signal
    rx_noisy = randn(1, 10000);
    
    [~, ~, meta] = run_paper2_receiver_variant(rx_noisy, preamble, mseq_os, sync_meta, cfg, 'E-CAL');
    
    assert(isfield(meta, 'rho_ref'), 'Missing rho_ref in E-CAL');
    assert(~isnan(meta.rho_ref), 'rho_ref is NaN');
    assert(isfield(meta, 'rho_relative'), 'Missing rho_relative in E-CAL');
    
    fprintf('test_reliability_calibration passed.\n');
end
