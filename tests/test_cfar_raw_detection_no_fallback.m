function test_cfar_raw_detection_no_fallback()
% TEST_CFAR_RAW_DETECTION_NO_FALLBACK Checks that fallback logic is separated from raw stats.
    cfg = paper2_config('quick');
    preamble = generate_hfm_preamble(cfg);
    
    % 1. Create a dummy matched filter output with NO signal, just noise, which guarantees fallback
    rng(12345, 'twister');
    g_fail = 1e-3 * randn(1, 100); % Pure noise, OS-CFAR will likely detect nothing (Pfa=1e-4)
    
    cfg_fail = cfg;
    cfg_fail.kappa_side = 10; % Force threshold to be higher than peak
    
    [~, ~, ~, ~, ~, meta] = extract_cir_hybrid(g_fail, preamble, cfg_fail);
    
    assert(meta.raw_os_path_count == 0, 'Raw OS path count should be 0');
    assert(meta.raw_hybrid_path_count == 0, 'Raw hybrid path count should be 0');
    assert(meta.fallback_used == true, 'Fallback should be used');
    assert(meta.final_path_count == 1, 'Final path count should be 1 due to fallback');
    
    % 2. Create a strong signal that will definitely pass CFAR
    g_pass = zeros(1, 100);
    g_pass(50) = 1;
    g_pass(55) = 0.8;
    g_pass = g_pass + 1e-3 * randn(1, 100); % small noise
    
    [~, ~, ~, ~, ~, meta_pass] = extract_cir_hybrid(g_pass, preamble, cfg);
    
    assert(meta_pass.fallback_used == false, 'Fallback should NOT be used for strong signal');
    assert(meta_pass.raw_os_path_count > 0, 'Raw OS should detect something');
    assert(meta_pass.raw_hybrid_path_count > 0, 'Raw Hybrid should detect something');
    
    fprintf('test_cfar_raw_detection_no_fallback passed.\n');
end
