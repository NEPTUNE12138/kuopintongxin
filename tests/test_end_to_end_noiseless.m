function test_end_to_end_noiseless()
% TEST_END_TO_END_NOISELESS Gate 3: Verifies 0 BER on a delta channel without noise.

    cfg = paper2_config('quick');
    cfg.num_data_bits = 50; % Short packet for test
    cfg.num_diff_symbols = 51;
    
    [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
    
    % Delta Channel (No fade, no noise)
    rx_pb = tx_pb; 
    
    % Sync
    [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_pb, preamble, cfg);
    
    sync_meta.peak_idx = peak_idx;
    sync_meta.preamble_start = p_start;
    sync_meta.payload_start = pay_start;
    sync_meta.mf = mf;
    
    variants = {'A', 'B', 'C', 'D', 'E'};
    
    fprintf('\n--- Noiseless End-to-End Test ---\n');
    for i = 1:length(variants)
        var = variants{i};
        [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_pb, preamble, mseq_os, sync_meta, cfg, var);
        
        assert(strcmp(meta.status, 'SUCCESS'), 'Variant %s failed: %s', var, meta.failure_reason);
        assert(length(decoded_bits) == length(data_bits), 'Variant %s decoded length mismatch.', var);
        
        errors = sum(decoded_bits ~= data_bits);
        ber = errors / length(data_bits);
        
        fprintf('%s: decoded bits=%d, errors=%d, BER=%.4f\n', var, length(decoded_bits), errors, ber);
        assert(errors == 0, 'Variant %s failed to achieve 0 BER in noiseless conditions.', var);
    end
    fprintf('test_end_to_end_noiseless passed.\n');
end
