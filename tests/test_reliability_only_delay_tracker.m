function test_reliability_only_delay_tracker()
% TEST_RELIABILITY_ONLY_DELAY_TRACKER Definition and telemetry regression.

    state_prev = [0; 0];
    P_prev = eye(2);
    R0 = 0.05;
    c2 = 1/50;

    [state_hi, tel_hi] = reliability_only_delay_tracker(0.4, 1.0, state_prev, P_prev, R0, c2);
    [state_lo, tel_lo] = reliability_only_delay_tracker(0.4, 0.1, state_prev, P_prev, R0, c2);

    assert(isequal(size(state_hi), [2, 1]), 'State must be [delay; delay_rate].');
    assert(abs(tel_hi.R_eff - R0) < 1e-12, 'm=1 must give R_eff=R0.');
    assert(tel_lo.R_eff > tel_hi.R_eff, 'Low reliability must increase R_eff.');
    assert(tel_lo.K_delay < tel_hi.K_delay, 'Low reliability must reduce delay gain.');
    assert(abs(tel_lo.R_eff - R0*(1+c2)/(0.1^2+c2)) < 1e-12, 'Reliability law mismatch.');
    assert(all(abs(tel_hi.Q_diag - [0.05; 0.002]) < 1e-12), 'Q must remain frozen.');

    required = {'delay_est', 'K_delay', 'R_eff', 'm_k'};
    for k = 1:numel(required)
        assert(isfield(tel_hi, required{k}), 'Missing telemetry field: %s', required{k});
    end

    disp('test_reliability_only_delay_tracker passed.');
end
