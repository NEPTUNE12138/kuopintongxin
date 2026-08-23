function [rx_eq, eq_sync_meta, app_meta] = apply_paper2_equalizer(rx_raw, preamble, raw_sync_meta, cfg)
% APPLY_PAPER2_EQUALIZER Full equalization pipeline: estimate, design, apply, re-sync.
%
% Inputs:
%   rx_raw        - raw received waveform
%   preamble      - known HFM preamble
%   raw_sync_meta - coarse sync metadata from raw waveform
%   cfg           - configuration struct
%
% Outputs:
%   rx_eq         - equalized waveform
%   eq_sync_meta  - post-EQ synchronization metadata
%   app_meta      - application metadata

    app_meta = struct();
    app_meta.valid = true;
    
    % 1. Estimate channel
    [h_hat, est_meta] = estimate_channel_from_hfm_ls(rx_raw, preamble, raw_sync_meta, cfg);
    app_meta.est_meta = est_meta;
    
    if ~est_meta.valid
        rx_eq = rx_raw;
        eq_sync_meta = raw_sync_meta;
        app_meta.valid = false;
        app_meta.reason = est_meta.reason;
        return;
    end
    
    % 2. Design MMSE equalizer
    [w, eq_design_meta] = design_linear_mmse_equalizer(h_hat, est_meta.eta, cfg);
    app_meta.eq_design_meta = eq_design_meta;
    app_meta.h_hat = h_hat;
    app_meta.w = w;
    
    if ~eq_design_meta.valid
        rx_eq = rx_raw;
        eq_sync_meta = raw_sync_meta;
        app_meta.valid = false;
        app_meta.reason = eq_design_meta.reason;
        return;
    end
    
    % 3. Apply equalizer via full convolution
    rx_eq = conv(rx_raw, w, 'full');
    
    % 4. Re-synchronize on equalized waveform
    try
        [peak_idx, p_start, pay_start, mf, ~] = coarse_sync_from_preamble(rx_eq, preamble, cfg);
        eq_sync_meta.peak_idx = peak_idx;
        eq_sync_meta.preamble_start = p_start;
        eq_sync_meta.payload_start = pay_start;
        eq_sync_meta.mf = mf;
    catch ME
        rx_eq = rx_raw;
        eq_sync_meta = raw_sync_meta;
        app_meta.valid = false;
        app_meta.reason = sprintf('Post-EQ sync failed: %s', ME.message);
    end
end
