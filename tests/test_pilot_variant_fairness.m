function test_pilot_variant_fairness()
% TEST_PILOT_VARIANT_FAIRNESS Checks shared waveform/noise/sync and variant set.
    val_code = fileread('src/main_WUWNET_Paper_Validation.m');
    
    mc_idx = strfind(val_code, 'for mc = 1:num_mc');
    var_idx = strfind(val_code, 'for v = 1:num_variants');
    rng_idx = strfind(val_code, 'rng(');
    sig_idx = strfind(val_code, 'rx_noisy = ');
    
    assert(~isempty(mc_idx), 'Could not find MC loop');
    assert(~isempty(var_idx), 'Could not find variant loop');
    assert(~isempty(rng_idx), 'Could not find rng initialization');
    assert(~isempty(sig_idx), 'Could not find signal generation');
    
    % Fairness requires rng and signal gen to happen AFTER MC loop starts, but BEFORE Variant loop starts
    assert(mc_idx(1) < rng_idx(1));
    assert(rng_idx(1) < sig_idx(1));
    assert(sig_idx(1) < var_idx(1));
    
    disp('test_pilot_variant_fairness passed.');
end
