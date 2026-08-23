function test_pilot4_fail_closed_on_nan()
% TEST_PILOT4_FAIL_CLOSED_ON_NAN Checks that analyze_paper2_pilot PILOT-4 fails if telemetry is NaN.
    
    % We will use the evaluate_mechanism_gate helper.
    
    res.m_fade = 0.5; res.m_pre = NaN; % Inject NaN
    res.mean_Reff_Rvb_fade = 1.5; res.mean_Reff_Rvb_pre = 1.0;
    res.mean_K_fade = 0.4; res.mean_K_pre = 0.6;
    res.Q11_fade = 0.05; res.Q22_fade = 0.002;
    
    [P4_pass, P4_status, ~] = evaluate_mechanism_gate(res);
    
    assert(P4_pass == false, 'PILOT-4 must FAIL CLOSED when required field is NaN');
    assert(strcmp(P4_status, 'PILOT4_MISSING_TELEMETRY'), 'Wrong failure mode');
    
    disp('test_pilot4_fail_closed_on_nan passed.');
end
