# WUWNET Paper 2 — Round-4 Algorithm Freeze Before Pilot

Repository:
`NEPTUNE12138/kuopintongxin`

Start from commit:
`9afba82c642521252f4d981a5baf7fbc44c758b3`

PURPOSE:
This round must freeze the scientifically defensible Paper-2 algorithm BEFORE any 200-MC Pilot.

Do NOT run Pilot.
Do NOT run Paper 3000.
Do NOT edit manuscript performance prose.
Do NOT optimize parameters to make Variant E win.
Do NOT search seeds.
Do NOT change the legacy frozen archive.

The Round-3 evidence has already shown:

1. `HETERO_PENALTY_SUSPECT = yes`
2. `RELIABILITY_SCALE_SUSPECT = no` under the old coarse thresholds
3. `VB_RECURSION_SUSPECT = no`
4. E-original is good in Static/Fade-only but catastrophically lags in Warp/Warp+Fade.
5. E-VB-only removes most of that catastrophic lag.
6. Absolute-reliability c2=1/50 is poor in all four factorial dynamic conditions.
7. Current TRM diagnostic has OS_PathCount=0 and relies on fallback single peaks; therefore current TRM evidence is NOT valid.

The goal of this round is to test calibrated relative reliability, fix the Bellhop local-cluster modeling, make CFAR/TRM detection genuinely operational, and then freeze the final algorithm.

---

# 0. Restore the verified baseline before any new experiment

The Round-3 config accidentally changed Variant-D parameters.

Restore exactly:

```matlab
cfg.var_D_A = 50;
cfg.var_D_b = 8;
```

These were the verified Round-2 values.

Do NOT change Variant D again in this round.

Add a regression assertion in a config test so these parameters cannot silently drift.

---

# 1. Correct the Round-3 diagnostic implementation

`diagnose_hvb_failure.m` currently computes `fade_mask` but does not actually use it in the exported statistics.

Fix this.

For scenarios with fade, derive symbol-level masks from:

```matlab
fade_env_at_symbol_centers < 0.5
```

Define:

- PRE: before first fade symbol
- FADE: fade symbols
- POST: after last fade symbol

For no-fade scenarios:
- use one phase called NORMAL
- do not fabricate PRE/FADE/POST

For each phase export:

```text
rho_raw
rho_relative if applicable
m
Lambda
R_vb
R_eff
R_eff/R_vb
K_delay
Q11
Q22
abs(innovation)
tracking_error
```

For every metric export:

```text
mean
median
P10
P90
```

Also export:
- RMSE
- BER
- valid trials

The current whole-packet-only summary is insufficient.

---

# 2. Always test E-CAL when HETERO_PENALTY_SUSPECT is true

Round-3 did not run E-CAL because RELIABILITY_SCALE_SUSPECT was false.

That decision rule is too restrictive.

New rule:

```text
If RELIABILITY_SCALE_SUSPECT == yes
OR HETERO_PENALTY_SUSPECT == yes
then run E-CAL.
```

Run E-CAL in all S0-S3 scenarios.

Use 50 MC per scenario for this Round-4 diagnostic, not 20.

Variants:

```text
C
E-original
E-VB-only
E-CAL
```

All share identical random realizations.

---

# 3. Keep c2=1/50 while testing E-CAL

Do NOT change c2 yet.

The point of E-CAL is to test whether relative reliability fixes the penalty law without changing c2.

Use:

```matlab
cfg.c2 = 1/50;
cfg.reliability.calibration_symbols = 8;
```

Raw reliability remains:

```matlab
rho_raw = abs(corr_p) / sqrt(Eseg*Ecode + eps);
```

Reference:

```matlab
rho_ref = median(rho_raw(1:Kcal));
```

After calibration:

```matlab
rho_relative = min(1, rho_raw / max(rho_ref, eps));
m = sqrt(rho_relative_k * rho_relative_prev);
```

During the first Kcal symbols:

```matlab
Lambda = 1;
no reliability Q-freeze;
```

