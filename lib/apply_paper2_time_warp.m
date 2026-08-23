function [sig_warp, warp_meta] = apply_paper2_time_warp(sig_in, cfg, warp_cfg)
% APPLY_PAPER2_TIME_WARP Applies physical time-warping based on acoustic velocity.
% Inputs:
%   sig_in   : Input baseband or passband signal
%   cfg      : Main paper configuration struct (needs cfg.fs)
%   warp_cfg : Struct with velocity parameters:
%              - v0_mps           : Mean velocity (m/s)
%              - velocity_amp_mps : Velocity oscillation amplitude (m/s)
%              - velocity_freq_hz : Velocity oscillation frequency (Hz)
%              - phase_rad        : Initial phase of oscillation (rad)
% Outputs:
%   sig_warp : Warped signal (same length as sig_in)
%   warp_meta: Struct with true time grids and epsilon_true_samples.

    if nargin < 3 || isempty(warp_cfg)
        warp_cfg.v0_mps = 0.5;
        warp_cfg.velocity_amp_mps = 1.5;
        warp_cfg.velocity_freq_hz = 0.2;
        warp_cfg.phase_rad = 0;
    end
    
    c_sound = 1500; % nominal speed of sound (m/s)
    
    N = length(sig_in);
    t = (0 : N - 1) / cfg.fs;
    
    v = warp_cfg.v0_mps + warp_cfg.velocity_amp_mps * sin(2 * pi * warp_cfg.velocity_freq_hz * t + warp_cfg.phase_rad);
    
    alpha = 1 + v / c_sound;
    t_src = cumtrapz(t, alpha);
    t_src = t_src - t_src(1); % Ensure t_src starts exactly at 0
    
    % Interpolate to get warped signal
    sig_warp = interp1(t, sig_in, t_src, 'linear', 0);
    
    % True absolute delay in samples:
    % Physical delay is epsilon(t) = t - t_src(t)
    epsilon_true_samples = (t - t_src) * cfg.fs;
    
    warp_meta.t = t;
    warp_meta.velocity_mps = v;
    warp_meta.alpha = alpha;
    warp_meta.t_src = t_src;
    warp_meta.epsilon_true_samples = epsilon_true_samples;
end
