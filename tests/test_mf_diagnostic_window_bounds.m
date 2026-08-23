function test_mf_diagnostic_window_bounds()
% TEST_MF_DIAGNOSTIC_WINDOW_BOUNDS
% Verifies that extract_mf_local_window correctly caps window extraction
% against the length of the matched-filter array.

    fprintf('Running test_mf_diagnostic_window_bounds...\n');
    
    % Simulate a short matched filter array where peak is near the end
    mf_len = 300;
    mf = randn(1, mf_len);
    peak_idx = 295;
    mf(peak_idx) = 100;
    
    n_pre = 50;
    n_post = 200;
    
    % We expect win_end to cap at length(mf) = 300, not error out.
    [g_win, win_start, win_end] = extract_mf_local_window(mf, peak_idx, n_pre, n_post);
    
    assert(win_end <= mf_len, 'win_end must not exceed mf length');
    assert(win_start == peak_idx - n_pre, 'win_start incorrectly computed');
    assert(win_end == mf_len, 'win_end should be capped at mf_len');
    assert(length(g_win) == (win_end - win_start + 1), 'g_win length mismatch');
    
    fprintf('test_mf_diagnostic_window_bounds passed.\n');
end
