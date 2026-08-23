function test_hvb_tracker()
% TEST_HVB_TRACKER Validates Q-freeze and heteroscedastic penalty scaling.

    cfg = paper2_config('quick');
    
    % Override frozen configuration to test the HVB module's adaptive capabilities
    cfg.hvb.q_adaptation_mode = 'both';
    cfg.hvb.use_q_freeze = true;
    cfg.q_freeze_reliability = 0.2;    
    % Initial states
    x_k = [0; 0];
    P_k = eye(2);
    alpha_k = 2;
    beta_k = 0.1;
    Q_k = [0.1 0; 0 0.1];
    
    % 1. High reliability test
    z_k = 0.5;
    u_k = 1;
    u_prev = 1;
    m_k = 1.0;
    
    [x1, P1, a1, b1, Q1, meta1] = hvb_akf_delay_tracker(z_k, u_k, u_prev, m_k, x_k, P_k, alpha_k, beta_k, Q_k, cfg);
    
    assert(meta1.Lambda_k == 1.0, 'Lambda must be 1 when m_k = 1');
    assert(any(Q1(:) ~= Q_k(:)), 'Q must adapt when reliable');
    
    % 2. Deep fade test (Q-freeze)
    m_k_fade = 0; % complete fade
    
    [x2, P2, a2, b2, Q2, meta2] = hvb_akf_delay_tracker(z_k, u_k, u_prev, m_k_fade, x_k, P_k, alpha_k, beta_k, Q_k, cfg);
    
    assert(meta2.Lambda_k > 1, 'Lambda must be > 1 in fade');
    assert(abs(meta2.Lambda_k - 51) < 1, 'Lambda max should be approx 51 for c2=1/50');
    assert(all(Q2(:) == Q_k(:)), 'Q must freeze in deep fade');
    
    disp('test_hvb_tracker passed.');
end
