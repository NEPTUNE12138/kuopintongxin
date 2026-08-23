function test_signal_model()
% TEST_SIGNAL_MODEL Verifies analytic passband DSSS/DBPSK generation.

    cfg = paper2_config('quick');
    [tx_pb, data_bits, preamble, mseq, mseq_os, tx_meta] = generate_paper2_tx_signal(cfg);
    
    % Check lengths
    assert(length(mseq) == 31, 'M-sequence length must be 31.');
    assert(length(mseq_os) == 186, 'Oversampled chip length must be 186.');
    assert(length(preamble) == tx_meta.preamble_samples, 'Preamble length mismatch.');
    
    % Check payload
    payload_len = length(tx_pb) - tx_meta.payload_start_index + 1 - tx_meta.guard_samples;
    expected_len = tx_meta.num_diff_symbols * tx_meta.symbol_samples;
    assert(payload_len == expected_len, 'Payload length mismatch.');
    
    % Check passband properties (should be complex analytic)
    assert(~isreal(tx_pb), 'Transmitted signal must be complex analytic passband.');
    
    disp('test_signal_model passed.');
end
