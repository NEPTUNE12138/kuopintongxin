function test_final_architecture_freeze()
    fprintf('Running test_final_architecture_freeze...\n');
    cfg = paper2_config('quick');
    
    assert(strcmp(cfg.final_tracker_variant, 'E-FQ'), 'final_tracker_variant must be E-FQ');
    assert(cfg.c2 == 1/50, 'c2 must be exactly 1/50');
    assert(cfg.c2_frozen == true, 'c2_frozen must be true');
    assert(cfg.final_architecture_frozen == true, 'final_architecture_frozen must be true');
    assert(cfg.trm_primary_contribution == false, 'trm_primary_contribution must be false');
    assert(cfg.frontend.use_trm == false, 'frontend.use_trm must be false');
    assert(cfg.equalizer.enabled == false, 'equalizer.enabled must be false');
    assert(cfg.equalizer.adopted == false, 'equalizer.adopted must be false');
    assert(isequal(cfg.final_Q, diag([0.05, 0.002])), 'final_Q must be diag([0.05, 0.002])');
    assert(cfg.reliability.calibration_symbols == 8, 'Kcal must be 8');
    
    fprintf('test_final_architecture_freeze passed.\n');
end