At transition `k = Kcal+1`, ensure `rho_prev` is converted into the same RELATIVE scale before computing `m`.
Do not mix raw rho_prev with relative rho_k.

Preserve:

```matlab
meta.rho_raw
meta.rho_ref
meta.rho_relative
meta.m_reliability
```

---

# 4. E-CAL scientific acceptance gate

E-CAL may replace E-original as the proposed reliability metric only if ALL are true:

### Normal behavior
In S0 and normal portion of S1:

```text
median(m) >= 0.90
median(R_eff/R_vb) <= 1.15
```

The normal channel should not continuously inflate R.

### Fade response
In the true FADE region of S2/S3:

```text
median(m_fade) < median(m_normal)
median((R_eff/R_vb)_fade) > median((R_eff/R_vb)_normal)
median(K_fade) < median(K_normal)
```

### Dynamic tracking
For S1 Warp:

```text
RMSE_ECAL <= 1.25 * RMSE_C
```

For S3 Warp+Fade:

```text
RMSE_ECAL <= 1.25 * RMSE_C
```

and E-CAL must be materially better than E-original.

### Functional gates
- noiseless BER remains zero
- Bellhop smoke remains zero
- timing correlation positive/high
- no new sync instability

If E-CAL fails:
DO NOT silently change c2.
Stop and report failure.

---

# 5. Only after E-CAL passes, rerun c2 factorial on E-CAL

The Round-3 factorial result for absolute E is diagnostic evidence only.

Do not use it to choose final c2 because large c2 values simply disable the penalty.

If E-CAL passes, run factorial sensitivity using E-CAL:

```text
SNR: 0, 15 dB
velocity amplitude: 0.5, 1.5 m/s
20 MC each for diagnostic selection
```

Use broad c2 grid including exact 1/50:

```matlab
unique(sort([0.005 0.01 0.02 0.05 0.1 0.2 0.5 1 2 5]))
```

Parameter selection rule must be predeclared:

For each condition j, define normalized loss:

```matlab
L_j(c2) = RMSE_j(c2) / min_c2 RMSE_j(c2)
```

Then:

```matlab
J(c2) = max_j L_j(c2)
```

Choose the c2 minimizing worst-case normalized loss (minimax robustness).

Do NOT choose a value based on one best condition.

If c2=1/50 is within 10% of the minimax optimum, KEEP 1/50 for simplicity.
Otherwise report the minimax-selected value and freeze it BEFORE Pilot.

After selecting:
do not retune c2 again using Pilot or Paper results.

---

# 6. Fix the Bellhop physical-model problem before validating TRM

The Bellhop files contain arrival groups separated by seconds, while the Paper-2 packet is ~0.62 s and the preamble is 50 ms.

The current implementation constructs the full multi-second FIR but applies:

```matlab
filter(h_true,1,packet)
```

which silently truncates late arrival groups.

This must be made explicit and physically consistent.

Create:

```matlab
lib/select_bellhop_local_cluster.m
```

Input:
- full Bellhop metadata/arrivals
- cfg

Deterministic rule:

1. Sort arrivals by relative delay.
2. Start from the EARLIEST arrival.
3. Include all subsequent arrivals until the gap between consecutive arrivals exceeds:

```matlab
cfg.bellhop_cluster_gap_s = 0.05;
```

(50 ms, tied to the acquisition/preamble timescale).

Do not select a cluster based on which gives best BER.

Return:

```text
h_cluster
cluster_meta
```

including:

```text
selected arrival indices
selected delays
selected path count
selected energy
total energy
retained_energy_ratio
cluster max excess delay
full-channel max excess delay
```

Normalize the selected cluster AFTER selection.

All Paper-2 BER/Stress/TRM experiments must use the SAME local-cluster channel model.

The paper interpretation is:

> Bellhop-derived local arrival clusters after coarse packet acquisition.

Do NOT claim full multi-second Bellhop multipath is processed by the 50-ms preamble TRM.

---

# 7. Use full convolution for the selected local cluster

For channel application replace silent-length truncation:

```matlab
filter(h_cluster,1,tx)
```

