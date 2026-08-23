function test_final_stress_snr_frozen()
% TEST_FINAL_STRESS_SNR_FROZEN Verify that stress SNR is hardcoded to 15 dB.
    
    cfg = paper2_config('quick');
    assert(isfield(cfg, 'stress_snr_db'), 'cfg must contain stress_snr_db');
    assert(cfg.stress_snr_db == 15, sprintf('Stress SNR must be strictly 15 dB, got %d', cfg.stress_snr_db));
    
    disp('test_final_stress_snr_frozen passed.');
end
