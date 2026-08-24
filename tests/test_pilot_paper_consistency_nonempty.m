function test_pilot_paper_consistency_nonempty()
    T_cons = readtable(fullfile('results', 'paper_review', 'pilot_paper_consistency.csv'));
    
    assert(height(T_cons) == 72, 'Consistency table must have exactly 72 data rows');
    
    % Check threshold movements
    idx_p2_efq_snr50 = find(strcmp(T_cons.ProfileID, 'P2') & strcmp(T_cons.Variant_or_Comparison, 'E-FQ') & strcmp(T_cons.Metric, 'SNR50'));
    assert(T_cons.PilotValue(idx_p2_efq_snr50) == -13, 'P2 E-FQ Pilot SNR50 must be -13');
    assert(T_cons.PaperValue(idx_p2_efq_snr50) == -12, 'P2 E-FQ Paper SNR50 must be -12');
    
    idx_p3_iae_snr05 = find(strcmp(T_cons.ProfileID, 'P3') & strcmp(T_cons.Variant_or_Comparison, 'IAE') & strcmp(T_cons.Metric, 'SNR05'));
    assert(T_cons.PilotValue(idx_p3_iae_snr05) == -13, 'P3 IAE Pilot SNR05 must be -13');
    assert(T_cons.PaperValue(idx_p3_iae_snr05) == -12, 'P3 IAE Paper SNR05 must be -12');
    
    disp('test_pilot_paper_consistency_nonempty passed.');
end
