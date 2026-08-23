function test_pilot_no_parameter_mutation()
% TEST_PILOT_NO_PARAMETER_MUTATION Snapshot frozen config before and after, verify unchanged.
    cfg1 = paper2_config('pilot');
    cfg2 = paper2_config('pilot');
    
    % In MATLAB, calling the same function twice without side effects should return identical struct
    assert(isequal(cfg1, cfg2), 'paper2_config mutated state or relies on uninitialized globals');
    
    disp('test_pilot_no_parameter_mutation passed.');
end
