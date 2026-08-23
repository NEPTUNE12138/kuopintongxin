function test_final_no_trm_no_eq()
    fprintf('Running test_final_no_trm_no_eq...\n');
    
    vd = paper2_variant_definition('E-FQ');
    assert(vd.uses_trm == false, 'E-FQ uses_trm must be false');
    
    cfg = paper2_config('quick');
    assert(cfg.equalizer.enabled == false, 'Equalizer must be disabled');
    
    fprintf('test_final_no_trm_no_eq passed.\n');
end
