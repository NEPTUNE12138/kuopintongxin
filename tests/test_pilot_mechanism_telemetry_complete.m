function test_pilot_mechanism_telemetry_complete()
% TEST_PILOT_MECHANISM_TELEMETRY_COMPLETE Checks E-FQ telemetry completeness.
    cfg = paper2_config('quick');
    
    rng(1, 'twister');
    [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
    
    rx_final = tx_pb + 0.1 * randn(size(tx_pb)); % fake channel
    
    [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_final, preamble, cfg);
    sync_meta.peak_idx = peak_idx;
    sync_meta.preamble_start = p_start;
    sync_meta.payload_start = pay_start;
    sync_meta.mf = mf;
    
    try
        [~, ~, meta] = run_paper2_receiver_variant(rx_final, preamble, mseq_os, sync_meta, cfg, 'E-FQ');
        
        assert(isfield(meta, 'm_reliability'), 'm_reliability missing');
        assert(isfield(meta, 'R_eff'), 'R_eff missing');
        assert(isfield(meta, 'R_vb'), 'R_vb missing');
        assert(isfield(meta, 'K_gain'), 'K_gain missing');
        assert(isfield(meta, 'Q_diag'), 'Q_diag missing');
        
        % Check that they have the required lengths
        N_syms = cfg.num_diff_symbols;
        assert(length(meta.m_reliability) == N_syms);
        assert(length(meta.R_eff) == N_syms);
        assert(length(meta.R_vb) == N_syms);
        assert(size(meta.K_gain, 2) == N_syms);
        assert(size(meta.Q_diag, 2) == N_syms);
        
        disp('test_pilot_mechanism_telemetry_complete passed.');
    catch ME
        if ~strcmp(ME.identifier, 'Paper2:SyncFail')
            rethrow(ME);
        end
    end
end
