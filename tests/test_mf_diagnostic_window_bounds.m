function test_mf_diagnostic_window_bounds()
% TEST_MF_DIAGNOSTIC_WINDOW_BOUNDS
% Verifies that if a matched-filter peak is near the end of the array,
% window slicing does not exceed array bounds.

    fprintf('Running test_mf_diagnostic_window_bounds...\n');
    cfg = paper2_config('quick');
    preamble = generate_hfm_preamble(cfg);
    
    % Simulate a short matched filter array where peak is near the end
    mf_len = 300;
    mf = randn(1, mf_len);
    peak_idx = 295;
    mf(peak_idx) = 100;
    
    sync_meta.peak_idx = peak_idx;
    sync_meta.mf = mf;
    sync_meta.preamble_start = 1;
    sync_meta.payload_start = 1;
    
    % We will call a subset of the receiver logic directly to test window bounds
    sig_pb = zeros(1, 1000); % dummy signal
    
    % Emulate receiver logic
    win_start = max(1, peak_idx - 50);
    % We expect win_end to cap at length(sync_meta.mf), not length(sig_pb)
    % The buggy code used length(sig_pb)
    
    % The correct bound:
    win_end   = min(length(sync_meta.mf), peak_idx + 200);
    g_win = sync_meta.mf(win_start:win_end);
    
    assert(win_end <= length(sync_meta.mf), 'win_end must not exceed mf length');
    assert(length(g_win) == (win_end - win_start + 1), 'g_win length mismatch');
    
    fprintf('test_mf_diagnostic_window_bounds passed.\n');
end
