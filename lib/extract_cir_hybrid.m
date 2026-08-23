function [h_ext, gamma_os, gamma_acf, gamma_hybrid, mask, meta] = extract_cir_hybrid(g, preamble, cfg)
% EXTRACT_CIR_HYBRID Extract CIR using Hybrid Threshold (OS-CFAR + ACF Sidelobe Floor)
% Inputs:
%   g: Matched filter / correlation output (the raw candidate CIR)
%   preamble: The known HFM preamble waveform
%   cfg: Configuration struct containing os_cfar and kappa_side
%
% Outputs:
%   h_ext: Extracted CIR (elements below threshold set to 0)
%   gamma_os: The OS-CFAR threshold sequence
%   gamma_acf: The constant threshold derived from ACF sidelobes
%   gamma_hybrid: The final combined threshold sequence
%   mask: Logical mask of detected paths
%   meta: Diagnostic metadata

    g = g(:).'; % Row vector
    preamble = preamble(:).';
    
    % 1. OS-CFAR on power of g
    g_power = abs(g).^2;
    [thresh_power, os_mask, os_meta] = os_cfar_1d(g_power, ...
        cfg.os_cfar.train_cells, cfg.os_cfar.guard_cells, ...
        cfg.os_cfar.order_idx, cfg.os_cfar.pfa);
    
    gamma_os = sqrt(thresh_power); % Convert power threshold back to amplitude threshold
    
    % 2. ACF of the HFM preamble
    [R_p, lags] = xcorr(preamble, preamble);
    R_p_amp = abs(R_p);
    
    % 3. Determine mainlobe exclusion region
    % Estimate mainlobe width using bandwidth
    if isfield(cfg, 'preamble_band') && isfield(cfg, 'fs')
        B = cfg.preamble_band(2) - cfg.preamble_band(1);
        mainlobe_half_width = ceil(cfg.fs / B); 
    else
        mainlobe_half_width = 30; % Fallback
    end
    
    center_idx = find(lags == 0);
    if isempty(center_idx)
        [~, center_idx] = max(R_p_amp); % Fallback
    end
    
    % 4. Max sidelobe ratio
    sidelobe_region = true(size(R_p_amp));
    exc_start = max(1, center_idx - mainlobe_half_width);
    exc_end   = min(length(R_p_amp), center_idx + mainlobe_half_width);
    sidelobe_region(exc_start:exc_end) = false;
    
    max_sidelobe = max(R_p_amp(sidelobe_region));
    rho_side = max_sidelobe / R_p_amp(center_idx);
    
    % 5. Threshold from ACF sidelobe
    g_peak = max(abs(g));
    if isfield(cfg, 'kappa_side')
        kappa = cfg.kappa_side;
    else
        kappa = 1.5;
    end
    gamma_acf = kappa * rho_side * g_peak;
    
    % 6. Hybrid Threshold
    gamma_hybrid = max(gamma_os, gamma_acf);
    
    % 7. Extract Paths
    mask = abs(g) >= gamma_hybrid;
    raw_hybrid_mask = mask;
    
    h_ext = zeros(size(g));
    h_ext(mask) = g(mask);
    
    fallback_used = false;
    fallback_index = NaN;
    
    % Fallback: if threshold is so high that nothing is detected (e.g., pure OS-CFAR on HFM)
    if ~any(mask)
        fallback_used = true;
        [~, max_idx] = max(abs(g));
        fallback_index = max_idx;
        h_ext(max_idx) = g(max_idx);
        mask(max_idx) = true;
    end
    
    % 8. Output Metadata
    meta.os_meta = os_meta;
    meta.rho_side = rho_side;
    meta.mainlobe_half_width = mainlobe_half_width;
    meta.g_peak = g_peak;
    meta.kappa_side = kappa;
    meta.gamma_acf = gamma_acf;
    
    meta.raw_os_mask = os_mask;
    meta.raw_hybrid_mask = raw_hybrid_mask;
    meta.final_mask = mask;
    meta.fallback_used = fallback_used;
    meta.fallback_index = fallback_index;
    
    meta.raw_os_path_count = sum(os_mask);
    meta.raw_hybrid_path_count = sum(raw_hybrid_mask);
    meta.final_path_count = sum(mask);
    
    gamma_acf_array = gamma_acf * ones(size(gamma_os));
    meta.acf_floor_active_fraction = mean(gamma_acf_array > gamma_os);
end
