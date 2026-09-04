# Final Code Audit: R-FQ Ablation

## Scope

Formal paired R-FQ ablation for WUWNet'26 Paper 2 using P1/P2/P3 and 3000 Monte Carlo trials per profile.

## Files modified for this formal run

- `src/run_RFQ_ablation_final.m`
  - Added deterministic threaded execution and 100-trial checkpoints.
  - Added per-trial overall RMSE, fade RMSE, bit-error count, BER, FER, and validity capture.
  - Added 2000-resample paired bootstrap analysis.
  - Added CSV, LaTeX table, PDF figure, and Markdown report generation.

## R-FQ implementation files already present before this formal run

- `lib/reliability_only_delay_tracker.m`
- `lib/run_paper2_receiver_variant.m`
- `lib/paper2_variant_definition.m`
- `src/main_WUWNET_Paper_Stress.m`
- `tests/test_reliability_only_delay_tracker.m`

These implementation files were not modified during the formal rerun.

## New experiment artifacts

- `RFQ_ablation_final_raw.mat`
- `RFQ_ablation_final_summary.csv`
- `RFQ_ablation_bootstrap_CI.csv`
- `tables/Table_RMQ_absolute.tex`
- `tables/Table_RMQ_improvement.tex`
- `Fig_RMQ_ablation.pdf`
- `Fig_RMQ_difference_CI.pdf`
- `RFQ_ABLATION_FINAL_REPORT.md`
- `FINAL_CODE_AUDIT.md`

The earlier formal artifact set was preserved under `archive_prior_20260904_2116/`; no file was overwritten.

## Protected-core verification

- `lib/hvb_akf_delay_tracker.m`: no git diff.
- `lib/hvb_akf_delay_tracker.m` SHA-256 before and after: `E1856C5B497BE877633C73D5443CC67C984EA00FB2749E992674F225001DAC93`.
- `lib/reliability_only_delay_tracker.m` SHA-256 before and after: `0F205A8BB4D4E020BC874D50A7C7BACBB5AF43AACCB1A37AD31932679E1FCE9A`.
- `lib/run_paper2_receiver_variant.m` SHA-256 before and after: `4FBD27EB71E1CED547AF947CCBA952B6FD5A3F4534AE1DEE77FBDA8C8DFC4E69`.
- E-FQ frozen recursion was not modified.
- Manuscript LaTeX was not modified. The `.tex` files under `results/.../tables/` are newly generated result tables only.
- `results/paper2_final/` was absent before the run and remains absent; it was neither created nor modified.
- At formal-experiment completion, no commit or push had been performed. A later user-authorized upload may commit this audited file set; that upload is recorded by Git history rather than changing the experiment data.

## Data-integrity verification

- Raw table rows: 36,000 = 3 profiles × 3000 trials × 4 methods.
- Valid rows: 36,000/36,000.
- All overall RMSE, fade RMSE, BER, and FER entries passed finiteness/schema checks.
- Master seed: 20260823.
- Paired seed formula: `master_seed + trial_id + 999000 + profile_index*10000`.
- Bootstrap: 2000 paired percentile resamples.

## Result location

`results/paper_strengthening/RFQ_ablation/final/`
