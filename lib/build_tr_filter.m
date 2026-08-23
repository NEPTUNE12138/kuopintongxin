function [q_filter, trm_group_delay, is_valid] = build_tr_filter(h_ext)
% BUILD_TR_FILTER Constructs normalized Time-Reversal filter.

    q_filter = conj(fliplr(h_ext));
    n_q = norm(q_filter);
    
    if n_q < 1e-12
        is_valid = false;
        q_filter = 1; % Fallback
        trm_group_delay = 0;
    else
        is_valid = true;
        q_filter = q_filter / n_q;
        trm_group_delay = length(q_filter) - 1;
    end
end
