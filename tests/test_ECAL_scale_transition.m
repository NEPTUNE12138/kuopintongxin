function test_ECAL_scale_transition()
% TEST_ECAL_SCALE_TRANSITION Ensure rho_prev is correctly scaled at Kcal+1.

    cfg = paper2_config('quick');
    cfg.reliability.calibration_symbols = 4;
    
    sync_meta.peak_idx = 100;
    sync_meta.preamble_start = 50;
    sync_meta.payload_start = 200;
    sync_meta.mf = randn(1, 500);
    
    [~, ~, preamble, ~, mseq_os, ~] = generate_paper2_tx_signal(cfg);
    
    rx_noisy = randn(1, 10000); % Noise will produce low raw reliability
    
    [~, ~, meta] = run_paper2_receiver_variant(rx_noisy, preamble, mseq_os, sync_meta, cfg, 'E-CAL');
    
    % The raw reliability is likely around 0.1 ~ 0.2 because of noise.
    % In E-CAL, the first Kcal symbols have m_reliability based on raw rho.
    % At Kcal+1, m_k = sqrt(rho_rel_k * rho_rel_prev).
    % If rho_prev wasn't scaled, it would mix raw (e.g., 0.1) and relative (e.g., 1.0), causing an artificial dip.
    
    Kcal = cfg.reliability.calibration_symbols;
    
    % Just assert it runs and output the values for visual inspection if it fails.
    assert(isfield(meta, 'rho_relative'), 'Missing rho_relative');
    assert(~isnan(meta.rho_ref), 'Missing rho_ref');
    
    m_k_cal = meta.m_reliability(Kcal);
    m_k_post = meta.m_reliability(Kcal+1);
    
    % For random noise, rho_raw will be relatively steady. 
    % rho_rel should be around 1.0. 
    % m_k_post should be around 1.0. 
    % m_k_cal should be around rho_ref (e.g. 0.1).
    assert(m_k_post > 0.5, 'm_k dropped unnaturally at Kcal+1 transition. Scaling bug? m_k_post = %f', m_k_post);
    
    fprintf('test_ECAL_scale_transition passed.\n');
end
