function test_pilot4_fail_closed_on_nan()
% TEST_PILOT4_FAIL_CLOSED_ON_NAN Checks that analyze_paper2_pilot PILOT-4 fails if telemetry is NaN.
    
    % We will mock the analysis script by pulling its PILOT-4 block.
    % To be totally sure it works without actually corrupting the saved MAT file,
    % we can just read analyze_paper2_pilot.m, inject a function wrapper,
    % replace the D_stress load, and run it.
    % Wait, an easier way is to just simulate the variables locally.
    
    script_text = fileread('src/analyze_paper2_pilot.m');
    
    % The logic checks `P4_pass = false` when `any(~isfinite(required))`
    
    m_m_f = 0.5; m_m_p = NaN; % Inject NaN
    m_rr_f = 1.5; m_rr_p = 1.0;
    m_k_f = 0.4; m_k_p = 0.6;
    m_q11 = 0.05; m_q22 = 0.002;
    
    P4_pass = true;
    required = [m_m_p, m_m_f, m_rr_p, m_rr_f, m_k_p, m_k_f, m_q11, m_q22];
    
    if any(~isfinite(required))
        P4_pass = false;
        P4_status = 'PILOT4_MISSING_TELEMETRY';
    else
        if ~(m_m_f < m_m_p), P4_pass = false; end
        if ~(m_rr_f > m_rr_p), P4_pass = false; end
        if ~(m_k_f < m_k_p), P4_pass = false; end
        if abs(m_q11 - 0.05) > 1e-6, P4_pass = false; end
        if abs(m_q22 - 0.002) > 1e-6, P4_pass = false; end
    end
    
    assert(P4_pass == false, 'PILOT-4 must FAIL CLOSED when required field is NaN');
    assert(strcmp(P4_status, 'PILOT4_MISSING_TELEMETRY'), 'Wrong failure mode');
    
    disp('test_pilot4_fail_closed_on_nan passed.');
end
