function stats = compute_paper2_ber_statistics(bit_errors, valid_flags, total_bits_per_trial)
% COMPUTE_PAPER2_BER_STATISTICS Compute unified BER and FER statistics.
%
% Inputs:
%   bit_errors           - [1 x N] vector of bit errors per trial for successfully synchronized trials (NaN for sync failure)
%   valid_flags          - [1 x N] logical vector (true if successfully synchronized)
%   total_bits_per_trial - integer, number of bits per trial (e.g., cfg.num_data_bits)
%
% Outputs:
%   stats - struct containing valid and overall statistics

    N = length(valid_flags);
    
    stats.Trials_Total = N;
    stats.Trials_Valid = sum(valid_flags);
    stats.SyncFailCount = N - stats.Trials_Valid;
    stats.SyncFailRate = stats.SyncFailCount / max(N, 1);
    
    if stats.Trials_Valid > 0
        valid_errors = bit_errors(valid_flags);
        stats.BitErrors_Valid = sum(valid_errors);
        stats.Bits_Valid = stats.Trials_Valid * total_bits_per_trial;
        stats.BER_Valid = stats.BitErrors_Valid / stats.Bits_Valid;
        
        stats.FrameErrors_Valid = sum(valid_errors > 0);
        stats.FER_Valid = stats.FrameErrors_Valid / stats.Trials_Valid;
        
        % Wilson CI for Valid BER
        z = 1.96;
        p = stats.BER_Valid;
        n = stats.Bits_Valid;
        denom = 1 + z^2/n;
        center = (p + z^2/(2*n)) / denom;
        hw = z * sqrt(p*(1-p)/n + z^2/(4*n^2)) / denom;
        stats.Wilson_Lower_ValidBER = max(0, center - hw);
        stats.Wilson_Upper_ValidBER = min(1, center + hw);
    else
        stats.BitErrors_Valid = 0;
        stats.Bits_Valid = 0;
        stats.BER_Valid = NaN;
        
        stats.FrameErrors_Valid = 0;
        stats.FER_Valid = NaN;
        
        stats.Wilson_Lower_ValidBER = NaN;
        stats.Wilson_Upper_ValidBER = NaN;
    end
    
    stats.FrameErrors_Overall = stats.SyncFailCount + (stats.Trials_Valid > 0) * sum(bit_errors(valid_flags) > 0);
    stats.FER_Overall = stats.FrameErrors_Overall / max(N, 1);
end
