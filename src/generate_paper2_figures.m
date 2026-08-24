function generate_paper2_figures()
% GENERATE_PAPER2_FIGURES Generates publication figures with exact source row counts

    out_dir = fullfile('results', 'paper_figures');
    if ~exist(out_dir, 'dir')
        mkdir(out_dir);
    end
    
    % Load tables
    T_ber = readtable(fullfile('results', 'paper_review', 'final_ber_table.csv'));
    T_trk = readtable(fullfile('results', 'paper_review', 'final_tracking_table.csv'));
    T_mech = readtable(fullfile('results', 'paper_review', 'final_mechanism_table.csv'));
    T_boot = readtable(fullfile('results', 'paper_review', 'final_bootstrap_table.csv'));
    
    profiles = {'P1', 'P2', 'P3'};
    vars = {'IAE', 'VB-FQ', 'E-FQ'};
    colors = [0, 0.4470, 0.7410; 0.8500, 0.3250, 0.0980; 0.4660, 0.6740, 0.1880];
    styles = {'-o', '-s', '-d'};
    
    audit_fid = fopen(fullfile('results', 'paper_review', 'final_figure_source_audit.txt'), 'w');
    
    % --- Fig1: FER vs SNR ---
    f1 = figure('Name', 'Fig1_FER_vs_SNR', 'Position', [100, 100, 1200, 400]);
    t1_src_cells = cell(0, 7);
    obj_count_1 = 0;
    for p = 1:3
        subplot(1, 3, p); hold on; grid on;
        for v = 1:3
            % use canonical profile matching
            idx = find(strcmp(T_ber.ProfileID, profiles{p}) & strcmp(T_ber.Variant, vars{v}));
            snr = T_ber.SNR_dB(idx);
            fer = T_ber.FER_Overall(idx);
            fer_l = T_ber.FER_Wilson_Lower(idx);
            fer_u = T_ber.FER_Wilson_Upper(idx);
            
            fer_plot = fer; fer_plot(fer_plot == 0) = 1e-4; 
            
            % Plot with errorbars or just lines. 
            plot(snr, fer_plot, styles{v}, 'Color', colors(v,:), 'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', vars{v});
            obj_count_1 = obj_count_1 + 1;
            
            for i = 1:length(snr)
                % ProfileID, ProfileDescription, Variant, SNR_dB, FER_Overall, FER_Wilson_Lower, FER_Wilson_Upper
                t1_src_cells(end+1, :) = {profiles{p}, T_ber.ProfileDescription{idx(1)}, vars{v}, snr(i), fer(i), fer_l(i), fer_u(i)};
            end
        end
        set(gca, 'YScale', 'log');
        ylim([1e-4, 1]); xlabel('SNR (dB)'); ylabel('FER (Overall)');
        title(sprintf('Profile %s', profiles{p}));
        legend('Location', 'southwest');
    end
    t1_src = cell2table(t1_src_cells, 'VariableNames', {'ProfileID', 'ProfileDescription', 'Variant', 'SNR_dB', 'FER_Overall', 'FER_Wilson_Lower', 'FER_Wilson_Upper'});
    
    if height(t1_src) ~= 63
        error('FIGURE_SOURCE_DATA_INCOMPLETE: Fig1 has %d rows instead of 63', height(t1_src));
    end
    fprintf(audit_fid, 'FIG1_SOURCE_ROWS=%d PASS\n', height(t1_src));
    writetable(t1_src, fullfile(out_dir, 'Fig1_FER_vs_SNR_source.csv'));
    saveas(f1, fullfile(out_dir, 'Fig1_FER_vs_SNR.png'));
    saveas(f1, fullfile(out_dir, 'Fig1_FER_vs_SNR.pdf'));
    savefig(f1, fullfile(out_dir, 'Fig1_FER_vs_SNR.fig'));
    
    % --- Fig2: BER vs SNR ---
    f2 = figure('Name', 'Fig2_BER_vs_SNR', 'Position', [100, 100, 1200, 400]);
    t2_src_cells = cell(0, 7);
    obj_count_2 = 0;
    for p = 1:3
        subplot(1, 3, p); hold on; grid on;
        for v = 1:3
            idx = find(strcmp(T_ber.ProfileID, profiles{p}) & strcmp(T_ber.Variant, vars{v}));
            snr = T_ber.SNR_dB(idx);
            ber = T_ber.BER_Valid(idx);
            ber_l = T_ber.BER_Wilson_Lower(idx);
            ber_u = T_ber.BER_Wilson_Upper(idx);
            
            ber_plot = ber; ber_plot(ber_plot == 0) = 1e-5; 
            plot(snr, ber_plot, styles{v}, 'Color', colors(v,:), 'LineWidth', 1.5, 'MarkerSize', 6, 'DisplayName', vars{v});
            obj_count_2 = obj_count_2 + 1;
            
            for i = 1:length(snr)
                t2_src_cells(end+1, :) = {profiles{p}, T_ber.ProfileDescription{idx(1)}, vars{v}, snr(i), ber(i), ber_l(i), ber_u(i)};
            end
        end
        set(gca, 'YScale', 'log');
        ylim([1e-5, 0.5]); xlabel('SNR (dB)'); ylabel('BER (Valid)');
        title(sprintf('Profile %s', profiles{p}));
        legend('Location', 'southwest');
    end
    t2_src = cell2table(t2_src_cells, 'VariableNames', {'ProfileID', 'ProfileDescription', 'Variant', 'SNR_dB', 'BER_Valid', 'BER_Wilson_Lower', 'BER_Wilson_Upper'});
    
    if height(t2_src) ~= 63, error('FIGURE_SOURCE_DATA_INCOMPLETE: Fig2 %d != 63', height(t2_src)); end
    fprintf(audit_fid, 'FIG2_SOURCE_ROWS=%d PASS\n', height(t2_src));
    writetable(t2_src, fullfile(out_dir, 'Fig2_BER_vs_SNR_source.csv'));
    saveas(f2, fullfile(out_dir, 'Fig2_BER_vs_SNR.png'));
    saveas(f2, fullfile(out_dir, 'Fig2_BER_vs_SNR.pdf'));
    savefig(f2, fullfile(out_dir, 'Fig2_BER_vs_SNR.fig'));
    
    % --- Fig3: Dynamic RMSE ---
    f3 = figure('Name', 'Fig3_Dynamic_RMSE', 'Position', [100, 100, 1200, 400]);
    t3_src_cells = cell(0, 7);
    obj_count_3 = 0;
    for m = 1:2
        subplot(1, 2, m); hold on; grid on;
        metrics = {'Overall', 'Fade'};
        met = metrics{m};
        
        for p = 1:3
            for v = 1:3
                idx = find(strcmp(T_trk.ProfileID, profiles{p}) & strcmp(T_trk.Variant, vars{v}));
                if ~isempty(idx)
                    rm_o = T_trk.Overall_RMSE_Median(idx(1));
                    rm_o_p10 = T_trk.Overall_RMSE_P10(idx(1));
                    rm_o_p90 = T_trk.Overall_RMSE_P90(idx(1));
                    rm_f = T_trk.FADE_RMSE_Median(idx(1));
                    
                    x_base = p - 1;
                    x_offset = (v-2)*0.25;
                    
                    if strcmp(met, 'Overall')
                        bar(x_base + x_offset, rm_o, 0.2, 'FaceColor', colors(v,:), 'EdgeColor', 'k');
                    else
                        bar(x_base + x_offset, rm_f, 0.2, 'FaceColor', colors(v,:), 'EdgeColor', 'k');
                    end
                    obj_count_3 = obj_count_3 + 1;
                    
                    if m == 1
                        t3_src_cells(end+1, :) = {profiles{p}, T_trk.ProfileDescription{idx(1)}, vars{v}, rm_o, rm_o_p10, rm_o_p90, rm_f};
                    end
                end
            end
        end
        xticks(0:2); xticklabels(profiles); ylabel(sprintf('%s RMSE (samples)', met));
        title(sprintf('Dynamic Tracking Accuracy (%s)', met));
        for v = 1:3, plot(NaN, NaN, 's', 'MarkerFaceColor', colors(v,:), 'MarkerEdgeColor', 'k', 'DisplayName', vars{v}); end
        legend('Location', 'northeast');
    end
    t3_src = cell2table(t3_src_cells, 'VariableNames', {'ProfileID', 'ProfileDescription', 'Variant', 'Overall_RMSE_Median', 'Overall_RMSE_P10', 'Overall_RMSE_P90', 'Fade_RMSE_Median'});
    
    if height(t3_src) ~= 9, error('FIGURE_SOURCE_DATA_INCOMPLETE: Fig3 %d != 9', height(t3_src)); end
    fprintf(audit_fid, 'FIG3_SOURCE_ROWS=%d PASS\n', height(t3_src));
    writetable(t3_src, fullfile(out_dir, 'Fig3_Dynamic_RMSE_source.csv'));
    saveas(f3, fullfile(out_dir, 'Fig3_Dynamic_RMSE.png'));
    saveas(f3, fullfile(out_dir, 'Fig3_Dynamic_RMSE.pdf'));
    savefig(f3, fullfile(out_dir, 'Fig3_Dynamic_RMSE.fig'));
    
    % --- Fig4: Reliability Mechanism ---
    f4 = figure('Name', 'Fig4_Reliability_Mechanism', 'Position', [100, 100, 1200, 400]);
    t4_src_cells = cell(0, 12);
    phases = {'PRE', 'FADE', 'POST'};
    obj_count_4 = 0;
    
    for p = 1:3
        idx = find(strcmp(T_mech.ProfileID, profiles{p}) & strcmp(T_mech.Variant, 'E-FQ'));
        if ~isempty(idx)
            m_pre = T_mech.Median_m_PRE(idx(1)); m_fade = T_mech.Median_m_FADE(idx(1)); m_post = T_mech.Median_m_POST(idx(1));
            r_pre = T_mech.Median_Reff_Rvb_PRE(idx(1)); r_fade = T_mech.Median_Reff_Rvb_FADE(idx(1)); r_post = T_mech.Median_Reff_Rvb_POST(idx(1));
            k_pre = T_mech.Median_K_PRE(idx(1)); k_fade = T_mech.Median_K_FADE(idx(1)); k_post = T_mech.Median_K_POST(idx(1));
            q11 = T_mech.Median_Q11_PRE(idx(1)); q22 = T_mech.Median_Q22_PRE(idx(1));
            
            t4_src_cells(end+1, :) = {profiles{p}, m_pre, m_fade, m_post, r_pre, r_fade, r_post, k_pre, k_fade, k_post, q11, q22};
            
            subplot(1, 3, p); hold on; grid on;
            plot(1:3, [m_pre, m_fade, m_post], '-o', 'LineWidth', 2, 'DisplayName', 'm');
            plot(1:3, [r_pre, r_fade, r_post], '-s', 'LineWidth', 2, 'DisplayName', 'Reff/Rvb');
            plot(1:3, [k_pre, k_fade, k_post], '-d', 'LineWidth', 2, 'DisplayName', 'K');
            obj_count_4 = obj_count_4 + 3;
            
            xticks(1:3); xticklabels(phases);
            title(sprintf('%s Mechanism (Q11=%g, Q22=%g fixed)', profiles{p}, q11, q22));
            legend('Location', 'best');
        end
    end
    t4_src = cell2table(t4_src_cells, 'VariableNames', {'ProfileID', 'm_PRE', 'm_FADE', 'm_POST', 'ReffRvb_PRE', 'ReffRvb_FADE', 'ReffRvb_POST', 'K_PRE', 'K_FADE', 'K_POST', 'Q11', 'Q22'});
    
    if height(t4_src) ~= 3, error('FIGURE_SOURCE_DATA_INCOMPLETE: Fig4 %d != 3', height(t4_src)); end
    fprintf(audit_fid, 'FIG4_SOURCE_ROWS=%d PASS\n', height(t4_src));
    writetable(t4_src, fullfile(out_dir, 'Fig4_Reliability_Mechanism_source.csv'));
    saveas(f4, fullfile(out_dir, 'Fig4_Reliability_Mechanism.png'));
    saveas(f4, fullfile(out_dir, 'Fig4_Reliability_Mechanism.pdf'));
    savefig(f4, fullfile(out_dir, 'Fig4_Reliability_Mechanism.fig'));
    
    % --- Fig5: Paired Fade Effect ---
    f5 = figure('Name', 'Fig5_Paired_Fade_Effect', 'Position', [100, 100, 800, 500]);
    t5_src_cells = cell(0, 6);
    obj_count_5 = 0;
    hold on; grid on;
    for p = 1:3
        idx_iae = find(strcmp(T_boot.ProfileID, profiles{p}) & strcmp(T_boot.Comparison, 'E-FQ vs IAE') & strcmp(T_boot.Metric, 'Fade_RMSE'));
        idx_vb = find(strcmp(T_boot.ProfileID, profiles{p}) & strcmp(T_boot.Comparison, 'E-FQ vs VB-FQ') & strcmp(T_boot.Metric, 'Fade_RMSE'));
        
        if ~isempty(idx_iae)
            med_iae = T_boot.Median_Difference(idx_iae(1));
            ci_iae = [T_boot.CI95_Lower(idx_iae(1)), T_boot.CI95_Upper(idx_iae(1))];
            errorbar(p - 0.1, med_iae, med_iae - ci_iae(1), ci_iae(2) - med_iae, 'o', 'Color', colors(1,:), 'LineWidth', 2, 'MarkerFaceColor', colors(1,:));
            t5_src_cells(end+1, :) = {profiles{p}, 'E-FQ vs IAE', med_iae, ci_iae(1), ci_iae(2), T_boot.WinRate_EFQ(idx_iae(1))};
            obj_count_5 = obj_count_5 + 1;
        end
        if ~isempty(idx_vb)
            med_vb = T_boot.Median_Difference(idx_vb(1));
            ci_vb = [T_boot.CI95_Lower(idx_vb(1)), T_boot.CI95_Upper(idx_vb(1))];
            errorbar(p + 0.1, med_vb, med_vb - ci_vb(1), ci_vb(2) - med_vb, 's', 'Color', colors(2,:), 'LineWidth', 2, 'MarkerFaceColor', colors(2,:));
            t5_src_cells(end+1, :) = {profiles{p}, 'E-FQ vs VB-FQ', med_vb, ci_vb(1), ci_vb(2), T_boot.WinRate_EFQ(idx_vb(1))};
            obj_count_5 = obj_count_5 + 1;
        end
    end
    plot([0 4], [0 0], 'k--');
    xlim([0.5, 3.5]); xticks(1:3); xticklabels(profiles);
    ylabel('Paired Fade RMSE Difference (E-FQ - Comparator)');
    title('Fade Tracking Paired Improvement');
    plot(NaN, NaN, 'o', 'Color', colors(1,:), 'MarkerFaceColor', colors(1,:), 'DisplayName', 'vs IAE');
    plot(NaN, NaN, 's', 'Color', colors(2,:), 'MarkerFaceColor', colors(2,:), 'DisplayName', 'vs VB-FQ');
    legend('Location', 'northeast');
    
    t5_src = cell2table(t5_src_cells, 'VariableNames', {'ProfileID', 'Comparison', 'Median_Difference', 'CI95_Lower', 'CI95_Upper', 'WinRate_EFQ'});
    if height(t5_src) ~= 6, error('FIGURE_SOURCE_DATA_INCOMPLETE: Fig5 %d != 6', height(t5_src)); end
    fprintf(audit_fid, 'FIG5_SOURCE_ROWS=%d PASS\n', height(t5_src));
    writetable(t5_src, fullfile(out_dir, 'Fig5_Paired_Fade_Effect_source.csv'));
    saveas(f5, fullfile(out_dir, 'Fig5_Paired_Fade_Effect.png'));
    saveas(f5, fullfile(out_dir, 'Fig5_Paired_Fade_Effect.pdf'));
    savefig(f5, fullfile(out_dir, 'Fig5_Paired_Fade_Effect.fig'));
    
    fclose(audit_fid);
    
    % Object Audit
    fid_obj = fopen(fullfile('results', 'paper_review', 'final_figure_object_audit.txt'), 'w');
    if obj_count_1 == 9, fprintf(fid_obj, 'FIG1_OBJECTS=%d PASS\n', obj_count_1); else, fprintf(fid_obj, 'FIG1_OBJECTS=%d FAIL\n', obj_count_1); end
    if obj_count_2 == 9, fprintf(fid_obj, 'FIG2_OBJECTS=%d PASS\n', obj_count_2); else, fprintf(fid_obj, 'FIG2_OBJECTS=%d FAIL\n', obj_count_2); end
    if obj_count_3 == 18, fprintf(fid_obj, 'FIG3_OBJECTS=%d PASS\n', obj_count_3); else, fprintf(fid_obj, 'FIG3_OBJECTS=%d FAIL\n', obj_count_3); end
    if obj_count_4 == 9, fprintf(fid_obj, 'FIG4_OBJECTS=%d PASS\n', obj_count_4); else, fprintf(fid_obj, 'FIG4_OBJECTS=%d FAIL\n', obj_count_4); end
    if obj_count_5 == 6, fprintf(fid_obj, 'FIG5_OBJECTS=%d PASS\n', obj_count_5); else, fprintf(fid_obj, 'FIG5_OBJECTS=%d FAIL\n', obj_count_5); end
    fclose(fid_obj);
    
    disp('Figure generation complete.');
end
