# WUWNET Paper 2 — Round-4.1 Integrity & Falsification Before Pilot

Repository:
`NEPTUNE12138/kuopintongxin`

Start from:
`816b809786b0cc30f07266ac8e039226f84d8246`

This is a corrective verification round only.
DO NOT run Pilot.
DO NOT run Paper.
DO NOT tune parameters after seeing results.
DO NOT loosen the predeclared E-CAL acceptance thresholds.
DO NOT tune kappa_side.
DO NOT search seeds.

## 1. Fix the false CFAR unit-test assumption

Current `test_cfar_raw_detection_no_fallback.m` incorrectly assumes pure random noise must always produce zero OS detections.

Replace it with two deterministic semantic tests:

A. RAW-DETECTION case:
- create a deterministic synthetic signal where raw OS/Hybrid detection is nonempty;
- assert `fallback_used == false`;
- assert `final_mask` equals the raw hybrid mask;
- assert raw counts are unchanged by final output logic.

B. FORCED-NO-RAW case:
- do NOT rely on random noise;
- create a deterministic input/configuration for which raw hybrid mask is empty;
- assert raw_os/raw_hybrid masks and counts remain empty;
- assert `fallback_used == true`;
- assert final_path_count == 1;
- assert fallback changes only the final operational mask, never raw detection statistics.

The purpose is to test separation semantics, not a probabilistic claim.

## 2. Fix matched-filter diagnostic window bounds

In BOTH:
- `src/diagnose_cfar_detection.m`
- `src/diagnose_trm_contribution.m`

replace the incorrect cap:

```matlab
win_end = min(length(rx_noisy), peak_idx + 200);
```

with a cap against the matched-filter array:

```matlab
win_end = min(length(g_raw), peak_idx + 200);
```

Also audit receiver code:
when slicing `sync_meta.mf`, cap against `length(sync_meta.mf)`, not input-signal length.

Add a unit test verifying a matched-filter peak near the end of the received preamble can still obtain the intended post-peak diagnostic window when `g_raw` is longer than `rx_noisy`.

## 3. Freeze Bellhop local-cluster policy explicitly in config

Add:

```matlab
cfg.bellhop_cluster_gap_s = 0.05;
cfg.channel_model = 'bellhop_local_cluster';
```

No hidden default is allowed for publication runs.

Keep the existing deterministic earliest-cluster rule.
Keep reporting retained energy:

P1 ~75.77%
P2 ~62.92%
P3 ~99.79%

Do not optimize cluster selection using BER.

All Validation / Stress / diagnostics / Pilot must use:
`select_bellhop_local_cluster` + `conv(...,'full')`.

## 4. Fix result paths

`diagnose_hvb_failure.m` currently writes under `src/results/...` depending on CWD.

Make every script use:

```matlab
project_root = ...
out_dir = fullfile(project_root,'results',...)
```

No `src/results` artifacts should be produced.

## 5. Run the E-CAL falsification at the PREDECLARED sample size

Run exactly 50 MC per S0-S3.

Compare:
- C
- E-original
- E-VB-only
- E-CAL

Do not change:
```matlab
cfg.c2 = 1/50;
Kcal = 8;
```

Use the already-correct true fade masks.

The acceptance thresholds remain exactly:

Normal:
```text
median(m) >= 0.90
median(R_eff/R_vb) <= 1.15
```

Fade:
```text
m_fade < m_pre
(R_eff/R_vb)_fade > (R_eff/R_vb)_pre
K_fade < K_pre
```

Dynamic:
```text
RMSE_ECAL_S1 <= 1.25 * RMSE_C_S1
RMSE_ECAL_S3 <= 1.25 * RMSE_C_S3
```

Do NOT weaken 1.25 after seeing the data.

Also report, but do NOT make it a retroactive gate:
```text
RMSE ratios E-CAL/C for S0,S1,S2,S3
```

If E-CAL fails either dynamic criterion at 50 MC:
print exactly:

```text
ECAL_NOT_ACCEPTED_FOR_FINAL_METHOD
```

and do not promote it.

If it passes:
print:

```text
ECAL_MECHANISM_GATE_PASS
```

but do not yet claim performance superiority.

## 6. Correct pipeline stop logic

Refactor diagnostics to RETURN decision structs, e.g.:

```matlab
hvb_decision = diagnose_hvb_failure('freeze');
cfar_decision = diagnose_cfar_detection('freeze');
```

`run_paper2_full_pipeline('quick')` must NOT blindly continue.

Required order:

1. all unit/integration gates
2. local-cluster report
3. 50-MC E-CAL freeze diagnostic
4. corrected CFAR calibration
5. only if relevant gates pass: c2 sensitivity / TRM diagnostic / boundary scan
6. final Quick Validation/Stress after frozen method selection

