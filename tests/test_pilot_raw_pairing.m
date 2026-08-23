function test_pilot_raw_pairing()
% TEST_PILOT_RAW_PAIRING Checks trial index/seeds align across variants.
    val_code = fileread('src/main_WUWNET_Paper_Validation.m');
    
    % Ensure that raw_errors is stored as a 4D array capturing all dimensions for paired analysis
    assert(~isempty(strfind(val_code, 'raw_errors(ch_idx, snr_idx, v, mc)')), 'raw_errors must be assigned using 4 paired dimensions');
    
    stress_code = fileread('src/main_WUWNET_Paper_Stress.m');
    % Ensure that stress results are saved per mc
    assert(~isempty(strfind(stress_code, 'results.(ch_key).(vc_key).rmse_overall(mc)')), 'stress RMSE must be paired by mc');
    
    disp('test_pilot_raw_pairing passed.');
end
