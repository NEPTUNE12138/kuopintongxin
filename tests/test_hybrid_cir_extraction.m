function test_hybrid_cir_extraction()
% TEST_HYBRID_CIR_EXTRACTION Verifies Hybrid threshold extraction with HFM

    cfg = paper2_config('quick');
    preamble = generate_hfm_preamble(cfg);
    
    % Create a synthetic correlation output (g)
    g = zeros(1, 1000);
    g(200) = 1.0; % Main path
    g(250) = 0.5; % Multipath
    
    % Add some noise simulating HFM ACF sidelobes
    g = g + 0.05 * randn(1, 1000) + 1j * 0.05 * randn(1, 1000);
    
    [h_ext, gamma_os, gamma_acf, gamma_hybrid, mask, meta] = extract_cir_hybrid(g, preamble, cfg);
    
    assert(meta.gamma_acf > 0, 'gamma_acf must be > 0 derived from HFM preamble.');
    assert(meta.rho_side > 0, 'rho_side must be extracted from HFM ACF.');
    assert(all(gamma_hybrid >= gamma_os), 'Hybrid threshold must be >= OS threshold.');
    
    assert(h_ext(200) ~= 0, 'Main peak must be detected.');
    assert(h_ext(250) ~= 0, 'Strong multipath must be detected.');
    
    disp('test_hybrid_cir_extraction passed.');
end
