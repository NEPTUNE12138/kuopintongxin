function test_variant_consistency()
% TEST_VARIANT_CONSISTENCY Ensures all variants can be executed identically.

    cfg = paper2_config('quick');
    [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
    
    rx_pb = tx_pb; % Noiseless
    
    [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_pb, preamble, cfg);
    
    sync_meta.peak_idx = peak_idx;
    sync_meta.preamble_start = p_start;
    sync_meta.payload_start = pay_start;
    sync_meta.mf = mf;
    
    variants = {'A', 'B', 'C', 'D', 'E'};
    
    for i = 1:length(variants)
        var = variants{i};
        [decoded_bits, ~, meta] = run_paper2_receiver_variant(rx_pb, preamble, mseq_os, sync_meta, cfg, var);
        assert(strcmp(meta.status, 'SUCCESS'), 'Variant %s crashed.', var);
        assert(length(decoded_bits) == cfg.num_data_bits, 'Variant %s length mismatch.', var);
    end
    
    disp('test_variant_consistency passed.');
end
