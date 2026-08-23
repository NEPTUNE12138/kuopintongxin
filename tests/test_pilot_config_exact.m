function test_pilot_config_exact()
% TEST_PILOT_CONFIG_EXACT Checks exact frozen Pilot settings.
    cfg = paper2_config('pilot');
    
    assert(cfg.final_architecture_frozen == true);
    assert(strcmp(cfg.final_tracker_variant, 'E-FQ'));
    assert(cfg.c2_frozen == true);
    assert(abs(cfg.c2 - 1/50) < 1e-6);
    assert(isequal(cfg.final_Q, diag([0.05,0.002])));
    assert(cfg.reliability.calibration_symbols == 8);
    assert(strcmp(cfg.hvb.q_adaptation_mode, 'fixed'));
    assert(cfg.frontend.use_trm == false);
    if isfield(cfg, 'trm_primary_contribution')
        assert(cfg.trm_primary_contribution == false);
    end
    assert(cfg.equalizer.enabled == false);
    assert(cfg.equalizer.adopted == false);
    assert(isequal(cfg.snr_range, -16:1:-10));
    assert(isequal(cfg.pilot_snr_range, -16:1:-10));
    assert(cfg.stress_snr_db == 15);
    assert(cfg.mc_trials_ber == 200);
    assert(cfg.mc_trials_stress == 200);
    
    disp('test_pilot_config_exact passed.');
end
