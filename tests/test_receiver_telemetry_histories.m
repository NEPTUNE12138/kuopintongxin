function test_receiver_telemetry_histories()
% TEST_RECEIVER_TELEMETRY_HISTORIES
% Verifies correct lengths and finiteness of all telemetry histories.

    fprintf('Running test_receiver_telemetry_histories...\n');

    cfg = paper2_config('quick');
    cfg.frontend.use_trm = false;

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

    % Run E-FQ variant
    [~, ~, meta] = run_paper2_receiver_variant(rx_noisy, preamble, mseq_os, sync_meta, cfg, 'E-FQ');
    assert(strcmp(meta.status, 'SUCCESS'), 'E-FQ must succeed');

    N = cfg.num_diff_symbols;

    % Check 1D histories
    fields_1d = {'innovation', 'abs_innovation', 'NIS', 'S', 'R_vb', 'R_eff', 'Lambda', 'm_reliability', 'rho'};
    for i = 1:length(fields_1d)
        f = fields_1d{i};
        assert(isfield(meta, f), sprintf('Missing field: %s', f));
        assert(length(meta.(f)) == N, sprintf('Field %s has wrong length: %d vs %d', f, length(meta.(f)), N));
        assert(all(isfinite(meta.(f))), sprintf('Field %s has non-finite values', f));
    end

    % Check 2D histories
    assert(size(meta.K_gain, 1) == 2 && size(meta.K_gain, 2) == N, 'K_gain wrong size');
    assert(size(meta.Q_diag, 1) == 2 && size(meta.Q_diag, 2) == N, 'Q_diag wrong size');
    assert(size(meta.P_pred_diag, 1) == 2 && size(meta.P_pred_diag, 2) == N, 'P_pred_diag wrong size');

    assert(all(isfinite(meta.K_gain(:))), 'K_gain has non-finite values');
    assert(all(isfinite(meta.Q_diag(:))), 'Q_diag has non-finite values');
    assert(all(isfinite(meta.P_pred_diag(:))), 'P_pred_diag has non-finite values');

    fprintf('test_receiver_telemetry_histories passed.\n');
end
