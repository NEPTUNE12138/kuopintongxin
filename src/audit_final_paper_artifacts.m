function audit_final_paper_artifacts()
% AUDIT_FINAL_PAPER_ARTIFACTS Asserts raw integrity of final MAT files.

    out_file = fullfile('results', 'paper_review', 'final_data_integrity_report.txt');
    
    % 1. Load MATs
    ber_file = fullfile('results', 'paper', 'paper2_ber_validation_3000mc.mat');
    stress_file = fullfile('results', 'paper', 'paper2_stress_pilot_3000mc.mat');
    
    assert(exist(ber_file, 'file') > 0, 'BER MAT missing');
    assert(exist(stress_file, 'file') > 0, 'Stress MAT missing');
    
    D_ber = load(ber_file);
    D_stress = load(stress_file);
    
    % --- BER SHAPE ---
    assert(isequal(size(D_ber.raw_errors), [3, 7, 3, 3000]), 'BER raw_errors dim mismatch');
    assert(isequal(D_ber.cfg.snr_range, -16:-10), 'BER SNR grid mismatch');
    assert(length(D_ber.variants) == 3, 'BER variants mismatch');
    
    ber_shape_pass = true;
    
    % --- STRESS SHAPE ---
    stress_shape_pass = true;
    mech_pass = true;
    
    for ch = 1:3
        ch_key = sprintf('CH%d', ch);
        for v = 1:3
            vc = strrep(D_ber.variants{v}, '-', '_');
            res = D_stress.results.(ch_key).(vc);
            
            if length(res.valid) ~= 3000
                stress_shape_pass = false;
            end
            if length(res.rmse_overall) ~= 3000
                stress_shape_pass = false;
            end
            
            if strcmp(vc, 'E_FQ')
                valid = res.valid;
                % check telemetry on valid
                if any(isnan(res.m_pre(valid))), mech_pass = false; end
                if any(isnan(res.m_fade(valid))), mech_pass = false; end
                if any(isnan(res.m_post(valid))), mech_pass = false; end
                
                if any(isnan(res.mean_Reff_Rvb_pre(valid))), mech_pass = false; end
                if any(isnan(res.mean_Reff_Rvb_fade(valid))), mech_pass = false; end
                if any(isnan(res.mean_Reff_Rvb_post(valid))), mech_pass = false; end
                
                if any(isnan(res.mean_K_pre(valid))), mech_pass = false; end
                if any(isnan(res.mean_K_fade(valid))), mech_pass = false; end
                if any(isnan(res.mean_K_post(valid))), mech_pass = false; end
                
                if any(isnan(res.Q11_pre(valid))), mech_pass = false; end
                if any(isnan(res.Q11_fade(valid))), mech_pass = false; end
                if any(isnan(res.Q11_post(valid))), mech_pass = false; end
                
                if any(isnan(res.Q22_pre(valid))), mech_pass = false; end
                if any(isnan(res.Q22_fade(valid))), mech_pass = false; end
                if any(isnan(res.Q22_post(valid))), mech_pass = false; end
            end
        end
    end
    
    % --- RECOMPUTE PASS ---
    recompute_pass = true;
    for ch = 1:3
        ch_key = sprintf('CH%d', ch);
        for v = 1:3
            vc = strrep(D_ber.variants{v}, '-', '_');
            res = D_stress.results.(ch_key).(vc);
            valid = res.valid;
            
            rm_o = median(res.rmse_overall(valid), 'omitnan');
            if isnan(rm_o) || rm_o <= 0
                recompute_pass = false;
            end
        end
    end
    
    % --- CHECKPOINT COUNT ---
    chk_dir = fullfile('results', 'paper', 'checkpoints');
    d_ber_chk = dir(fullfile(chk_dir, 'chk_ber_*.mat'));
    d_stress_chk = dir(fullfile(chk_dir, 'chk_stress_*.mat'));
    
    chk_pass = true;
    if length(d_ber_chk) ~= 21
        chk_pass = false;
    end
    if length(d_stress_chk) ~= 3
        chk_pass = false;
    end
    
    % Save report
    fid = fopen(out_file, 'w');
    if ber_shape_pass
        fprintf(fid, 'BER_SHAPE_PASS\n');
    else
        fprintf(fid, 'BER_SHAPE_FAIL\n');
    end
    
    if stress_shape_pass
        fprintf(fid, 'STRESS_SHAPE_PASS\n');
    else
        fprintf(fid, 'STRESS_SHAPE_FAIL\n');
    end
    
    if recompute_pass
        fprintf(fid, 'SUMMARY_RECOMPUTE_PASS\n');
    else
        fprintf(fid, 'SUMMARY_RECOMPUTE_FAIL\n');
    end
    
    if mech_pass
        fprintf(fid, 'MECHANISM_COMPLETENESS_PASS\n');
    else
        fprintf(fid, 'MECHANISM_COMPLETENESS_FAIL\n');
    end
    
    if chk_pass
        fprintf(fid, 'CHECKPOINT_COUNT_PASS\n');
    else
        fprintf(fid, 'CHECKPOINT_COUNT_FAIL\n');
    end
    fclose(fid);
    
    disp('Audit complete.');
end
