function test_vbfq_ablation_definition()
% TEST_VBFQ_ABLATION_DEFINITION
% Verifies VB-FQ uses Lambda=1 (no reliability penalty) and fixed Q.

    fprintf('Running test_vbfq_ablation_definition...\n');

    var_def = paper2_variant_definition('VB-FQ');
    assert(var_def.uses_vb, 'VB-FQ must use VB tracker');
    assert(~var_def.uses_reliability, 'VB-FQ must NOT use reliability');

    cfg = paper2_config('quick');
    cfg.hvb.q_adaptation_mode = 'fixed';  % As VB-FQ sets it
    cfg.hvb.use_heteroscedastic = false;   % As VB-FQ sets it

    z_k = 5; u_k = 1; u_prev = 1; m_k = 0.5;
    x_prev = [0; 0]; P_prev = eye(2); alpha_prev = 2; beta_prev = 0.1;
    Q_init = diag([0.05, 0.002]);

    [~, ~, ~, ~, Q_out, meta] = hvb_akf_delay_tracker(z_k, u_k, u_prev, m_k, x_prev, P_prev, alpha_prev, beta_prev, Q_init, cfg);

    % Lambda must be exactly 1 (heteroscedastic disabled)
    assert(abs(meta.Lambda_k - 1.0) < 1e-12, 'VB-FQ Lambda must be 1');

    % Q must remain fixed
    assert(abs(Q_out(1,1) - 0.05) < 1e-12, 'VB-FQ Q11 must be fixed');
    assert(abs(Q_out(2,2) - 0.002) < 1e-12, 'VB-FQ Q22 must be fixed');

    fprintf('test_vbfq_ablation_definition passed.\n');
end
