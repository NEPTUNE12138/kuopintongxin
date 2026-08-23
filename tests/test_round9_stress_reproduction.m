function test_round9_stress_reproduction()
% TEST_ROUND9_STRESS_REPRODUCTION Compares old and new Stress runs for exact numerical equality.
    
    pilot_dir = fullfile('results', 'pilot');
    stress_files = dir(fullfile(pilot_dir, 'paper2_stress_pilot_*.mat'));
    
    if length(stress_files) < 2
        fprintf('Need at least 2 stress files to test reproduction. Found %d.\n', length(stress_files));
        return;
    end
    
    [~, idx] = sort([stress_files.datenum], 'ascend');
    old_mat = fullfile(pilot_dir, stress_files(idx(1)).name);
    new_mat = fullfile(pilot_dir, stress_files(idx(end)).name);
    
    fprintf('Comparing %s (OLD) vs %s (NEW)\n', old_mat, new_mat);
    
    D_old = load(old_mat);
    D_new = load(new_mat);
    
    out_dir = fullfile('results', 'pilot_review');
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end
    
    csv_file = fullfile(out_dir, 'pilot_stress_reproduction_check.csv');
    fid = fopen(csv_file, 'w');
    fprintf(fid, 'Profile,Variant,Metric,OldValue,NewValue,AbsDifference,Pass\n');
    
    num_ch = size(D_old.cfg.channels, 1);
    num_v = length(D_old.variants);
    
    all_pass = true;
    tol = 1e-10;
    
    metrics = {'rmse_overall', 'rmse_pre', 'rmse_fade', 'rmse_post'};
    
    for ch = 1:num_ch
        ch_key = sprintf('CH%d', ch);
        ch_name = D_old.cfg.channels{ch, 2};
        
        for v = 1:num_v
            vc_key = strrep(D_old.variants{v}, '-', '_');
            var_name = D_old.csv_labels{v};
            
            res_old = D_old.results.(ch_key).(vc_key);
            res_new = D_new.results.(ch_key).(vc_key);
            
            % Check BER/FER
            stats_old = compute_paper2_ber_statistics(res_old.raw_errors, res_old.valid, D_old.cfg.num_data_bits);
            stats_new = compute_paper2_ber_statistics(res_new.raw_errors, res_new.valid, D_new.cfg.num_data_bits);
            
            diff_ber = abs(stats_old.BER_Valid - stats_new.BER_Valid);
            pass_ber = diff_ber <= tol || (isnan(stats_old.BER_Valid) && isnan(stats_new.BER_Valid));
            fprintf(fid, '%s,%s,BER_Valid,%.6f,%.6f,%.6g,%d\n', ch_name, var_name, stats_old.BER_Valid, stats_new.BER_Valid, diff_ber, pass_ber);
            if ~pass_ber, all_pass = false; end
            
            diff_fer = abs(stats_old.FER_Overall - stats_new.FER_Overall);
            pass_fer = diff_fer <= tol;
            fprintf(fid, '%s,%s,FER_Overall,%.6f,%.6f,%.6g,%d\n', ch_name, var_name, stats_old.FER_Overall, stats_new.FER_Overall, diff_fer, pass_fer);
            if ~pass_fer, all_pass = false; end
            
            for m = 1:length(metrics)
                met = metrics{m};
                val_old = median(res_old.(met)(res_old.valid), 'omitnan');
                val_new = median(res_new.(met)(res_new.valid), 'omitnan');
                
                diff_val = abs(val_old - val_new);
                pass_val = diff_val <= tol || (isnan(val_old) && isnan(val_new));
                
                fprintf(fid, '%s,%s,%s_Median,%.6f,%.6f,%.6g,%d\n', ch_name, var_name, met, val_old, val_new, diff_val, pass_val);
                if ~pass_val, all_pass = false; end
            end
        end
    end
    
    fclose(fid);
    
    if ~all_pass
        error('ROUND9_1_REPRODUCTION_FAILURE\nPAPER_BLOCKED');
    end
    
    disp('test_round9_stress_reproduction passed.');
end
