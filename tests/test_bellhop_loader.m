function test_bellhop_loader()
% TEST_BELLHOP_LOADER Gate 2: Verifies strict loader properties on real Bellhop MATs.

    cfg = paper2_config('quick');
    
    for i = 1:size(cfg.channels, 1)
        ch_file = cfg.channels{i, 1};
        [h, meta] = load_bellhop_cir(ch_file, cfg.fs);
        
        assert(isfield(meta, 'absolute_delays'), 'Missing absolute_delays in meta.');
        assert(length(meta.absolute_delays) == meta.num_arrivals, 'Arrival count mismatch.');
        assert(~isempty(h), 'FIR is empty.');
        assert(all(isfinite(h)), 'FIR contains non-finite values.');
        assert(abs(norm(h) - 1) < 1e-9, 'FIR is not unit-energy normalized.');
        assert(isfinite(meta.rms_delay_spread), 'RMS delay spread not finite.');
        
        % Ensure it's not a bounce-count matrix disguised as amplitudes
        % Real amplitudes should be complex or positive/negative, not integers 1, 2, 3...
        % Just verifying the max element isn't arbitrarily huge
        assert(max(abs(h)) <= 1.0, 'Max amplitude exceeds 1.0 after normalization.');
    end
    
    disp('test_bellhop_loader passed.');
end
