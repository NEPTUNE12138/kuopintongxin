function test_trm_true_cir_metrics()
    cfg.samples_per_chip = 6;
    cfg.fs = 48000;
    
    % Delta channel
    h_eq = zeros(1, 100);
    h_eq(50) = 1;
    
    [rms_ds, peak_ratio, pslr] = compute_focusing_metrics(h_eq, cfg);
    assert(rms_ds < 1e-6, 'Delta channel RMS delay spread must be 0');
    assert(abs(peak_ratio - 1) < 1e-6, 'Delta channel peak ratio must be 1');
    assert(pslr > 50, 'Delta channel PSLR must be high');
    
    fprintf('test_trm_true_cir_metrics passed.\n');
end

function [rms_ds, peak_ratio, pslr] = compute_focusing_metrics(h_eq, cfg)
    p_eq = abs(h_eq).^2;
    total_energy = sum(p_eq) + eps;
    
    t_idx = (1:length(p_eq)) - 1;
    mean_delay = sum(t_idx .* p_eq) / total_energy;
    mean_sq_delay = sum((t_idx.^2) .* p_eq) / total_energy;
    rms_ds = sqrt(max(0, mean_sq_delay - mean_delay^2));
    
    [~, max_idx] = max(p_eq);
    window = cfg.samples_per_chip;
    idx_start = max(1, max_idx - window);
    idx_end = min(length(p_eq), max_idx + window);
    
    peak_energy = sum(p_eq(idx_start:idx_end));
    peak_ratio = peak_energy / total_energy;
    
    sidelobe_region = true(size(p_eq));
    sidelobe_region(idx_start:idx_end) = false;
    max_sl = max(p_eq(sidelobe_region));
    if max_sl > 0
        pslr = 10 * log10(p_eq(max_idx) / max_sl);
    else
        pslr = 100;
    end
end
