function preamble_analytic = generate_hfm_preamble(cfg)
% GENERATE_HFM_PREAMBLE Generates a true Hyperbolic Frequency Modulated (HFM) 
% preamble in the analytic passband domain.
    
    fs = cfg.fs;
    T = cfg.preamble_duration;
    f0 = cfg.preamble_band(1);
    f1 = cfg.preamble_band(2);
    
    t = 0:1/fs:T-1/fs;
    
    % True HFM phase formula
    % instantaneous frequency f(t) = f0 * f1 * T / (f0 * T + (f1 - f0) * t)
    % phase(t) = 2*pi * integral_0^t f(tau) d tau
    %          = 2*pi * (f0*f1*T / (f1 - f0)) * log(1 + (f1 - f0)*t / (f0*T))
    
    phi = 2 * pi * (f0 * f1 * T / (f1 - f0)) * log(1 + (f1 - f0) * t / (f0 * T));
    
    preamble_real = cos(phi);
    
    % Convert to analytic passband representation
    preamble_analytic = hilbert(preamble_real);
    
    % Do not normalize energy here so it matches the unit amplitude of the DSSS payload.
end
