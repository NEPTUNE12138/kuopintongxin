# R-FQ Ablation Final Report

## 1. Experimental objective

Separate the contribution of VB measurement-noise adaptation from receiver-derived reliability scaling in E-FQ.

## 2. Code changes

- Added/updated only `src/run_RFQ_ablation_final.m` for parallel execution, checkpointing, trial-level BER/FER capture, paired bootstrap analysis, tables, figures, and reporting.
- Tracker recursion files and manuscript LaTeX were not modified.

## 3. Experimental parameters

- Profiles: P1, P2, P3
- N_MC: 3000 per profile
- Master seed: 20260823
- Q: diag([0.05, 0.002]); c2: 0.020000; N_vb: 4
- frontend.use_trm: false; equalizer.enabled: false
- Methods: IAE, VB-FQ, R-FQ, E-FQ

## 4. Statistical method

Each trial generates bits, Bellhop-channel output, time warp, fade, and AWGN once, then passes that shared observation to all four receivers. Differences are E-FQ minus comparator. Confidence intervals are percentile 95% paired-bootstrap intervals with 2000 resamples. Negative RMSE differences favor E-FQ.

## 5. Main results

- E-FQ vs VB-FQ: median difference -0.0111 samples, 95% CI [-0.0115, -0.0106], median improvement 3.21%. Absolute pooled medians: E-FQ 0.3130, VB-FQ 0.3232.
- E-FQ vs R-FQ: median difference -0.1745 samples, 95% CI [-0.1751, -0.1738], median improvement 35.16%. Absolute pooled medians: E-FQ 0.3130, R-FQ 0.4912.
- E-FQ vs IAE: median difference -0.0905 samples, 95% CI [-0.0912, -0.0896], median improvement 21.83%. Absolute pooled medians: E-FQ 0.3130, IAE 0.4035.

## 6. Direct answers

**Question 1: Does reliability alone improve tracking?** No against the IAE benchmark: R-FQ has higher median RMSE in all three profiles. Reliability scaling alone is insufficient.

**Question 2: Does VB alone improve tracking?** Yes: VB-FQ has lower median RMSE than IAE in all three profiles.

**Question 3: Does combining VB and reliability provide additional gain?** Yes. E-FQ improves over both VB-FQ and R-FQ, and the paired CI versus each excludes zero. The E-FQ vs VB-FQ contrast isolates the incremental reliability gain in the presence of VB.

## 7. Suggested paper interpretation

The dominant gain comes from VB measurement-noise adaptation. Reliability-only scaling does not outperform IAE by itself, but reliability provides a smaller, statistically resolved incremental gain when coupled with VB, especially during the fade interval. Describe this as complementary gain rather than a formal factorial interaction, because KF-FQ was not included in the specified four-method analysis.
