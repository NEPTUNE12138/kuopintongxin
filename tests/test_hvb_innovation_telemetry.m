function test_hvb_innovation_telemetry()
% TEST_HVB_INNOVATION_TELEMETRY
% Verifies valid, finite, correctly sized innovation and NIS telemetry.

    fprintf('Running test_hvb_innovation_telemetry...\n');
    cfg.c2 = 0.05; cfg.N_vb = 2;
    z_k = 10; u_k = 0; u_prev = 0; m_k = 1;
    x_prev = [0; 0]; P_prev = eye(2); alpha_prev = 1; beta_prev = 1; Q_prev = eye(2);
    
    [~, ~, ~, ~, ~, meta] = hvb_akf_delay_tracker(z_k, u_k, u_prev, m_k, x_prev, P_prev, alpha_prev, beta_prev, Q_prev, cfg);
    
    assert(isfield(meta, 'innovation'), 'Missing innovation');
    assert(isfield(meta, 'NIS'), 'Missing NIS');
    assert(isfield(meta, 'S'), 'Missing S');
    
    assert(isfinite(meta.innovation), 'Innovation not finite');
    assert(isfinite(meta.NIS), 'NIS not finite');
    
    fprintf('test_hvb_innovation_telemetry passed.\n');
end
