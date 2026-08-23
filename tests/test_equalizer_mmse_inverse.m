function test_equalizer_mmse_inverse()
    fprintf('Running test_equalizer_mmse_inverse...\n');
    cfg = paper2_config('quick');
    
    % Known FIR
    h = [1; 0.5; -0.3; 0.1];
    Lh = length(h);
    cfg.equalizer.channel_len = Lh;
    cfg.equalizer.eq_len = Lh;
    cfg.equalizer.decision_delay = Lh - 1;
    
    eta = 0.01;
    [w, eq_meta] = design_linear_mmse_equalizer(h, eta, cfg);
    
    assert(eq_meta.valid, 'Equalizer must be valid');
    assert(all(isfinite(w)), 'w must be finite');
    assert(isfinite(eq_meta.lambda_eq), 'lambda_eq must be finite');
    
    % Combined response residual ISI should be lower than raw channel
    g = conv(h, w);
    D = cfg.equalizer.decision_delay;
    main = abs(g(D+1))^2;
    total = sum(abs(g).^2);
    residual_isi_eq = (total - main) / max(total, eps);
    
    % Raw channel ISI
    [~, main_idx] = max(abs(h));
    main_raw = abs(h(main_idx))^2;
    total_raw = sum(abs(h).^2);
    residual_isi_raw = (total_raw - main_raw) / max(total_raw, eps);
    
    assert(residual_isi_eq < residual_isi_raw, ...
        sprintf('EQ ISI %.4f should be < raw ISI %.4f', residual_isi_eq, residual_isi_raw));
    
    fprintf('test_equalizer_mmse_inverse passed.\n');
end