with:

```matlab
conv(tx,h_cluster,'full')
```

or equivalent explicit zero-padding.

The receiver must see the complete tail of the selected local cluster.

Update timing metadata accordingly.

Re-run all end-to-end tests.

---

# 8. Current TRM diagnostic is invalid: remove fallback from evidence

Round-3 produced:

```text
OS_PathCount = 0
Hybrid_PathCount = 1
Jaccard = 1
```

This happened because OS raw detection found nothing and `extract_cir_hybrid` inserted a single strongest-peak fallback.

Therefore Jaccard=1 is not evidence of identical real detections.

Modify `extract_cir_hybrid.m` metadata to distinguish:

```text
raw_os_mask
raw_hybrid_mask
final_mask
fallback_used
fallback_index
raw_os_path_count
raw_hybrid_path_count
final_path_count
```

The fallback may remain as an operational safety mechanism for receiver continuity, but:

**fallback detections MUST NOT count as CFAR detections in the TRM scientific diagnostic.**

If raw detector finds zero paths, diagnostic must report:

```text
CFAR_EXTRACTION_FAILURE
```

not “Hybrid inactive”.

---

# 9. Add a genuine CFAR detection-calibration diagnostic

Create:

```matlab
src/diagnose_cfar_detection.m
```

Use the selected TRUE Bellhop local cluster, so true tap locations are known.

Use HFM matched-filter output.

For each true path, expected matched-filter peak location is known from:
- channel tap delay
- preamble matched-filter group shift

Allow matching tolerance equal to HFM mainlobe half-width.

Evaluate raw OS-CFAR before fallback.

Diagnostic grid:

```text
Pfa = [1e-2, 1e-3, 1e-4]
order = [0.50, 0.75]
```

Keep:

```text
kappa_side = 1.5
```

fixed.
Do NOT tune kappa.

For 3 profiles × SNR {-10,0} × 30 MC:
calculate:

```text
true-path recall
false detections per trial
precision
raw path count
fallback rate
```

Selection rule for OS-CFAR parameters:

Choose the configuration with:
1. median recall >= 0.90 across profiles at 0 dB;
2. among those, lowest median false detections;
3. if no configuration reaches 0.90 recall, declare OS-CFAR unsuitable and STOP TRM promotion.

Do not select using BER.

Freeze selected CFAR parameters before Pilot.

---

# 10. Re-run the Hybrid TRM diagnostic only after CFAR works

Using selected local clusters and frozen CFAR:

For each trial calculate RAW OS and RAW Hybrid masks.

Metrics:

```text
OS raw path count
Hybrid raw path count
true-path recall OS
true-path recall Hybrid
false positives OS
false positives Hybrid
Jaccard
ACF floor active fraction
```

Then create q from actual detected CIRs.

For focusing evidence use:

```matlab
h_eq_os  = conv(h_cluster_true, q_os);
h_eq_hyb = conv(h_cluster_true, q_hyb);
```

Metrics:

```text
RMS delay spread
Peak concentration within ±1 chip
PSLR
```

No fallback-based q may be used for the publication diagnostic.

Automatic conclusion:

### Hybrid supported
Only if Hybrid:
- preserves true-path recall within 5% of OS,
- reduces false detections or improves focusing in a consistent predefined set of conditions.

### Hybrid not independently supported
If OS and Hybrid are statistically indistinguishable or Hybrid degrades recall/focusing:
print:

```text
HYBRID_TRM_NOT_SUPPORTED_AS_PRIMARY_CONTRIBUTION
```

Do not tune kappa to rescue it.

In that case keep TRM only as a conventional front-end / robustness safeguard in the future manuscript.

---

# 11. Re-run BER boundary scan AFTER the algorithm/channel model is frozen

After:
- E-CAL decision
- c2 frozen
- local Bellhop cluster frozen
- CFAR frozen

run 20-MC boundary scan:

```matlab
SNR = -22:1:-8
```

Compare:
- C
- final E candidate

Export BOTH:

```text
conditional BER over valid frames
sync fail rate
FER
valid trials
```

