# WUWNet Paper 2 — Round-10.2 Profile-Key / Figure Artifact Repair

Repo: `NEPTUNE12138/kuopintongxin`
Base: `e37b4a1196bc364d6520485693e196a0365035cd`
Accepted 3000-MC scientific-data commit: `cda0964df2caf95ad03f9875d1e4dd47285f584a`

## Status

The 3000-MC BER/Stress data and PAPER-1..6 scientific gates remain ACCEPTED.

Round-10.2 is deterministic post-processing ONLY.

DO NOT rerun any Pilot/3000-MC simulation.
DO NOT change Q, c2, Kcal, reliability formula, VB recursion, Early/Late, seeds,
Bellhop clusters, SNR grid, stress scenario, variants, TRM/EQ state, or any
algorithm parameter.

## Root cause to repair

Final CSV Profile values are verbose strings:

- `Profile P1: Tx15m / 20km / Rx34m`
- `Profile P2: Tx15m / 20km / Rx3467m`
- `Profile P3: Tx100m / 45km / Rx110m`

Round-10.1 code uses `strcmp(T.Profile,'P1')`, etc., so zero rows match.

Evidence:
- `pilot_paper_consistency.csv` is header-only.
- figure source CSVs are header-only.
- therefore existing PNG/PDF/FIG files are NOT accepted as publication figures.

## 1. Canonical profile helper

Create `lib/canonical_profile_id.m`.

It must map both compact and verbose strings to exactly `P1`, `P2`, `P3`.
Unknown strings must error.

Add `tests/test_canonical_profile_id.m`.

In `src/analyze_paper2_paper.m` and `src/generate_paper2_figures.m`, create a
canonical `ProfileID` column and use ONLY `ProfileID` for joins/filtering.
Do not compare raw verbose Profile strings.

## 2. Pilot→Paper consistency

Regenerate `results/paper_review/pilot_paper_consistency.csv` from existing
Pilot/Paper artifacts only.

Schema:

`ProfileID,ProfileDescription,Variant_or_Comparison,Metric,PilotValue,PaperValue,Difference,RelativeDifference,DirectionConsistent`

Required rows:

A. Thresholds:
3 profiles × 3 variants × {SNR50,SNR05} = 18 rows.

B. Tracking medians:
3 profiles × 3 variants × {Overall_RMSE,Fade_RMSE} = 18 rows.

C. Effect ratios:
per profile:
- E-FQ/IAE Overall
- E-FQ/IAE Fade
- E-FQ/VB-FQ Overall
- E-FQ/VB-FQ Fade
= 12 rows.

D. E-FQ mechanism:
per profile:
m_PRE, m_FADE, ReffRvb_PRE, ReffRvb_FADE, K_PRE, K_FADE, Q11, Q22
= 24 rows.

TOTAL = 72 data rows + header.

Difference = Paper - Pilot.
RelativeDifference only where meaningful and Pilot != 0; otherwise NaN.
For raw scalar rows use DirectionConsistent=`NA`.
For effect-ratio rows TRUE iff Pilot ratio <1 AND Paper ratio <1.

Explicitly preserve these known MC threshold movements if confirmed:
- P2 E-FQ SNR50: Pilot -13, Paper -12.
- P3 IAE SNR05: Pilot -13, Paper -12.

Also create
`results/paper_review/pilot_paper_direction_summary.csv`
with 3 rows (P1/P2/P3), containing all four tracking effect ratios plus
mechanism-direction checks in BOTH Pilot and Paper:
m_FADE<m_PRE,
ReffRvb_FADE>ReffRvb_PRE,
K_FADE<K_PRE,
Q fixed [0.05,0.002].

## 3. Bootstrap table verification

Keep current final bootstrap scientific values unless deterministic
recomputation finds an error.

Assert `final_bootstrap_table.csv` has exactly:
3 profiles × 2 comparisons × 2 metrics = 12 rows.

Comparisons:
- E-FQ vs IAE
- E-FQ vs VB-FQ

Metrics:
- Overall_RMSE
- Fade_RMSE

Every row:
N_Paired=3000 and all CI/ratio values finite.

## 4. Repair figures from canonical ProfileID

Modify `src/generate_paper2_figures.m`.

Before saving ANY figure, assert its source-data row count.
If wrong: error `FIGURE_SOURCE_DATA_INCOMPLETE` and do not save.

### Fig1 FER vs SNR
Source rows = 63.
Columns:
ProfileID, ProfileDescription, Variant, SNR_dB,
FER_Overall, FER_Wilson_Lower, FER_Wilson_Upper.
Plot Wilson 95% intervals.
Exact zero values remain zero in source CSV.

### Fig2 BER vs SNR
Source rows = 63.
Columns:
ProfileID, ProfileDescription, Variant, SNR_dB,
BER_Valid, BER_Wilson_Lower, BER_Wilson_Upper.
Plot Wilson 95% intervals.
Exact zeros remain zero in source.

