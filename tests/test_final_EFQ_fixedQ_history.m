function test_final_EFQ_fixedQ_history()
    fprintf('Running test_final_EFQ_fixedQ_history...\n');
    
    cfg = paper2_config('quick');
    [tx_pb, ~, preamble, mseq, mseq_os, ~] = generate_paper2_tx_signal(cfg);
    [h_cir, ~] = select_bellhop_local_cluster(cfg.channels{1,1}, cfg);
    rx = conv(tx_pb, h_cir, 'full');
    
    [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx, preamble, cfg);
    sync.peak_idx = peak_idx;
    sync.preamble_start = p_start;
    sync.payload_start = pay_start;
    sync.mf = mf;
    
    [~, ~, meta] = run_paper2_receiver_variant(rx, preamble, mseq_os, sync, cfg, 'E-FQ');
    
    assert(strcmp(meta.status, 'SUCCESS'), 'Test must successfully sync');
    assert(isfield(meta, 'Q_diag'), 'E-FQ must output Q_diag');
    
    % Check all symbols
    for k = 1:size(meta.Q_diag, 2)
        q11 = meta.Q_diag(1, k);
        q22 = meta.Q_diag(2, k);
        assert(abs(q11 - 0.05) < 1e-6, sprintf('Q11 at sym %d is %.6f, expected 0.05', k, q11));
        assert(abs(q22 - 0.002) < 1e-6, sprintf('Q22 at sym %d is %.6f, expected 0.002', k, q22));
    end
    
    fprintf('test_final_EFQ_fixedQ_history passed.\n');
end
