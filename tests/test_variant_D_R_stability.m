function test_variant_D_R_stability()
% TEST_VARIANT_D_R_STABILITY Gate 7: Ensure Variant D R_iae does not explode

    cfg = paper2_config('quick');
    [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
    
    % Noiseless signal -> extremely high reliability (m_k ~ 1.0)
    % Variant D applies a penalty for low reliability, but for high reliability it should just be R_iae.
    % Wait, if penalty was applied multiplicatively to R_iae IN THE STATE, it might explode.
    % We ensure that the stored meta.R_vb (which is R_iae) is stable.
    
    [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(tx_pb, preamble, cfg);
    sync_meta.peak_idx = peak_idx;
    sync_meta.preamble_start = p_start;
    sync_meta.payload_start = pay_start;
    sync_meta.mf = mf;
    
    [~, ~, meta] = run_paper2_receiver_variant(tx_pb, preamble, mseq_os, sync_meta, cfg, 'D');
    
    assert(strcmp(meta.status, 'SUCCESS'), 'Variant D should succeed on noiseless.');
    
    R_iae_end = meta.R_vb(end);
    
    % Should remain small (around C_k or initial 0.1)
    assert(R_iae_end < 10, 'Variant D R_iae exploded!');
    
    disp('test_variant_D_R_stability passed.');
end
