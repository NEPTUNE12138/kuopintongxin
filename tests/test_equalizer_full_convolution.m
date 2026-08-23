function test_equalizer_full_convolution()
    fprintf('Running test_equalizer_full_convolution...\n');
    cfg = paper2_config('quick');
    
    rx = randn(1, 1000);
    w = randn(cfg.equalizer.eq_len, 1);
    
    rx_eq = conv(rx, w, 'full');
    
    % Full convolution length = length(rx) + length(w) - 1
    expected_len = length(rx) + length(w) - 1;
    assert(length(rx_eq) == expected_len, ...
        sprintf('EQ output length %d != expected %d', length(rx_eq), expected_len));
    
    fprintf('test_equalizer_full_convolution passed.\n');
end
