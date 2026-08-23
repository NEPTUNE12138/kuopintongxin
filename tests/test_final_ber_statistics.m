function test_final_ber_statistics()
    fprintf('Running test_final_ber_statistics...\n');
    
    % 1. All successful, zero errors
    total_bits = 100;
    valid_flags = [true, true, true];
    bit_errors = [0, 0, 0];
    
    s = compute_paper2_ber_statistics(bit_errors, valid_flags, total_bits);
    assert(s.Trials_Valid == 3);
    assert(s.SyncFailCount == 0);
    assert(s.SyncFailRate == 0);
    assert(s.BER_Valid == 0);
    assert(s.FER_Valid == 0);
    assert(s.FER_Overall == 0);
    
    % 2. Successful with bit errors
    valid_flags = [true, true, true];
    bit_errors = [0, 5, 10];
    s = compute_paper2_ber_statistics(bit_errors, valid_flags, total_bits);
    assert(s.Trials_Valid == 3);
    assert(s.SyncFailRate == 0);
    assert(s.BER_Valid == 15 / 300);
    assert(s.FER_Valid == 2/3);
    assert(s.FER_Overall == 2/3);
    
    % 3. Mixed sync failures
    valid_flags = [true, false, true, false];
    bit_errors = [10, NaN, 0, NaN];
    s = compute_paper2_ber_statistics(bit_errors, valid_flags, total_bits);
    assert(s.Trials_Total == 4);
    assert(s.Trials_Valid == 2);
    assert(s.SyncFailCount == 2);
    assert(s.SyncFailRate == 0.5);
    assert(s.BER_Valid == 10 / 200);
    assert(s.FER_Valid == 0.5);
    % Overall FER = (2 sync fails + 1 frame error) / 4 = 0.75
    assert(s.FER_Overall == 0.75);
    
    % 4. All sync failures
    valid_flags = [false, false];
    bit_errors = [NaN, NaN];
    s = compute_paper2_ber_statistics(bit_errors, valid_flags, total_bits);
    assert(s.Trials_Valid == 0);
    assert(s.SyncFailRate == 1.0);
    assert(isnan(s.BER_Valid));
    assert(isnan(s.FER_Valid));
    assert(s.FER_Overall == 1.0);
    
    fprintf('test_final_ber_statistics passed.\n');
end
