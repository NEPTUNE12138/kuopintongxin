# VB Probabilistic Model / Code Audit V2

## Reference
Särkkä and Nummenmaa, "Recursive Noise Adaptive Kalman Filtering by Variational Bayesian Approximations," *IEEE Transactions on Automatic Control*, 2009.

## Audit Checklist
The implemented scalar VB recursion in `lib/hvb_akf_delay_tracker.m` was audited line-by-line against the theoretical framework.

1. **Factorization**: The code correctly implicitly implements the mean-field approximation $q(x_k, R_k) \approx q_x(x_k) q_R(R_k)$ via the alternating fixed-point loop (lines 26-41).
2. **State Distribution ($q_x$)**: Maintained as a Gaussian $\mathcal{N}(x_k \mid x_{post}, P_{post})$ via the standard Kalman measurement update within the loop.
3. **Variance Distribution ($q_R$)**: Parameterized as an Inverse-Gamma distribution using shape $\alpha$ and scale $\beta$. 
4. **Expected Precision**: The theory states the expected precision is $E[1/R_k] = \alpha_k / \beta_k$. The implemented code correctly inverses this expectation to define the effective VB measurement variance:
   ```matlab
   R_vb = beta / alpha;
   ```
   *Note: This is strictly the reciprocal expected precision, not the true posterior mean variance of the Inverse-Gamma distribution (which would be $\beta_k / (\alpha_k - 1)$). The code does not erroneously claim it is the posterior mean variance.*
5. **Forgetting Rule**: The exponential forgetting is correctly implemented (lines 19-20):
   ```matlab
   alpha0 = 0.95 * alpha_prev;
   beta0 = 0.95 * beta_prev;
   ```
   (where $\rho = 0.95$).
6. **Posterior Second Moment**: The expected residual sum of squares is correctly calculated using both the point estimate residual and the state uncertainty:
   ```matlab
   Eres = res^2 + H * P_post * H';
   ```

## Manuscript-Ready Paragraph (VB Probabilistic Model)
To dynamically track the time-varying measurement noise variance $R_k$, we employ a Variational Bayesian (VB) approximation that iteratively estimates the joint posterior of the tracking state $x_k$ and the noise variance $R_k$. Following the mean-field approximation, the posterior is factorized as $p(x_k, R_k \mid Z_k) \approx q_x(x_k)q_R(R_k)$, where $q_x(\cdot)$ is Gaussian and $q_R(\cdot)$ is Inverse-Gamma parameterized by shape $\alpha_k$ and scale $\beta_k$. To prevent the variance estimate from becoming overly rigid over time, a heuristic exponential forgetting factor $\rho \in (0, 1]$ is applied to the prior hyperparameters, yielding the temporal updates $\alpha_k^- = \rho \alpha_{k-1}$ and $\beta_k^- = \rho \beta_{k-1}$. During each tracking step, the filter alternates between updating the state posterior moments via standard Kalman equations and refining the variance posterior using the expected second moment of the measurement residual. The reciprocal of the expected precision, given by $R_{VB} = \beta_k / \alpha_k$, subsequently serves as the effective measurement variance in the state update.
