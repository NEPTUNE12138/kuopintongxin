function test_channel_full_convolution()
% TEST_CHANNEL_FULL_CONVOLUTION Ensures convolution is used rather than filter to avoid truncation.

    tx = ones(1, 100);
    h = [1, 0, 0, 0.5, 0, 0.2];
    
    rx_filter = filter(h, 1, tx);
    rx_conv = conv(tx, h, 'full');
    
    assert(length(rx_conv) == length(tx) + length(h) - 1, 'Conv length mismatch');
    assert(length(rx_filter) == length(tx), 'Filter length mismatch');
    
    % Test that late energy is captured by conv but not filter
    % The last element of rx_conv should be the tail
    assert(rx_conv(end) == 0.2, 'Conv failed to capture tail');
    
    fprintf('test_channel_full_convolution passed.\n');
end
