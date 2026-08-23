function test_cfar_raw_detection_no_fallback()
% TEST_CFAR_RAW_DETECTION_NO_FALLBACK
% Validates that OS-CFAR and Hybrid extraction preserve raw detection semantics
% correctly regardless of fallback mechanisms.

    fprintf('Running test_cfar_raw_detection_no_fallback...\n');
    cfg = paper2_config('quick');
    preamble = generate_hfm_preamble(cfg);
    
    %% CASE A: RAW-DETECTION (Deterministic presence)
    % We construct a signal that OS-CFAR is guaranteed to detect.
    % Flat noise floor (which makes OS background low) and a clear peak.
    g_raw = 1e-6 * ones(1, 200); % non-zero constant floor, so OS can sort it
    g_raw(50) = 1.0; % Huge peak
    
    cfg_A = cfg;
    cfg_A.os_cfar.pfa = 1e-4; 
    cfg_A.os_cfar.order_idx = 0.75;
    
    [h_ext_A, ~, ~, ~, ~, meta_A] = extract_cir_hybrid(g_raw, preamble, cfg_A);
    
    assert(meta_A.fallback_used == false, 'Fallback should NOT be used for clear peak.');
    assert(isequal(meta_A.final_mask, meta_A.raw_hybrid_mask), 'Final mask should equal raw hybrid mask.');
    assert(meta_A.raw_os_path_count > 0, 'Raw OS path count should be > 0');
    assert(meta_A.raw_hybrid_path_count >= meta_A.raw_os_path_count, 'Raw hybrid count >= raw OS count');
    
    %% CASE B: FORCED-NO-RAW (Deterministic absence)
    % We construct a signal where raw hybrid mask is guaranteed EMPTY.
    % All zeros, except one tiny peak, with a huge kappa_side so hybrid threshold is unreachable.
    % Wait, if it's all zeros, OS-CFAR threshold might be 0, which detects the peak.
    % To guarantee OS-CFAR detects nothing, we make the peak smaller than the background.
    % Actually, if we just make it a tiny peak but increase the background...
    g_empty = ones(1, 200); % Background = 1
    g_empty(50) = 0.5; % Peak is smaller than background! No way CFAR detects it.
    
    cfg_B = cfg;
    cfg_B.os_cfar.pfa = 1e-4;
    cfg_B.kappa_side = 10; % Huge ACF threshold
    
    [h_ext_B, ~, ~, ~, ~, meta_B] = extract_cir_hybrid(g_empty, preamble, cfg_B);
    
    assert(meta_B.fallback_used == true, 'Fallback MUST be used when raw masks are empty.');
    assert(meta_B.raw_os_path_count == 0, 'Raw OS count must be exactly 0.');
    assert(meta_B.raw_hybrid_path_count == 0, 'Raw hybrid count must be exactly 0.');
    assert(sum(meta_B.final_mask) == 1, 'Final mask must have exactly 1 path (fallback).');
    
    fprintf('test_cfar_raw_detection_no_fallback passed.\n');
end
