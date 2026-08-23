function stats = compute_paper2_ber_statistics(trial_errors, bits_per_trial)
% COMPUTE_PAPER2_BER_STATISTICS Computes comprehensive BER statistics
% Inputs:
%   trial_errors   : 1xN array of bit errors per trial. NaN indicates sync failure.
%   bits_per_trial : Integer, number of data bits in a single trial.
% Outputs:
%   stats          : Struct containing total_errors, total_bits, BER, Wilson CI,
%                    valid_trials, sync_fail_rate, frame_error_rate.

    total_trials = length(trial_errors);
    valid_mask = ~isnan(trial_errors);
    valid_trials = sum(valid_mask);
    
    sync_fail_rate = 1 - (valid_trials / total_trials);
    
    if valid_trials == 0
        stats.total_errors = NaN;
        stats.total_bits = 0;
        stats.ber = NaN;
        stats.wilson_ci = [NaN, NaN];
        stats.valid_trials = 0;
        stats.sync_fail_rate = 1;
        stats.frame_error_rate = 1;
        return;
    end
    
    valid_errors = trial_errors(valid_mask);
    
    stats.valid_trials = valid_trials;
    stats.sync_fail_rate = sync_fail_rate;
    
    stats.total_errors = sum(valid_errors);
    stats.total_bits = valid_trials * bits_per_trial;
    stats.ber = stats.total_errors / stats.total_bits;
    
    % Frame Error Rate (FER): percentage of valid trials with > 0 errors
    stats.frame_error_rate = sum(valid_errors > 0) / valid_trials;
    
    % Wilson Score Confidence Interval (95%)
    z = 1.96; % 95% confidence
    n = stats.total_bits;
    p = stats.ber;
    
    denominator = 1 + z^2/n;
    center_adj = p + z^2/(2*n);
    margin = z * sqrt( (p*(1-p))/n + z^2/(4*n^2) );
    
    lower_bound = (center_adj - margin) / denominator;
    upper_bound = (center_adj + margin) / denominator;
    
    stats.wilson_ci = [max(0, lower_bound), min(1, upper_bound)];
end