If E-CAL fails:
stop before c2 finalization and publication Validation/Stress.

If CFAR fails:
do not stop the Bayesian tracker work, but set:
```text
TRM_PRIMARY_CONTRIBUTION = false
```
and skip claims of hybrid focusing benefit.

## 7. Re-run CFAR calibration after the window-bound fix

Run 30 MC, not 5.

Grid remains exactly:

```matlab
Pfa = [1e-2 1e-3 1e-4];
Order = [0.50 0.75];
SNR = [-10 0];
```

No kappa tuning.

Selection rule remains:
- minimum/required recall >= 0.90 across all profiles at 0 dB;
- among valid candidates, lowest false detections.

If none passes:
print:

```text
CFAR_EXTRACTION_FAILURE
HYBRID_TRM_NOT_SUPPORTED_AS_PRIMARY_CONTRIBUTION
```

Do not “rescue” CFAR by changing the rule after seeing results.

If one passes:
freeze selected Pfa/order in config and then rerun Hybrid diagnostic with raw masks.

## 8. Do NOT use zero-filter focusing metrics as evidence

In TRM diagnostic, when raw OS/Hybrid mask is empty:
- RMS_OS/RMS_Hyb = NaN
- Peak_OS/Peak_Hyb = NaN
- PSLR_OS/PSLR_Hyb = NaN
- mark extraction failure

Never report:
```text
RMS=0, Peak=0, PSLR=100
```
for an all-zero q; that is not successful focusing.

## 9. c2 selection only if E-CAL passes

If and only if E-CAL passes the 50-MC gate:
run E-CAL factorial with 20 MC per condition.

Use the existing minimax rule.

Do not change the rule:
if c2=0.02 worst-case normalized loss is within 10% of minimax optimum, retain 0.02.

Write the final value statically into config and add:

```matlab
cfg.final_tracker_variant = 'E-CAL';
cfg.c2_frozen = true;
```

If E-CAL fails:
do not run/freeze c2 and set:

```matlab
cfg.final_tracker_variant = 'UNRESOLVED';
cfg.c2_frozen = false;
```

## 10. Publication Validation/Stress must use the frozen method

Current Validation uses `E`, and Stress uses `E`.
Do not run Pilot with that.

After a final tracker is accepted, map publication Variant E explicitly to the frozen implementation.

Preferred implementation:
`paper2_variant_definition('E')` remains the publication label, but receiver behavior follows a config field such as:

```matlab
cfg.reliability.mode = 'relative_calibrated';
```

Do not keep publication method hidden under a diagnostic label `E-CAL`.

If E-CAL is rejected:
do not silently map E to E-CAL.

## 11. Fix Stress experimental definition

`main_WUWNET_Paper_Stress.m` must:
- call `apply_paper2_time_warp`;
- use actual symbol-level fade masks;
- NOT use first/middle/final thirds;
- export PRE/FADE/POST from the physical fade envelope;
- export `R_eff/R_vb` in addition to absolute R_eff.

## 12. Update alignment honestly

Until this round is resolved:

```text
Round-4 Algorithm Freeze: PARTIAL
Full Quick Pipeline: FAILED / NOT COMPLETE
E-CAL final method: UNDER FALSIFICATION
c2 final: NOT FROZEN
OS-CFAR: UNDER CALIBRATION
Hybrid TRM primary contribution: NOT VERIFIED
Bellhop local-cluster model: VERIFIED
Pilot: NOT RUN
Paper: NOT RUN
```

Do not mark Hybrid TRM/OS-CFAR VERIFIED from unit tests alone.

## 13. Required final report

Return:

### Gate status
- all tests
- full Quick success/failure

### E-CAL 50-MC
For S0-S3:
- C RMSE
- E-original RMSE
- E-VB-only RMSE
- E-CAL RMSE
- E-CAL/C ratio
- PRE/NORMAL m, Reff/Rvb, K
- FADE m, Reff/Rvb, K
- exact gate PASS/FAIL

### CFAR 30-MC
Per candidate:
- recall
- precision
- false detections
- fallback rate
- selected config or explicit failure

### TRM decision
- SUPPORTED
or
- NOT SUPPORTED AS PRIMARY CONTRIBUTION

### Cluster model
- selected path count
- retained energy ratio
- max cluster excess delay

### Frozen state
- final tracker variant
- c2
- CFAR settings or demotion
- SNR grid only if boundary scan legitimately rerun

Final line:
`PILOT NOT RUN — waiting for review.`

Important:
If E-CAL fails 50-MC, STOP algorithm freezing and do not invent a replacement in this round.
We will design the next tracker mechanism separately.
