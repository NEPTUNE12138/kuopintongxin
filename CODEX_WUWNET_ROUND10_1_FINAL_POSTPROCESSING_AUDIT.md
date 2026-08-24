# WUWNet Paper 2 — Round-10.1 Final Post-Processing, Consistency & Figure Audit

Repository:
`NEPTUNE12138/kuopintongxin`

Start from final 3000-MC result commit:
`cda0964df2caf95ad03f9875d1e4dd47285f584a`

SCIENTIFIC STATUS ENTERING ROUND-10.1:

```text
3000-MC BER run: COMPLETE
3000-MC Stress run: COMPLETE
PAPER-1 through PAPER-6: ALL PASS
Core final scientific results: ACCEPTED
NO FURTHER PARAMETER TUNING
```

Round-10.1 is NOT a simulation round.

DO NOT rerun:
- 3000-MC BER
- 3000-MC Stress
- 200-MC Pilot
- held-out Round-6
- CFAR
- equalizer
- any parameter scan

DO NOT change:
- Q
- c2
- Kcal
- E-FQ algorithm
- reliability formula
- VB recursion
- Early/Late spacing
- Bellhop local-cluster policy
- SNR grid
- stress scenario
- variants
- seeds

Use ONLY the already committed raw final MAT files and Pilot result files,
except for the small runtime benchmark explicitly authorized below.

Purpose:
finish the missing publication/audit artifacts without touching the scientific data.

---

# 1. Preserve final scientific result status

The current accepted 3000-MC result commit is:

```text
cda0964df2caf95ad03f9875d1e4dd47285f584a
```

Do not change or overwrite:

```text
results/paper/paper2_ber_validation_3000mc.mat
results/paper/paper2_stress_pilot_3000mc.mat
results/paper/checkpoints/*
results/paper_review/final_ber_table.csv
results/paper_review/final_threshold_table.csv
results/paper_review/final_tracking_table.csv
results/paper_review/final_mechanism_table.csv
```

If regenerated analysis tables are numerically identical, overwrite only the
derived CSVs intentionally and report exact before/after comparison.

---

# 2. Final raw-data integrity audit

Create:

```matlab
src/audit_final_paper_artifacts.m
```

Load the two final raw MAT files and assert:

## BER

```text
raw_errors dimensions = [3, 7, 3, 3000]
profiles = 3
SNR grid = -16:-10
variants = A / VB-FQ / E-FQ
labels = IAE / VB-FQ / E-FQ
```

For every BER cell:
- attempted trials = 3000
- valid-count computed from raw_errors matches final_ber_table.csv
- bit-error totals match final_ber_table.csv
- FER counts match final_ber_table.csv

## Stress

For every P1/P2/P3 × IAE/VB-FQ/E-FQ:
- each raw vector length = 3000
- valid count matches final_tracking_table.csv
- RMSE medians independently recompute to the published table
- E-FQ required mechanism telemetry has no missing values on valid trials

Required E-FQ telemetry:
```text
m_pre/m_fade/m_post
mean_Reff_Rvb_pre/fade/post
mean_K_pre/fade/post
Q11_pre/fade/post
Q22_pre/fade/post
```

## Checkpoints

Verify exactly:
```text
21 BER checkpoint files
3 Stress checkpoint files
```

and each checkpoint has the expected completed shape.

Do NOT use checkpoints to regenerate scientific data.

Create:

```text
results/paper_review/final_data_integrity_report.txt
```

with:
```text
BER_SHAPE_PASS
STRESS_SHAPE_PASS
SUMMARY_RECOMPUTE_PASS
MECHANISM_COMPLETENESS_PASS
CHECKPOINT_COUNT_PASS
```

Fail closed.

---

# 3. Create final_raw_index.txt

This was required in Round-10 but is currently missing.

Create:

```text
results/paper_review/final_raw_index.txt
```

Record:

```text
paper basis SHA
result commit SHA

final BER MAT path
final Stress MAT path

BER dimensions
Stress trial count

checkpoint directory
BER checkpoint count
Stress checkpoint count

final BER table path
final tracking table path
final bootstrap table path
final mechanism table path
```

Do not invent a SHA for dirty/uncommitted working-tree content.

---

# 4. Correct execution-SHA terminology

Current manifest uses:

```text
execution_worktree_sha = 01521c...
```

