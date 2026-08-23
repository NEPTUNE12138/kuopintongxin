function test_equalizer_channel_estimator_noiseless()
    fprintf('Running test_equalizer_channel_estimator_noiseless...\n');
    cfg = paper2_config('quick');
    
    % Synthetic known short FIR
    h_true = [1; 0.5; -0.3; 0.1];
    Lh = length(h_true);
    cfg.equalizer.channel_len = Lh;
    
    preamble = generate_hfm_preamble(cfg);
    
    % Noiseless convolution
    rx = conv(preamble, h_true);
    
    % Mock sync metadata
    sync_meta.preamble_start = 1;
    sync_meta.payload_start = length(preamble) + cfg.guard_samples + 1;
    
    % Pad rx to include guard region
    rx = [rx, zeros(1, cfg.guard_samples + 1000)];
    
    [h_hat, est_meta] = estimate_channel_from_hfm_ls(rx, preamble, sync_meta, cfg);
    
    assert(est_meta.valid, 'Channel estimation must be valid');
    assert(all(isfinite(h_hat)), 'h_hat must be finite');
    
    % Aligned NMSE should be small for noiseless case
    h_hat = h_hat(:); h_true_col = h_true(:);
    a = (h_hat' * h_true_col) / max(h_hat' * h_hat, eps);
    nmse = norm(a*h_hat - h_true_col)^2 / max(norm(h_true_col)^2, eps);
    assert(nmse < 0.1, sprintf('NMSE too large: %.4f', nmse));
    
    fprintf('test_equalizer_channel_estimator_noiseless passed.\n');
end
