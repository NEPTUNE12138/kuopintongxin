# WUWNet Paper 2 — Round-10.3 Publication Figure Polish ONLY

Repository:
`NEPTUNE12138/kuopintongxin`

Base:
`7da693a68dd5b4f0959c639b93b2b773d0898c3b`

Scientific data basis:
`cda0964df2caf95ad03f9875d1e4dd47285f584a`

STATUS:
- 3000-MC raw data: ACCEPTED
- PAPER-1..6: PASS
- Pilot→Paper consistency: COMPLETE (72 rows)
- Bootstrap: COMPLETE (12 rows)
- Figure source-data row counts: PASS (63,63,9,3,6)
- No new simulations are authorized.

This round is publication-presentation polish ONLY.

DO NOT:
- rerun BER/Stress/Pilot
- modify any raw MAT/checkpoint
- change Q/c2/Kcal
- change algorithm/filter/reliability/VB/Early-Late
- change Bellhop/SNR/stress/seeds/variants
- change any final numerical result

## 1. Make canonical profile matching strict

Current `canonical_profile_id.m` uses `contains(raw_str,'P1')`, which would
incorrectly accept strings such as `P10`.

Replace with an anchored/exact mapping that accepts only:
- `P1`
- `P2`
- `P3`
- `Profile P1: Tx15m / 20km / Rx34m`
- `Profile P2: Tx15m / 20km / Rx3467m`
- `Profile P3: Tx100m / 45km / Rx110m`

Unknown strings (including `P10`, `XP1X`, `Profile P4`) must error.

Extend `test_canonical_profile_id.m` with these negative cases.

## 2. Fig1 FER must actually plot Wilson 95% intervals

The source CSV already contains:
- FER_Overall
- FER_Wilson_Lower
- FER_Wilson_Upper

But current code only calls `plot(...)`.

Modify `generate_paper2_figures.m` so Fig1 visibly draws Wilson intervals,
preferably with `errorbar`.

For log-y plotting:
- source CSV remains unchanged;
- preserve exact zero FER in source;
- when necessary use a documented positive display floor only for graphical
  coordinates;
- CI lower values that are zero must also receive graphical floor without
  modifying source data.

Keep:
3 profiles × 3 methods × 7 SNR.

## 3. Fig2 BER must actually plot Wilson 95% intervals

Same requirement for:
- BER_Valid
- BER_Wilson_Lower
- BER_Wilson_Upper

Use visible 95% interval bars/ranges rather than merely storing the CI columns.

## 4. Redesign Fig4 to avoid mixed-scale shared y-axis

Current Fig4 puts:
- reliability m
- R_eff/R_vb
- K_delay

on one shared quantitative axis for each profile.

Change to three metric panels:

Panel A:
`m` for P1/P2/P3 across PRE/FADE/POST.

Panel B:
`R_eff/R_vb` for P1/P2/P3 across PRE/FADE/POST.

Panel C:
`K_delay` for P1/P2/P3 across PRE/FADE/POST.

This prevents scale mixing.

Add a textual annotation or caption:
`Q11 = 0.05 and Q22 = 0.002 are fixed in all phases.`

Do NOT plot Q as a varying curve.

Keep Fig4 source CSV unchanged numerically:
3 rows, one per profile.

## 5. Enrich direction summary (no new statistics)

Current `pilot_paper_direction_summary.csv` contains only booleans.

Regenerate with the actual Pilot/Paper ratios plus booleans:

ProfileID,
EFQ_IAE_Overall_PilotRatio,
EFQ_IAE_Overall_PaperRatio,
EFQ_IAE_Overall_Consistent,
EFQ_IAE_Fade_PilotRatio,
EFQ_IAE_Fade_PaperRatio,
EFQ_IAE_Fade_Consistent,
EFQ_VBFQ_Overall_PilotRatio,
EFQ_VBFQ_Overall_PaperRatio,
EFQ_VBFQ_Overall_Consistent,
EFQ_VBFQ_Fade_PilotRatio,
EFQ_VBFQ_Fade_PaperRatio,
EFQ_VBFQ_Fade_Consistent,
Mechanism_m_Consistent,
Mechanism_ReffRvb_Consistent,
Mechanism_K_Consistent,
Q_Fixed_Consistent

3 rows only.

All ratios must be derived from existing Pilot/Paper tables, not hard-coded.

## 6. Strengthen figure audit

The current object audit is based on generation counters.

After figures are created, inspect actual axes/graphics handles before closing
and verify scientific objects really exist.

Required:
- Fig1: 9 FER data/errorbar series
- Fig2: 9 BER data/errorbar series
- Fig3: data for 3×3×2 method/metric combinations
- Fig4: 3 metric panels × 3 profile series
- Fig5: 6 paired-effect estimates

Exclude dummy legend objects.

Update:
`results/paper_review/final_figure_object_audit.txt`

## 7. Preserve all already-correct source row counts

They must remain exactly:
- Fig1 = 63
- Fig2 = 63
- Fig3 = 9
- Fig4 = 3
- Fig5 = 6
- pilot_paper_consistency = 72
- final_bootstrap_table = 12

Run all Round-10.2 regression tests plus the stricter canonical-profile tests.

## 8. Raw scientific files must remain untouched

Git diff from base must NOT include:
- `results/paper/paper2_ber_validation_3000mc.mat`
- `results/paper/paper2_stress_pilot_3000mc.mat`
- `results/paper/checkpoints/*`

No simulation execution.

## 9. Final status

If all presentation checks pass:

FINAL_3000MC_DATA_AUDITED
FINAL_PUBLICATION_FIGURES_POLISHED
READY_FOR_MANUSCRIPT_DRAFTING
NO FURTHER CODE/ALGORITHM DEVELOPMENT

Final line:
WAITING FOR MANUSCRIPT SCIENTIFIC AUDIT.
