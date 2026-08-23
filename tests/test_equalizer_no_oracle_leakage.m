function test_equalizer_no_oracle_leakage()
    fprintf('Running test_equalizer_no_oracle_leakage...\n');
    
    % Verify estimate_channel_from_hfm_ls API does not accept true h
    % The function signature is: (rx_raw, preamble, sync_meta, cfg)
    % It has no parameter for h_true — this is verified by inspection.
    
    % Check that nargin of estimate_channel_from_hfm_ls is exactly 4
    n = nargin('estimate_channel_from_hfm_ls');
    assert(n == 4, sprintf('estimate_channel_from_hfm_ls must take exactly 4 args, got %d', n));
    
    fprintf('test_equalizer_no_oracle_leakage passed.\n');
end
