function test_hvb_q_modes()
% TEST_HVB_Q_MODES
% Verifies Q-adaptation constraints for the 4 diagnostic modes.

    fprintf('Running test_hvb_q_modes...\n');
    cfg.c2 = 0.05;
    cfg.N_vb = 2;
    z_k = 10; u_k = 0; u_prev = 0; m_k = 1;
    x_prev = [0; 0]; P_prev = eye(2); alpha_prev = 1; beta_prev = 1;
    Q_prev = diag([0.05, 0.002]);
    
    % Force an innovation to cause adaptation
    cfg.hvb.use_q_freeze = false;
    
    cfg.hvb.q_adaptation_mode = 'fixed';
    [~, ~, ~, ~, Q_out, ~] = hvb_akf_delay_tracker(z_k, u_k, u_prev, m_k, x_prev, P_prev, alpha_prev, beta_prev, Q_prev, cfg);
    assert(abs(Q_out(1,1) - 0.05) < 1e-9 && abs(Q_out(2,2) - 0.002) < 1e-9, 'Fixed Q mode failed');
    
    cfg.hvb.q_adaptation_mode = 'q22_only';
    [~, ~, ~, ~, Q_out, ~] = hvb_akf_delay_tracker(z_k, u_k, u_prev, m_k, x_prev, P_prev, alpha_prev, beta_prev, Q_prev, cfg);
    assert(abs(Q_out(1,1) - 0.05) < 1e-9 && abs(Q_out(2,2) - 0.002) > 1e-9, 'Q22_only mode failed');
    
    cfg.hvb.q_adaptation_mode = 'q11_only';
    [~, ~, ~, ~, Q_out, ~] = hvb_akf_delay_tracker(z_k, u_k, u_prev, m_k, x_prev, P_prev, alpha_prev, beta_prev, Q_prev, cfg);
    assert(abs(Q_out(1,1) - 0.05) > 1e-9 && abs(Q_out(2,2) - 0.002) < 1e-9, 'Q11_only mode failed');
    
    cfg.hvb.q_adaptation_mode = 'both';
    [~, ~, ~, ~, Q_out, ~] = hvb_akf_delay_tracker(z_k, u_k, u_prev, m_k, x_prev, P_prev, alpha_prev, beta_prev, Q_prev, cfg);
    assert(abs(Q_out(1,1) - 0.05) > 1e-9 && abs(Q_out(2,2) - 0.002) > 1e-9, 'Both Q mode failed');
    
    fprintf('test_hvb_q_modes passed.\n');
end
