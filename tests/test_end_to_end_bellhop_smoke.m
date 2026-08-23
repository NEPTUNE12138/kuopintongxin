function test_end_to_end_bellhop_smoke()
% TEST_END_TO_END_BELLHOP_SMOKE Gate 4: Real Bellhop channel, no noise.
% Ensures variants don't crash and extract reasonably on multipath.

    cfg = paper2_config('quick');
    cfg.num_data_bits = 80;
    cfg.num_diff_symbols = 81;
    
    [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
    
    ch_file = cfg.channels{1, 1};
    [h, ~] = load_bellhop_cir(ch_file, cfg.fs);
    
    rx_pb = filter(h, 1, tx_pb);
    
    [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_pb, preamble, cfg);
    
    sync_meta.peak_idx = peak_idx;
    sync_meta.preamble_start = p_start;
    sync_meta.payload_start = pay_start;
    sync_meta.mf = mf;
    
    variants = {'A', 'B', 'C', 'D', 'E'};
    
    fprintf('\n--- Bellhop Smoke Test (High SNR, Profile 1) ---\n');
    for i = 1:length(variants)
        var = variants{i};
        [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_pb, preamble, mseq_os, sync_meta, cfg, var);
        
        assert(strcmp(meta.status, 'SUCCESS'), 'Variant %s failed on Bellhop smoke: %s', var, meta.failure_reason);
        assert(meta.num_processed_symbols >= 0.9 * cfg.num_diff_symbols, 'Variant %s lost track too early.', var);
        assert(~any(isnan(meta.delay_est_samples)), 'NaNs found in delay estimates.');
        
        errors = sum(decoded_bits ~= data_bits(1:length(decoded_bits)));
        ber = errors / max(1, length(decoded_bits));
        fprintf('%s: decoded bits=%d, errors=%d, BER=%.4f\n', var, length(decoded_bits), errors, ber);
    end
    fprintf('test_end_to_end_bellhop_smoke passed.\n');
end