but `git rev-parse HEAD` only proves HEAD, not whether the worktree was clean.

Rename conceptually to:

```text
execution_head_sha = 01521c6d3bc2f3d9455b87e01898869fb635b37a
result_commit_sha = cda0964df2caf95ad03f9875d1e4dd47285f584a
```

Add:

```text
execution_worktree_clean = NOT RECORDED
```

unless there is actual recorded evidence proving it.

Do NOT falsely state the worktree was clean.

Keep:

```text
paper_basis_sha = 01521c...
```

---

# 5. Populate Pilot-to-Paper consistency analysis

Current:

```text
results/paper_review/pilot_paper_consistency.csv
```

contains only the header.

This must be completed using already existing Pilot and Paper tables.

Use:

```text
results/pilot_review/pilot_transition_thresholds.csv
results/pilot_review/pilot_stress_summary.csv
results/pilot_review/pilot_tracking_paired_bootstrap.csv

results/paper_review/final_threshold_table.csv
results/paper_review/final_tracking_table.csv
results/paper_review/final_bootstrap_table.csv
results/paper_review/final_mechanism_table.csv
```

Required consistency rows:

## Thresholds

For every Profile × Variant:
```text
SNR50
SNR05
```

## Tracking medians

For every Profile × Variant:
```text
Overall_RMSE
Fade_RMSE
```

## Primary effect ratios

For every profile:
```text
E-FQ/IAE Overall ratio
E-FQ/IAE Fade ratio
E-FQ/VB-FQ Overall ratio
E-FQ/VB-FQ Fade ratio
```

## Mechanism

For E-FQ each profile:
```text
m_PRE
m_FADE
R_eff/R_vb_PRE
R_eff/R_vb_FADE
K_PRE
K_FADE
Q11
Q22
```

Columns:

```text
Profile
Variant_or_Comparison
Metric
PilotValue
PaperValue
Difference
RelativeDifference
DirectionConsistent
```

For quantities where RelativeDifference is not meaningful, write NaN,
not a fabricated percentage.

Important observed changes that MUST be transparently reflected if the files confirm them:

```text
P2 E-FQ SNR50:
Pilot = -13 dB
Paper = -12 dB

P3 IAE SNR05:
Pilot = -13 dB
Paper = -12 dB
```

Do not hide threshold movement due to increased MC size.

Interpretation:
the primary effect directions remain consistent even if an integer-grid
threshold changes by 1 dB.

---

# 6. Complete final bootstrap table

Current `final_bootstrap_table.csv` only contains Fade_RMSE rows.

Round-10 predeclared BOTH:
```text
Overall_RMSE
Fade_RMSE
```

for:
```text
E-FQ vs IAE
E-FQ vs VB-FQ
```

Regenerate from the existing final Stress MAT ONLY.

For each of 3 profiles:
```text
2 comparisons × 2 metrics = 4 rows
```

Expected total:

```text
12 data rows
```

Use exactly:

```text
paired trials
10,000 bootstrap resamples
bootstrap seed = 20260909
difference = E-FQ - comparator
```

Columns:

```text
Profile
Comparison
Metric
N_Paired
Median_EFQ
Median_Comparator
Median_Difference
CI95_Lower
CI95_Upper
WinRate_EFQ
Median_Ratio
ReductionPercent
```

Do not alter PAPER-3 gate logic.
This is completion of the predeclared analysis.

---

# 7. Independently recompute final headline effect sizes

Create:

```text
results/paper_review/final_headline_effects.csv
```

For each profile:

```text
Overall E-FQ vs IAE
Fade E-FQ vs IAE
Overall E-FQ vs VB-FQ
Fade E-FQ vs VB-FQ
```

Columns:

```text
Profile
Metric
Comparator
ComparatorMedian
EFQMedian
Ratio
ReductionPercent
```

Expected from current tables approximately:

```text
P1 Overall vs IAE: ~11.5% reduction
P2 Overall vs IAE: ~22.1%
P3 Overall vs IAE: ~29.6%

P1 Fade vs IAE: ~16.9%
P2 Fade vs IAE: ~26.9%
P3 Fade vs IAE: ~35.0%

P1 Fade vs VB-FQ: ~8.6%
P2 Fade vs VB-FQ: ~11.3%
P3 Fade vs VB-FQ: ~13.9%
```

Recompute from raw data/table, do not hard-code these rounded values.

