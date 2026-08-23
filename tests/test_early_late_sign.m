function test_early_late_sign()
% TEST_EARLY_LATE_SIGN Verifies the correction direction of the early-late DLL.

    cfg = paper2_config('quick');
    mseq = load_paper2_mseq(cfg);
    mseq_os = repelem(mseq, cfg.samples_per_chip);
    
    L_sym = length(mseq_os);
    delta = round(0.5 * cfg.samples_per_chip);
    
    % True symbol at index 100
    idx_true = 100;
    sig = zeros(1, 100 + L_sym + 100);
    sig(idx_true:idx_true+L_sym-1) = mseq_os;
    
    % 1. Positive Delay Error: The true signal is delayed relative to our estimate.
    % If our estimate is 95, true is 100. Error = +5 samples.
    idx_est = 95;
    
    seg_E = sig(idx_est - delta : idx_est + L_sym - 1 - delta);
    seg_L = sig(idx_est + delta : idx_est + L_sym - 1 + delta);
    
    E_pwr = abs(sum(seg_E .* mseq_os))^2;
    L_pwr = abs(sum(seg_L .* mseq_os))^2;
    
    D_k = (L_pwr - E_pwr) / (E_pwr + L_pwr + 1e-9);
    z_k = D_k * delta;
    
    % If true signal is late (positive delay error), Late segment has more energy.
    % D_k should be positive, and z_k should be positive.
    assert(z_k > 0, 'DLL sign logic is incorrect. Expected positive correction for positive delay error.');
    
    % 2. Negative Delay Error: True signal is early.
    % Estimate is 105, true is 100. Error = -5 samples.
    idx_est = 105;
    
    seg_E = sig(idx_est - delta : idx_est + L_sym - 1 - delta);
    seg_L = sig(idx_est + delta : idx_est + L_sym - 1 + delta);
    
    E_pwr = abs(sum(seg_E .* mseq_os))^2;
    L_pwr = abs(sum(seg_L .* mseq_os))^2;
    
    D_k = (L_pwr - E_pwr) / (E_pwr + L_pwr + 1e-9);
    z_k = D_k * delta;
    
    assert(z_k < 0, 'DLL sign logic is incorrect. Expected negative correction for negative delay error.');
    
    disp('test_early_late_sign passed.');
end
