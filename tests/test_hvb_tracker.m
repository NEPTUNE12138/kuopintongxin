% test_hvb_tracker.m
addpath('../lib');
addpath('../config');

cfg = paper2_config('quick');
cfg.symbol_dur = 1; % Normalised
z_k = 0.1;
u_k = 1;
u_prev = 1;
x_prev = [0; 0];
P_prev = eye(2);
alpha_prev = 2;
beta_prev = 0.1;
Q_prev = [1e-4, 0; 0, 1e-4];

% 1. High reliability (m_k = 1)
[x1, P1, a1, b1, Q1, meta1] = hvb_akf_delay_tracker(z_k, u_k, u_prev, x_prev, P_prev, alpha_prev, beta_prev, Q_prev, cfg);

% 2. Low reliability (m_k = 0.1)
u_k_low = 0.1;
[x2, P2, a2, b2, Q2, meta2] = hvb_akf_delay_tracker(z_k, u_k_low, u_prev, x_prev, P_prev, alpha_prev, beta_prev, Q_prev, cfg);

assert(meta1.Lambda_k < meta2.Lambda_k, 'Error: Lambda should increase in deep fade');
assert(meta2.R_eff > meta2.R_vb, 'Error: R_eff should be > R_vb in deep fade');
assert(abs(meta1.K_gain(1)) > abs(meta2.K_gain(1)), 'Error: Kalman gain should decrease in deep fade');

% 3. Check Q is diagonal
assert(Q1(1,2) == 0 && Q1(2,1) == 0, 'Error: Q matrix has non-zero off-diagonal elements');

% 4. No NaN/Inf
assert(~any(isnan(x1)) && ~any(isinf(x1)), 'Error: Output contains NaN/Inf');

fprintf('test_hvb_tracker: Passed.\n');