---

# 8. Complete mechanism descriptive effect table

Create:

```text
results/paper_review/final_mechanism_effects.csv
```

For E-FQ per profile compute:

```text
ReliabilityDropPercent
ReffRvbIncreasePercent
KReductionPercent
```

Definitions:

```matlab
ReliabilityDropPercent =
100*(1 - m_fade/m_pre);

ReffRvbIncreasePercent =
100*(Rratio_fade/Rratio_pre - 1);

KReductionPercent =
100*(1 - K_fade/K_pre);
```

Expected approximately from current final data:

```text
P1:
m drop ~16.0%
R inflation +42.1%
K reduction ~14.6%

P2:
m drop ~13.9%
R inflation +34.1%
K reduction ~16.5%

P3:
m drop ~14.6%
R inflation +37.4%
K reduction ~15.1%
```

Again recompute, do not hard-code.

---

# 9. Fix mechanism telemetry test completely

Current `test_pilot_mechanism_telemetry_complete.m` no longer swallows
SyncFail, but it still only checks vector existence/length.

Strengthen it to:
- require receiver SUCCESS;
- construct non-empty physical/controlled PRE/FADE/POST masks;
- calculate phase telemetry summaries;
- assert all are finite;
- assert E-FQ Q phase medians equal [0.05,0.002].

Do not change the receiver.

Keep `test_pilot4_fail_closed_on_nan` calling the REAL
`evaluate_mechanism_gate`.

Add:

```text
test_final_raw_shapes
test_final_summary_recompute
test_final_bootstrap_schema
test_pilot_paper_consistency_nonempty
```

---

# 10. Final publication figures

Current repository has NO committed:

```text
results/paper_figures/
```

Create it now using existing final 3000-MC results only.

Generate:

## Figure 1 — FER vs SNR

Preferred final communication figure.

Three panels or three separate files for P1/P2/P3.

Curves:
```text
IAE
VB-FQ
E-FQ
```

Use:
```text
FER_Overall
Wilson 95% CI
```

SNR:
```text
-16:-10 dB
```

## Figure 2 — BER vs SNR

Same variants/profiles.

Use BER_Valid + Wilson CI.

If using log scale:
- preserve actual zero values in source CSV;
- use an explicitly documented visualization floor only for plotting.

## Figure 3 — Dynamic Tracking RMSE

For each profile compare:
```text
IAE
VB-FQ
E-FQ
```

Show:
```text
Overall RMSE
Fade RMSE
```

Use medians.
Use P10/P90 where available or paired-data uncertainty derived from raw MAT.

## Figure 4 — Mechanism

E-FQ only.

For P1/P2/P3 show PRE/FADE/POST:
```text
m
R_eff/R_vb
K_delay
```

Q should be described as fixed:
```text
Q11 = 0.05
Q22 = 0.002
```

Do not imply Q changes.

## Figure 5 — Paired Fade Improvement

Recommended:
for each profile visualize paired:
```text
E-FQ - IAE
E-FQ - VB-FQ
```

with median + 95% paired-bootstrap CI.

Do not plot rejected TRM/E-CAL/equalizer as final methods.

For each figure save:

```text
PNG
PDF
FIG
source CSV
```

Names:

```text
Fig1_FER_vs_SNR.*
Fig2_BER_vs_SNR.*
Fig3_Dynamic_RMSE.*
Fig4_Reliability_Mechanism.*
Fig5_Paired_Fade_Effect.*
```

Make publication-readable axes/legends.
Do not create decorative figures unsupported by data.

---

# 11. Final runtime benchmark

Current repository does not contain the required final runtime table,
and the old benchmark still uses legacy variants A/B/C/D/E.

Create:

```matlab
src/benchmark_final_paper_variants.m
```

Only benchmark:

```text
IAE
VB-FQ
E-FQ
```

Use:
```text
100 repeated packets
one deterministic representative final front end
same packet/input for all methods
```

Report:

```text
Variant
Median_ms_per_packet
P10_ms_per_packet
P90_ms_per_packet
RelativeRuntime_vs_IAE
```

Save:

```text
results/paper_review/final_runtime_table.csv
```

This benchmark is NOT a scientific gate.

Do not benchmark TRM/equalizer.

---

# 12. Final gate re-audit without simulations

Do not rerun final data.

