function [state, telemetry] = reliability_only_delay_tracker(z_k, m_k, state_prev, P_prev, R0, c2)
% RELIABILITY_ONLY_DELAY_TRACKER Fixed-Q KF with reliability-scaled R.
%   [STATE, TELEMETRY] = RELIABILITY_ONLY_DELAY_TRACKER(Z_K, M_K,
%   STATE_PREV, P_PREV, R0, C2) performs one standard Kalman-filter
%   update for STATE = [delay; delay_rate]. It does not perform VB or
%   covariance matching. The process covariance is frozen at
%   diag([0.05, 0.002]), and the measurement covariance is
%
%       R_eff = R0 * (1 + c2) / (m_k^2 + c2).
%
%   The posterior covariance required by the next recursion is returned
%   in TELEMETRY.P_post.

    validateattributes(z_k, {'numeric'}, {'real', 'finite', 'scalar'});
    validateattributes(m_k, {'numeric'}, {'real', 'finite', 'scalar', '>=', 0, '<=', 1});
    validateattributes(state_prev, {'numeric'}, {'real', 'finite', 'size', [2, 1]});
    validateattributes(P_prev, {'numeric'}, {'real', 'finite', 'size', [2, 2]});
    validateattributes(R0, {'numeric'}, {'real', 'finite', 'scalar', 'positive'});
    validateattributes(c2, {'numeric'}, {'real', 'finite', 'scalar', 'positive'});

    F = [1, 1; 0, 1];
    H = [1, 0];
    Q = diag([0.05, 0.002]);

    state_pred = F * state_prev;
    P_pred = F * P_prev * F' + Q;

    Lambda_k = (1 + c2) / (m_k^2 + c2);
    R_eff = R0 * Lambda_k;
    innovation = z_k - H * state_pred;
    S = H * P_pred * H' + R_eff;
    K = P_pred * H' / max(S, eps);

    state = state_pred + K * innovation;

    % Joseph form preserves symmetry and positive semidefiniteness.
    I_KH = eye(2) - K * H;
    P_post = I_KH * P_pred * I_KH' + K * R_eff * K';
    P_post = (P_post + P_post') / 2;

    telemetry.delay_est = state(1);
    telemetry.K_delay = K(1);
    telemetry.R_eff = R_eff;
    telemetry.m_k = m_k;

    % Recursion and audit fields used by the unified receiver.
    telemetry.P_post = P_post;
    telemetry.K_gain = K;
    telemetry.Lambda_k = Lambda_k;
    telemetry.Q_diag = diag(Q);
    telemetry.innovation = innovation;
    telemetry.S = S;
    telemetry.NIS = innovation^2 / max(S, eps);
    telemetry.P_pred_diag = diag(P_pred);
    telemetry.R0 = R0;
end
