function test_frontend_trm_override()
% TEST_FRONTEND_TRM_OVERRIDE
% Verifies that cfg.frontend.use_trm = false bypasses TRM for all variants.

    fprintf('Running test_frontend_trm_override...\n');

    cfg = paper2_config('quick');
    cfg.frontend.use_trm = false;

    % Generate a minimal test signal
    [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);

    ch_file = cfg.channels{1, 1};
    [h_chan, ~] = select_bellhop_local_cluster(ch_file, cfg);
    rx = conv(tx_pb, h_chan, 'full');

    snr_db = 20;
    rx_pwr = norm(rx)^2 / length(rx);
    noise_pwr = rx_pwr / (10^(snr_db/10));
    noise = sqrt(noise_pwr/2) * (randn(size(rx)) + 1j*randn(size(rx)));
    rx_noisy = rx + noise;

    [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_noisy, preamble, cfg);
    sync_meta.peak_idx = peak_idx;
    sync_meta.preamble_start = p_start;
    sync_meta.payload_start = pay_start;
    sync_meta.mf = mf;

    % Test with variant E (which normally uses TRM) — TRM must be bypassed
    [decoded_E, ~, meta_E] = run_paper2_receiver_variant(rx_noisy, preamble, mseq_os, sync_meta, cfg, 'E-FQ');
    assert(strcmp(meta_E.status, 'SUCCESS'), 'E-FQ with TRM override must succeed');

    % Verify no CIR meta (TRM was bypassed)
    assert(isempty(fieldnames(meta_E.cir_meta)), 'CIR meta must be empty when TRM is bypassed');

    % Test with variant A (which never uses TRM) — should also work fine
    [decoded_A, ~, meta_A] = run_paper2_receiver_variant(rx_noisy, preamble, mseq_os, sync_meta, cfg, 'A');
    assert(strcmp(meta_A.status, 'SUCCESS'), 'A with TRM override must succeed');

    fprintf('test_frontend_trm_override passed.\n');
end
