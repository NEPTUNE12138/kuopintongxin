function [x_post, P_post, alpha_out, beta_out, Q_out, meta] = hvb_akf_delay_tracker(z_k, u_k, u_prev, m_k, x_prev, P_prev, alpha_prev, beta_prev, Q_prev, cfg)
% HVB_AKF_DELAY_TRACKER Heteroscedastic Variational Bayesian Adaptive Kalman Filter
    
    % 1. Predict
    F = [1 1; 0 1];
    H = [1 0];
    x_pred = F * x_prev;
    P_pred = F * P_prev * F' + Q_prev;
    
    % 2. Reliability & Heteroscedastic Penalty
    c2 = cfg.c2;
    Lambda_k = (1 + c2) / (m_k^2 + c2);
    
    % 3. VB Initialization
    alpha0 = 0.95 * alpha_prev;
    beta0 = 0.95 * beta_prev;
    
    x_post = x_pred;
    P_post = P_pred;
    
    % 4. Inner VB Iterations
    for iter = 1:cfg.N_vb
        res = z_k - H * x_post;
        Eres = res^2 + H * P_post * H';
        
        alpha = alpha0 + 0.5;
        beta = beta0 + 0.5 * Eres;
        
        R_vb = beta / alpha;
        R_eff = R_vb * Lambda_k; % Penalty applied only to effective variance
        
        S = H * P_pred * H' + R_eff;
        K_gain = P_pred * H' / max(S, eps);
        
        x_post = x_pred + K_gain * (z_k - H * x_pred);
        P_post = (eye(2) - K_gain * H) * P_pred;
    end
    
    % 5. Q Adaptation (Q-Freeze Mechanism)
    Q_out = Q_prev;
    if m_k >= cfg.q_freeze_reliability
        innovation = z_k - H * x_pred;
        C_k = innovation^2;
        Q_est_full = K_gain * C_k * K_gain';
        Q_est_diag = diag(diag(Q_est_full));
        
        Q_out(1,1) = max(1e-6, 0.9 * Q_prev(1,1) + 0.1 * Q_est_diag(1,1));
        Q_out(2,2) = max(1e-6, 0.9 * Q_prev(2,2) + 0.1 * Q_est_diag(2,2));
    end
    
    % Outputs
    alpha_out = alpha;
    beta_out = beta;
    
    meta.R_vb = R_vb;
    meta.R_eff = R_eff;
    meta.K_gain = K_gain;
    meta.Lambda_k = Lambda_k;
    meta.Q_diag = diag(Q_out);
end
