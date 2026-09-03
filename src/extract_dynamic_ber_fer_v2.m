function extract_dynamic_ber_fer()
    mat_file = fullfile('results', 'paper', 'paper2_stress_pilot_3000mc.mat');
    out_dir = fullfile('results', 'paper_strengthening_v2');
    if ~exist(out_dir, 'dir'), mkdir(out_dir); end
    
    fprintf('Loading MAT file: %s\n', mat_file);
    data = load(mat_file);
    
    % variants to extract: IAE (A), VB-FQ (VB_FQ), E-FQ (E_FQ)
    variants = {'A', 'VB_FQ', 'E_FQ'};
    labels = {'IAE', 'VB-FQ', 'E-FQ'};
    num_channels = 3;
    
    out_Variant = {};
    out_Profile = {};
    out_BER_Valid = [];
    out_FER_Overall = [];
    out_ReceiverFailRate = [];
    out_CI95_Lower = [];
    out_CI95_Upper = [];
    
    for v = 1:length(variants)
        vc = variants{v};
        lbl = labels{v};
        
        for ch = 1:num_channels
            ch_key = sprintf('CH%d', ch);
            
            raw_err = data.results.(ch_key).(vc).raw_errors;
            valid = data.results.(ch_key).(vc).valid;
            
            % Compute fail rate
            fail_rate = sum(~valid) / length(valid);
            
            % Compute overall FER (including sync fails as frame errors)
            num_data_bits = data.cfg.num_data_bits;
            fer_trials = raw_err(valid) > 0;
            total_frames = length(valid);
            failed_frames = sum(~valid) + sum(fer_trials);
            fer_overall = failed_frames / total_frames;
            
            % Compute BER_Valid
            valid_errs = raw_err(valid);
            if ~isempty(valid_errs)
                ber_valid = sum(valid_errs) / (length(valid_errs) * num_data_bits);
            else
                ber_valid = NaN;
            end
            
            % Compute 95% CI for FER Overall via bootstrap
            % Frame error vector: 1 if error/fail, 0 if success
            frame_err_vec = ones(total_frames, 1);
            valid_idx = find(valid);
            frame_err_vec(valid_idx(raw_err(valid) == 0)) = 0;
            
            boot_fer = bootstrp(1000, @mean, frame_err_vec);
            ci = prctile(boot_fer, [2.5, 97.5]);
            
            out_Variant{end+1} = lbl;
            out_Profile{end+1} = sprintf('P%d', ch);
            out_BER_Valid(end+1) = ber_valid;
            out_FER_Overall(end+1) = fer_overall;
            out_ReceiverFailRate(end+1) = fail_rate;
            out_CI95_Lower(end+1) = ci(1);
            out_CI95_Upper(end+1) = ci(2);
        end
    end
    
    T = table(out_Variant', out_Profile', out_BER_Valid', out_FER_Overall', out_ReceiverFailRate', out_CI95_Lower', out_CI95_Upper', ...
        'VariableNames', {'Variant', 'Profile', 'BER_Valid', 'FER_Overall', 'ReceiverFailRate', 'FER_CI95_Lower', 'FER_CI95_Upper'});
        
    out_file = fullfile(out_dir, 'DynamicStress_Communication_15dB.csv');
    writetable(T, out_file);
    fprintf('Exported to %s\n', out_file);
end
