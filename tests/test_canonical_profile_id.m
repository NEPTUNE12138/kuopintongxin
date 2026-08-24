function test_canonical_profile_id()
    % TEST_CANONICAL_PROFILE_ID Tests canonical profile ID mapping
    
    % Compact
    assert(strcmp(canonical_profile_id('P1'), 'P1'));
    assert(strcmp(canonical_profile_id('P2'), 'P2'));
    assert(strcmp(canonical_profile_id('P3'), 'P3'));
    
    % Verbose
    assert(strcmp(canonical_profile_id('Profile P1: Tx15m / 20km / Rx34m'), 'P1'));
    assert(strcmp(canonical_profile_id('Profile P2: Tx15m / 20km / Rx3467m'), 'P2'));
    assert(strcmp(canonical_profile_id('Profile P3: Tx100m / 45km / Rx110m'), 'P3'));
    
    % Error cases
    bad_strings = {'Unknown', 'P10', 'XP1X', 'Profile P4', 'Profile P1: Tx15m / 20km / Rx34m extra'};
    for i = 1:length(bad_strings)
        try
            canonical_profile_id(bad_strings{i});
            error('Should have thrown an error for %s', bad_strings{i});
        catch ME
            assert(strcmp(ME.identifier, 'canonical_profile_id:UnknownProfile'));
        end
    end
    
    disp('test_canonical_profile_id passed.');
end
