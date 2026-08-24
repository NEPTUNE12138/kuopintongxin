function test_figure_profile_key_mapping()
    T_ber = readtable(fullfile('results', 'paper_review', 'final_ber_table.csv'));
    T_trk = readtable(fullfile('results', 'paper_review', 'final_tracking_table.csv'));
    
    assert(ismember('ProfileID', T_ber.Properties.VariableNames), 'ProfileID must exist in BER table');
    assert(ismember('ProfileID', T_trk.Properties.VariableNames), 'ProfileID must exist in Tracking table');
    
    p_ids = unique(T_ber.ProfileID);
    assert(length(p_ids) == 3, 'Must have exactly 3 canonical profiles');
    assert(ismember('P1', p_ids) && ismember('P2', p_ids) && ismember('P3', p_ids), 'Must map to P1, P2, P3');
    
    % The verbose descriptions must be preserved
    p_descs = unique(T_ber.ProfileDescription);
    assert(length(p_descs) == 3, 'Must have exactly 3 verbose profiles');
    
    disp('test_figure_profile_key_mapping passed.');
end
