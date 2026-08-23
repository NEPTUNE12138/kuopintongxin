function [pass, status, details] = evaluate_mechanism_gate(res, expected_Q)
% EVALUATE_MECHANISM_GATE Encapsulates the FAIL-CLOSED PAPER-4/PILOT-4 logic
% Inputs:
%   res - scalar struct containing median telemetry fields:
%         .m_pre, .m_fade, .m_post
%         .mean_Reff_Rvb_pre, .mean_Reff_Rvb_fade, .mean_Reff_Rvb_post
%         .mean_K_pre, .mean_K_fade, .mean_K_post
%         .Q11_fade, .Q22_fade (or pre/post)
%   expected_Q - 1x2 array [Q11, Q22] (default: [0.05, 0.002])
% Outputs:
%   pass - boolean
%   status - string summarizing failure reason or 'PASS'
%   details - string with detailed numerical values for debugging

    if nargin < 2
        expected_Q = [0.05, 0.002];
    end
    
    pass = true;
    status = 'PASS';
    details = '';
    
    if isfield(res, 'valid')
        valid = res.valid;
    else
        valid = true(size(res.m_fade)); % fallback if not provided
    end
    
    % Safely extract fields
    m_m_f = NaN; if isfield(res, 'm_fade'), m_m_f = median(res.m_fade(valid), 'omitnan'); end
    m_m_p = NaN; if isfield(res, 'm_pre'), m_m_p = median(res.m_pre(valid), 'omitnan'); end
    m_rr_f = NaN; if isfield(res, 'mean_Reff_Rvb_fade'), m_rr_f = median(res.mean_Reff_Rvb_fade(valid), 'omitnan'); end
    m_rr_p = NaN; if isfield(res, 'mean_Reff_Rvb_pre'), m_rr_p = median(res.mean_Reff_Rvb_pre(valid), 'omitnan'); end
    m_k_f = NaN; if isfield(res, 'mean_K_fade'), m_k_f = median(res.mean_K_fade(valid), 'omitnan'); end
    m_k_p = NaN; if isfield(res, 'mean_K_pre'), m_k_p = median(res.mean_K_pre(valid), 'omitnan'); end
    m_q11 = NaN; if isfield(res, 'Q11_fade'), m_q11 = median(res.Q11_fade(valid), 'omitnan'); end
    m_q22 = NaN; if isfield(res, 'Q22_fade'), m_q22 = median(res.Q22_fade(valid), 'omitnan'); end

    required = [m_m_p, m_m_f, m_rr_p, m_rr_f, m_k_p, m_k_f, m_q11, m_q22];
    
    details = sprintf('m: PRE=%.4f, FADE=%.4f | R_eff/R_vb: PRE=%.4f, FADE=%.4f | K: PRE=%.4f, FADE=%.4f | Q11=%.4f, Q22=%.4f', ...
        m_m_p, m_m_f, m_rr_p, m_rr_f, m_k_p, m_k_f, m_q11, m_q22);
    
    if any(~isfinite(required))
        pass = false;
        status = 'PILOT4_MISSING_TELEMETRY';
        return;
    end
    
    if ~(m_m_f < m_m_p)
        pass = false;
        status = 'PILOT4_FAIL_M_RELIABILITY';
    elseif ~(m_rr_f > m_rr_p)
        pass = false;
        status = 'PILOT4_FAIL_REFF_RVB';
    elseif ~(m_k_f < m_k_p)
        pass = false;
        status = 'PILOT4_FAIL_K_GAIN';
    elseif abs(m_q11 - expected_Q(1)) > 1e-6
        pass = false;
        status = 'PILOT4_FAIL_Q11_NOT_FROZEN';
    elseif abs(m_q22 - expected_Q(2)) > 1e-6
        pass = false;
        status = 'PILOT4_FAIL_Q22_NOT_FROZEN';
    end
end
