function [x_post, P_post, alpha_out, beta_out, Q_out, meta] = hvb_akf_delay_tracker(z_k, u_k, u_prev, x_prev, P_prev, alpha_prev, beta_prev, Q_prev, cfg)
% HVB_AKF_DELAY_TRACKER Heteroscedastic Variational Bayesian Adaptive Kalman Filter for DLL tracking
% 
% State vector: x = [epsilon; epsilon_dot] (code delay offset; drift rate)

    % 1. State Prediction
    Tu = cfg.symbol_dur;
    F = [1, Tu; 0, 1];
    H = [1, 0];
    
    x_pred = F * x_prev;
    P_pred = F * P_prev * F' + Q_prev;
    
    % 2. Reliability Metric
    c2 = cfg.c2;
    m_k = abs(u_k * conj(u_prev));
    Lambda_k = (1 + c2) / (m_k^2 + c2);
    
    % Clipping Lambda_k if needed to prevent numerical explosion
    Lambda_k = min(Lambda_k, 1e6);
    
    % 3. VB Prior Hyperparameters
    rho_R = cfg.vb_forgetting_factor;
    alpha0 = rho_R * alpha_prev;
    beta0  = rho_R * beta_prev;
    
    % Initialize posterior as prediction for inner loop
    x_post = x_pred;
    P_post = P_pred;
    
    % 4. Inner VB Iterations
    N_vb = cfg.N_vb;
    
    for iter = 1:N_vb
        % Expected residual energy
        % z_k is scalar, H is 1x2
        res = z_k - H * x_post;
        Eres = res^2 + H * P_post * H';
        
        % Update alpha and beta
        alpha = alpha0 + 0.5;
        beta  = beta0 + 0.5 * Eres;
        
        % Precision-matched effective covariance
        R_vb = beta / max(alpha, eps);
        
        % Heteroscedastic penalty ONLY for Kalman gain
        R_eff = R_vb * Lambda_k;
        
        % Measurement update from SAME PREDICTION (x_pred, P_pred)
        S = H * P_pred * H' + R_eff;
        K_gain = P_pred * H' / max(S, eps);
        
        x_post = x_pred + K_gain * (z_k - H * x_pred);
        P_post = (eye(2) - K_gain * H) * P_pred;
    end
    
    % 5. Q Adaptation (Structural Regularization)
    Q_out = Q_prev;
    if Lambda_k <= cfg.Lambda_freeze
        % Innovation based Q update
        innovation = z_k - H * x_pred;
        % Simple diagonal update
        C_k = innovation^2;
        Q_est_full = K_gain * C_k * K_gain';
        
        % Structural Regularization (diag)
        Q_est_diag = diag(diag(Q_est_full));
        
        rho_Q = 0.9;
        Q_min = 1e-6;
        Q_out(1,1) = max(Q_min, rho_Q * Q_prev(1,1) + (1 - rho_Q) * Q_est_diag(1,1));
        Q_out(2,2) = max(Q_min, rho_Q * Q_prev(2,2) + (1 - rho_Q) * Q_est_diag(2,2));
    end
    
    % 6. Outputs
    alpha_out = alpha;
    beta_out = beta;
    
    meta.R_vb = R_vb;
    meta.R_eff = R_eff;
    meta.K_gain = K_gain;
    meta.m_k = m_k;
    meta.Lambda_k = Lambda_k;
    meta.Q_diag = diag(Q_out);
    meta.Eres = Eres;
end
