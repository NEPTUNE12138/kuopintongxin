function p_id = canonical_profile_id(raw_str)
% CANONICAL_PROFILE_ID Standardizes verbose profile strings to P1, P2, P3

    if ~ischar(raw_str) && ~isstring(raw_str)
        error('canonical_profile_id:InvalidInput', 'Input must be a string');
    end
    
    raw_str = char(raw_str);
    
    if strcmp(raw_str, 'P1') || strcmp(raw_str, 'Profile P1: Tx15m / 20km / Rx34m')
        p_id = 'P1';
    elseif strcmp(raw_str, 'P2') || strcmp(raw_str, 'Profile P2: Tx15m / 20km / Rx3467m')
        p_id = 'P2';
    elseif strcmp(raw_str, 'P3') || strcmp(raw_str, 'Profile P3: Tx100m / 45km / Rx110m')
        p_id = 'P3';
    else
        error('canonical_profile_id:UnknownProfile', 'Unknown profile string: %s', raw_str);
    end
end
