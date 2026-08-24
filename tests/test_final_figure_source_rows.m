function test_final_figure_source_rows()
    f1 = readtable(fullfile('results', 'paper_figures', 'Fig1_FER_vs_SNR_source.csv'));
    assert(height(f1) == 63, 'Fig1 must have 63 source rows');
    
    f2 = readtable(fullfile('results', 'paper_figures', 'Fig2_BER_vs_SNR_source.csv'));
    assert(height(f2) == 63, 'Fig2 must have 63 source rows');
    
    f3 = readtable(fullfile('results', 'paper_figures', 'Fig3_Dynamic_RMSE_source.csv'));
    assert(height(f3) == 9, 'Fig3 must have 9 source rows');
    
    f4 = readtable(fullfile('results', 'paper_figures', 'Fig4_Reliability_Mechanism_source.csv'));
    assert(height(f4) == 3, 'Fig4 must have 3 source rows');
    
    f5 = readtable(fullfile('results', 'paper_figures', 'Fig5_Paired_Fade_Effect_source.csv'));
    assert(height(f5) == 6, 'Fig5 must have 6 source rows');
    
    % Check for NaN in numeric columns
    assert(all(~isnan(f1.FER_Overall)), 'FER cannot be NaN');
    assert(all(~isnan(f3.Overall_RMSE_Median)), 'Overall RMSE cannot be NaN');
    assert(all(~isnan(f5.Median_Difference)), 'Paired Difference cannot be NaN');
    
    disp('test_final_figure_source_rows passed.');
end
