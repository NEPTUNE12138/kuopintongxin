function test_pilot_snr_range_persistence()
% TEST_PILOT_SNR_RANGE_PERSISTENCE Verify that pilot_snr_range is exactly -16:1:-10
% and propagates correctly into pilot and paper modes.
    
    cfg_quick = paper2_config('quick');
    assert(isequal(cfg_quick.pilot_snr_range, -16:1:-10), 'Pilot SNR range must be strictly -16:1:-10');
    
    cfg_pilot = paper2_config('pilot');
    assert(isequal(cfg_pilot.snr_range, -16:1:-10), 'Pilot mode snr_range must be -16:1:-10');
    
    cfg_paper = paper2_config('paper');
    assert(isequal(cfg_paper.snr_range, -16:1:-10), 'Paper mode snr_range must be -16:1:-10');
    
    disp('test_pilot_snr_range_persistence passed.');
end
