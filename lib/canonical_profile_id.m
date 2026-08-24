function p_id = canonical_profile_id(raw_str)
% CANONICAL_PROFILE_ID Standardizes verbose profile strings to P1, P2, P3

    if ~ischar(raw_str) && ~isstring(raw_str)
        error('canonical_profile_id:InvalidInput', 'Input must be a string');
    end
    
    raw_str = char(raw_str);
    
    if contains(raw_str, 'P1')
        p_id = 'P1';
    elseif contains(raw_str, 'P2')
        p_id = 'P2';
    elseif contains(raw_str, 'P3')
        p_id = 'P3';
    else
        error('canonical_profile_id:UnknownProfile', 'Unknown profile string: %s', raw_str);
    end
end