Recompute PAPER-1 through PAPER-6 entirely from:
- existing final raw MATs
- regenerated derived tables

Confirm the same result:

```text
PAPER_3000MC_COMPLETE
FINAL_RESULTS_ACCEPTED
```

If derived re-audit disagrees with current gate report:
STOP and report the discrepancy.
Do not tune/re-simulate.

---

# 13. Update PAPER_CODE_ALIGNMENT.md

Replace stale:

```text
Final publication variants ... FROZEN FOR PILOT
Pilot: READY ONLY IF ...
Paper: READY
```

with:

```text
Final publication variants IAE / VB-FQ / E-FQ: FROZEN FINAL
200-MC Pilot: ALL PREDECLARED GATES PASS
3000-MC Paper: COMPLETE
Final large-MC gates: PASS
Final post-processing audit: COMPLETE
```

Keep:
- TRM rejected
- EQ rejected
- adaptive-Q E-CAL rejected
- no sea-trial claim
- Bellhop local-cluster wording

---

# 14. Final manifest

Update:

```text
results/paper_review/final_manifest.txt
```

Include:

```text
paper_basis_sha = 01521c6d3bc2f3d9455b87e01898869fb635b37a
execution_head_sha = 01521c6d3bc2f3d9455b87e01898869fb635b37a
execution_worktree_clean = NOT RECORDED
paper_result_commit_sha = cda0964df2caf95ad03f9875d1e4dd47285f584a
postprocessing_commit_sha = <new commit>
```

Plus frozen architecture and MC values.

If self-SHA cannot be recorded in one commit, use:
```text
postprocessing_basis_sha = cda096...
```
rather than inventing the new commit.

---

# 15. Required final repository outputs

After Round-10.1, the following MUST exist:

```text
results/paper_review/final_ber_table.csv
results/paper_review/final_threshold_table.csv
results/paper_review/final_tracking_table.csv
results/paper_review/final_bootstrap_table.csv
results/paper_review/final_mechanism_table.csv
results/paper_review/final_mechanism_effects.csv
results/paper_review/final_headline_effects.csv
results/paper_review/pilot_paper_consistency.csv
results/paper_review/final_runtime_table.csv
results/paper_review/final_data_integrity_report.txt
results/paper_review/final_gate_report.txt
results/paper_review/final_manifest.txt
results/paper_review/final_raw_index.txt

results/paper_figures/Fig1_FER_vs_SNR.png
results/paper_figures/Fig1_FER_vs_SNR.pdf
results/paper_figures/Fig1_FER_vs_SNR.fig
results/paper_figures/Fig1_FER_vs_SNR_source.csv

results/paper_figures/Fig2_BER_vs_SNR.*
results/paper_figures/Fig3_Dynamic_RMSE.*
results/paper_figures/Fig4_Reliability_Mechanism.*
results/paper_figures/Fig5_Paired_Fade_Effect.*
```

---

# 16. HARD SCIENTIFIC STOP

NO MORE:
- algorithm changes
- parameter tuning
- Monte Carlo reruns
- profile selection
- SNR selection

After Round-10.1 the next phase is manuscript drafting/audit only.

---

# REQUIRED FINAL REPORT

## Scientific data status
- 3000-MC raw data unchanged: yes/no
- any simulation rerun: yes/no
- any parameter change: yes/no

## Raw integrity
- BER shape
- Stress vector lengths
- checkpoint counts
- recompute agreement

## Headline results
Per profile:
- Overall E-FQ vs IAE reduction
- Fade E-FQ vs IAE reduction
- Fade E-FQ vs VB-FQ reduction

## Bootstrap
For Overall and Fade:
- all 12 comparison rows
- paired CI
- win rate

## Mechanism
Per profile:
- m drop
- R_eff/R_vb increase
- K reduction
- Q fixed

## Pilot→Paper consistency
Explicitly report threshold movements and tracking effect stability.

## Publication package
- figures created
- source CSVs created
- final runtime table created

## Final decision

If all post-processing checks pass:

```text
FINAL_3000MC_DATA_AUDITED
FINAL_PUBLICATION_ARTIFACTS_COMPLETE
READY_FOR_MANUSCRIPT_DRAFTING
NO FURTHER PARAMETER TUNING
```

Final line:

```text
WAITING FOR MANUSCRIPT SCIENTIFIC AUDIT.
```