### Fig3 Dynamic RMSE
Current Round-10.1 code only draws Fade; fix this.
Source rows = 9.
Columns:
ProfileID, ProfileDescription, Variant,
Overall_RMSE_Median, Overall_RMSE_P10, Overall_RMSE_P90,
Fade_RMSE_Median.
Show BOTH Overall and Fade clearly (two panels is preferred).
Do not call P10/P90 confidence intervals.

### Fig4 Reliability Mechanism
E-FQ only; source rows = 3.
Columns:
ProfileID,
m_PRE,m_FADE,m_POST,
ReffRvb_PRE,ReffRvb_FADE,ReffRvb_POST,
K_PRE,K_FADE,K_POST,Q11,Q22.
Prefer separate metric panels; do not misleadingly imply Q changes.
State Q11=0.05, Q22=0.002 fixed.

### Fig5 Paired Fade Effect
Source rows = 6.
Columns:
ProfileID,Comparison,Median_Difference,CI95_Lower,CI95_Upper,WinRate_EFQ.
Plot E-FQ vs IAE and E-FQ vs VB-FQ with paired-bootstrap 95% CI and zero line.

Save each as PNG/PDF/FIG/source CSV.

## 5. Figure source/object audit

Create `results/paper_review/final_figure_source_audit.txt` containing:

- FIG1_SOURCE_ROWS=63 PASS
- FIG2_SOURCE_ROWS=63 PASS
- FIG3_SOURCE_ROWS=9 PASS
- FIG4_SOURCE_ROWS=3 PASS
- FIG5_SOURCE_ROWS=6 PASS

Reopen source CSVs after writing and verify required numeric columns are not
entirely NaN.

Also create `final_figure_object_audit.txt`.
Before closing figures verify real scientific plotted objects, excluding dummy
legend objects:
- Fig1: 9 method curves
- Fig2: 9 method curves
- Fig3: data for 3 profiles×3 methods×2 metrics
- Fig4: all 3 profiles×3 mechanism metrics
- Fig5: 6 effect estimates

## 6. Add missing regression tests

Add:

- `tests/test_final_raw_shapes.m`
- `tests/test_final_summary_recompute.m`
- `tests/test_final_bootstrap_schema.m`
- `tests/test_pilot_paper_consistency_nonempty.m`
- `tests/test_final_figure_source_rows.m`
- `tests/test_figure_profile_key_mapping.m`

Requirements:
- BER raw shape = 3×7×3×3000.
- each Stress trial vector length = 3000.
- selected summary cells independently recompute from raw MAT.
- bootstrap = 12 rows, 2 metrics, 2 comparisons, 3 profiles, N=3000.
- consistency = exactly 72 data rows and explicitly verifies the two known
  1-dB threshold changes.
- source rows exactly 63,63,9,3,6.
- verbose profile strings map correctly and yield expected selections.

Keep the strengthened mechanism telemetry test.
Do not alter receiver/scientific algorithms.

## 7. Runtime table

Audit existing `final_runtime_table.csv`.
If source benchmark is valid (IAE/VB-FQ/E-FQ only, common packet, 100 repeats,
no TRM/EQ), preserve current values; do not rerun unnecessarily.

## 8. Raw data integrity

Do not modify:
- `results/paper/paper2_ber_validation_3000mc.mat`
- `results/paper/paper2_stress_pilot_3000mc.mat`
- checkpoints

Re-run deterministic audit only and keep:
BER_SHAPE_PASS
STRESS_SHAPE_PASS
SUMMARY_RECOMPUTE_PASS
MECHANISM_COMPLETENESS_PASS
CHECKPOINT_COUNT_PASS

Use git diff/hash to confirm raw MAT files are unchanged in Round-10.2.

## 9. Final status semantics

The current claim `FINAL_PUBLICATION_ARTIFACTS_COMPLETE` is NOT accepted until:
- consistency CSV = 72 data rows;
- Fig source rows = 63,63,9,3,6;
- figure-object audit passes;
- all new tests pass.

If all pass:

FINAL_3000MC_DATA_AUDITED
FINAL_PUBLICATION_ARTIFACTS_COMPLETE
READY_FOR_MANUSCRIPT_DRAFTING
NO FURTHER PARAMETER TUNING

Otherwise:

FINAL_3000MC_DATA_AUDITED
FINAL_PUBLICATION_ARTIFACTS_INCOMPLETE
MANUSCRIPT_FIGURE_STAGE_BLOCKED

Update PAPER_CODE_ALIGNMENT.md only after genuine pass:
- Final post-processing audit: COMPLETE
- Figure source-data audit: PASS
- Pilot→Paper consistency audit: PASS

## Required Codex report

Report:
- base/new commit and changed files;
- 3000-MC BER rerun = NO;
- 3000-MC Stress rerun = NO;
- Pilot rerun = NO;
- parameter changes = NO;
- verbose Profile -> P1/P2/P3 mapping;
- consistency row count = 72;
- two 1-dB threshold movements;
- four tracking effect ratios per profile;
- mechanism direction consistency;
- figure source row counts 63,63,9,3,6;
- figure scientific-object counts;
- bootstrap 12-row verification;
- all new tests PASS.

Final line:
`WAITING FOR MANUSCRIPT SCIENTIFIC AUDIT.`