For BER=1e-3, report only brackets, never fake interpolation through zero BER.

Use this scan only to choose Pilot SNR range.

Do not use its 20-MC values in the paper.

---

# 12. Suggested Pilot SNR-range decision rule

For each profile, find the region spanning approximately:

```text
BER 1e-1 down to <=1e-3
```

Then choose ONE common Pilot SNR grid covering all three profiles with modest margin.

Do not simply restore `-14:0` if the waterfall lies lower.

Write selected grid to config only after the boundary scan.

---

# 13. Fix Round-3 documentation status

Update `PAPER_CODE_ALIGNMENT.md`.

Until this Round-4 is complete:

```text
Hybrid TRM primary contribution: PARTIAL / UNDER DIAGNOSTIC
Reliability-aware HVB: PARTIAL / UNDER CALIBRATION
c2 final value: NOT FROZEN
Bellhop local-cluster model: PARTIAL
Pilot 200 MC: NOT RUN
Paper 3000 MC: NOT RUN
```

Do not mark algorithmic efficacy VERIFIED merely because unit tests pass.

---

# 14. Required tests

Add:

## test_variant_D_config_regression.m
Assert:
```matlab
cfg.var_D_A == 50
cfg.var_D_b == 8
```

## test_bellhop_cluster_selection.m
For all three current profiles:
- deterministic cluster selection
- at least one path
- retained energy in (0,1]
- cluster delay spread < full delay spread
- cluster max excess delay <= cluster-gap policy

## test_channel_full_convolution.m
Ensure delayed tail is not silently truncated.

## test_cfar_raw_detection_no_fallback.m
Ensure raw masks and fallback are separated.

## test_ECAL_scale_transition.m
Ensure the first post-calibration m uses relative-relative values, not raw-relative mixed scales.

Keep all existing tests.

---

# 15. Hard stop before Pilot

Round-4 may finish only when:

### HVB gate
- E-CAL tested with 50 MC S0-S3
- mechanism criteria passed OR explicitly failed
- final E candidate frozen
- final c2 frozen

### Channel gate
- local-cluster model frozen
- retained-energy ratios exported for all profiles
- no silent full-FIR truncation

### TRM gate
Either:
A. genuine raw CFAR works and Hybrid has quantified support,
OR
B. Hybrid is explicitly demoted and no unsupported benefit is claimed.

### SNR gate
- new boundary scan completed
- Pilot SNR grid frozen

DO NOT RUN PILOT.

---

# 16. Required completion report

Return:

## A. Git
- commit SHA
- diff summary

## B. Restored baseline
- Variant-D A,b values

## C. Bellhop local clusters
Per profile:
- full path count
- cluster path count
- cluster max delay
- retained energy ratio
- full max excess delay

## D. HVB 50-MC
For S0-S3:
- C RMSE
- E-original RMSE
- E-VB-only RMSE
- E-CAL RMSE
- phase-level m
- Lambda
- R_eff/R_vb
- K

Decision:
- final proposed E mode
- E-CAL PASS/FAIL

## E. c2
- factorial table for final E candidate
- minimax-selected c2
- whether 1/50 retained
- explicit statement: c2 frozen before Pilot

## F. CFAR calibration
Per candidate:
- recall
- precision
- false detections
- fallback rate
- selected Pfa/order

## G. Hybrid TRM
Per profile/SNR:
- true-path recall OS/Hybrid
- false positives OS/Hybrid
- raw path counts
- Jaccard
- RMS spread
- peak concentration
- PSLR

Decision:
- SUPPORTED
or
- NOT SUPPORTED AS PRIMARY CONTRIBUTION

## H. Boundary scan
Per profile:
- C 1e-3 bracket
- final E 1e-3 bracket
- sync-fail rate near waterfall

## I. Frozen Pilot config
- final SNR grid
- final c2
- final channel-cluster policy
- final CFAR settings
- final E mode

## J. Final line
`PILOT NOT RUN — algorithm frozen and waiting for review.`

Do not auto-run 200 MC.
