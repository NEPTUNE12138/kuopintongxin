function benchmark_final_paper_variants()
% BENCHMARK_FINAL_PAPER_VARIANTS Runtime benchmark for IAE, VB-FQ, E-FQ

    out_file = fullfile('results', 'paper_review', 'final_runtime_table.csv');
    
    cfg = paper2_config('quick');
    cfg.snr_range = 15;
    
    [h_cir, ~] = select_bellhop_local_cluster(cfg.channels{1, 1}, cfg);
    
    [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
    rx_clean = conv(tx_pb, h_cir, 'full');
    
    rx_power = norm(rx_clean)^2 / length(rx_clean);
    noise_power = rx_power / (10^(15 / 10));
    noise = sqrt(noise_power/2) * (randn(size(rx_clean)) + 1j * randn(size(rx_clean)));
    rx_noisy = rx_clean + noise;
    
    [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_noisy, preamble, cfg);
    sync_meta.peak_idx = peak_idx;
    sync_meta.preamble_start = p_start;
    sync_meta.payload_start = pay_start;
    sync_meta.mf = mf;
    
    variants = {'A', 'VB-FQ', 'E-FQ'};
    labels = {'IAE', 'VB-FQ', 'E-FQ'};
    
    num_mc = 100;
    runtimes = zeros(3, num_mc);
    
    fprintf('Running Benchmark for 100 packets...\n');
    for v = 1:3
        vc = variants{v};
        fprintf('Variant: %s\n', labels{v});
        
        % Warmup
        run_paper2_receiver_variant(rx_noisy, preamble, mseq_os, sync_meta, cfg, vc);
        
        for m = 1:num_mc
            tic;
            run_paper2_receiver_variant(rx_noisy, preamble, mseq_os, sync_meta, cfg, vc);
            runtimes(v, m) = toc;
        end
    end
    
    m_med = median(runtimes, 2) * 1000; % ms
    m_p10 = prctile(runtimes, 10, 2) * 1000;
    m_p90 = prctile(runtimes, 90, 2) * 1000;
    
    fid = fopen(out_file, 'w');
    fprintf(fid, 'Variant,Median_ms_per_packet,P10_ms_per_packet,P90_ms_per_packet,RelativeRuntime_vs_IAE\n');
    
    for v = 1:3
        rel = m_med(v) / m_med(1);
        fprintf(fid, '%s,%.2f,%.2f,%.2f,%.3f\n', labels{v}, m_med(v), m_p10(v), m_p90(v), rel);
    end
    fclose(fid);
    
    disp('Benchmark complete.');
end
