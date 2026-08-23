function [g_win, win_start, win_end] = extract_mf_local_window(mf, peak_idx, n_pre, n_post)
% EXTRACT_MF_LOCAL_WINDOW Extracts a safe window from matched filter output.
% Ensures that the extracted window does not exceed the boundaries of the matched filter array.
%
% Inputs:
%   mf       - The full matched filter output array.
%   peak_idx - Index of the peak in mf.
%   n_pre    - Number of samples to include before the peak.
%   n_post   - Number of samples to include after the peak.
%
% Outputs:
%   g_win     - The extracted window from the matched filter output.
%   win_start - The start index of the window in the original mf array.
%   win_end   - The end index of the window in the original mf array.

    win_start = max(1, peak_idx - n_pre);
    win_end   = min(length(mf), peak_idx + n_post);
    g_win = mf(win_start:win_end);
end
