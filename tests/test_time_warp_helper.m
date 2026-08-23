function test_time_warp_helper()
    cfg.fs = 48000;
    t = (0:47999)/cfg.fs;
    sig_in = sin(2*pi*1000*t);
    
    % 1. Zero velocity
    warp_cfg.v0_mps = 0;
    warp_cfg.velocity_amp_mps = 0;
    warp_cfg.velocity_freq_hz = 0;
    warp_cfg.phase_rad = 0;
    
    [~, warp_meta_0] = apply_paper2_time_warp(sig_in, cfg, warp_cfg);
    assert(max(abs(warp_meta_0.epsilon_true_samples)) < 1e-6, 'Zero velocity drift not zero');
    
    % 2. Constant positive velocity
    warp_cfg.v0_mps = 1.5;
    [~, warp_meta_pos] = apply_paper2_time_warp(sig_in, cfg, warp_cfg);
    
    % Epsilon = (t - t_src)*fs
    % t_src = t * (1 + v/c)
    % eps = t * fs * (-v/c)  -> should be monotonically decreasing or increasing based on definition
    diffs = diff(warp_meta_pos.epsilon_true_samples);
    assert(all(diffs < 0), 'Epsilon should drift monotonically for positive velocity');
    
    fprintf('test_time_warp_helper passed.\n');
end
