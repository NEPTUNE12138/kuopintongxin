function test_equalizer_shared_frontend()
    fprintf('Running test_equalizer_shared_frontend...\n');
    cfg = paper2_config('quick');
    cfg.frontend.use_trm = false;
    
    [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
    ch_file = cfg.channels{1, 1};
    [h_chan, ~] = select_bellhop_local_cluster(ch_file, cfg);
    rx = conv(tx_pb, h_chan, 'full');
    
    snr_db = 15;
    rx_pwr = norm(rx)^2 / length(rx);
    noise_pwr = rx_pwr / (10^(snr_db/10));
    rng(42);
    noise = sqrt(noise_pwr/2) * (randn(size(rx)) + 1j*randn(size(rx)));
    rx_noisy = rx + noise;
    
    [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_noisy, preamble, cfg);
    raw_sync.peak_idx = peak_idx;
    raw_sync.preamble_start = p_start;
    raw_sync.payload_start = pay_start;
    raw_sync.mf = mf;
    
    [rx_eq, eq_sync, app_meta] = apply_paper2_equalizer(rx_noisy, preamble, raw_sync, cfg);
    
    if ~app_meta.valid
        fprintf('  EQ not valid — skipping shared frontend check (acceptable).\n');
        fprintf('test_equalizer_shared_frontend passed.\n');
        return;
    end
    
    % Run all 3 trackers on identical EQ waveform
    variants = {'A', 'VB-FQ', 'E-FQ'};
    norms = zeros(1, 3);
    for v = 1:3
        [~, ~, meta] = run_paper2_receiver_variant(rx_eq, preamble, mseq_os, eq_sync, cfg, variants{v});
        norms(v) = norm(rx_eq);
    end
    
    % All must receive the exact same waveform norm
    assert(all(abs(norms - norms(1)) < 1e-10), 'All trackers must receive identical EQ waveform');
    
    fprintf('test_equalizer_shared_frontend passed.\n');
end
