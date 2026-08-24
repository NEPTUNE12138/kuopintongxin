function test_final_summary_recompute()
    T_trk = readtable(fullfile('results', 'paper_review', 'final_tracking_table.csv'));
    stress_file = fullfile('results', 'paper', 'paper2_stress_pilot_3000mc.mat');
    D_stress = load(stress_file);
    
    for r = 1:height(T_trk)
        ch_key = sprintf('CH%d', str2double(T_trk.ProfileID{r}(2)));
        if strcmp(T_trk.Variant{r}, 'IAE')
            vc = 'A';
        else
            vc = strrep(T_trk.Variant{r}, '-', '_');
        end
        res = D_stress.results.(ch_key).(vc);
        val_recomp = median(res.rmse_overall(res.valid), 'omitnan');
        
        assert(abs(val_recomp - T_trk.Overall_RMSE_Median(r)) < 1e-4, 'Recompute mismatch for %s %s', T_trk.ProfileID{r}, T_trk.Variant{r});
    end
    disp('test_final_summary_recompute passed.');
end
