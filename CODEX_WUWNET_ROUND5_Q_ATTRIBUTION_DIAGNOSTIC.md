# WUWNET Paper 2 — Round-5 Uncertainty-Attribution Diagnostic

Repository:
`NEPTUNE12138/kuopintongxin`

Start from commit:
`a652dfa3a6e1134f31cc5e687d21271bd15f0a3a`

This round is a ROOT-CAUSE diagnostic, not Pilot and not final parameter tuning.

## Scientific status entering this round

The predeclared 50-MC E-CAL gate has now been executed.

50-MC median tracking RMSE:
- S0 Static: C=0.4503, E-original=0.3929, E-VB-only=0.6477, E-CAL=0.6321
- S1 Warp: C=0.5392, E-original=2.3144, E-VB-only=0.7313, E-CAL=0.6859
- S2 Fade: C=0.4271, E-original=0.3518, E-VB-only=0.6406, E-CAL=0.5803
- S3 Warp+Fade: C=0.5381, E-original=2.3340, E-VB-only=0.7200, E-CAL=0.6633

Predeclared dynamic gate:
`RMSE_ECAL <= 1.25 * RMSE_C`

S1 ratio = ~1.272 -> FAIL.
S3 ratio = ~1.233 -> PASS.

Therefore:
`ECAL_NOT_ACCEPTED_FOR_FINAL_METHOD`

Do NOT change the 1.25 threshold.
Do NOT promote E-CAL.
Do NOT tune c2.
Do NOT run Pilot.
Do NOT run Paper.

The key remaining hypothesis is uncertainty attribution / Q adaptation:
- E-CAL S1 median K_delay ≈ 0.912
- E-CAL S1 median Q11 ≈ 1.118
- E-CAL S1 median Q22 ≈ 0.0469
while initial Q is `[0.05, 0.002]`.
Thus E-CAL is no longer over-conservative; adaptive Q becomes much larger and the filter becomes too responsive to discriminator measurements.

We must diagnose this before inventing a new final method.

---

# PART 0 — Preserve scientifically valid fixes

Keep:
- Bellhop earliest local-cluster policy
- `cfg.bellhop_cluster_gap_s = 0.05`
- `cfg.channel_model = 'bellhop_local_cluster'`
- normalize cluster AFTER selection
- `conv(...,'full')` channel application
- Variant D `A=50`, `b=8`
- physical `apply_paper2_time_warp`
- real fade masks
- deterministic seeds
- E-CAL 8-symbol relative calibration implementation
- all existing valid tests

Do not alter the frozen Paper-1 archive.

---

# PART 1 — Fix the CFAR window bug FOR REAL

The latest code still contains the old bug in BOTH:
- `src/diagnose_cfar_detection.m`
- `src/diagnose_trm_contribution.m`

Current wrong line:
```matlab
win_end = min(length(rx_noisy), peak_idx + 200);
```

This MUST be removed.

## 1.1 Centralize window extraction

Create:
`lib/extract_mf_local_window.m`

Suggested interface:
```matlab
[g_win, win_start, win_end] = extract_mf_local_window(mf, peak_idx, n_pre, n_post)
```

Implementation:
```matlab
win_start = max(1, peak_idx - n_pre);
win_end   = min(length(mf), peak_idx + n_post);
g_win = mf(win_start:win_end);
```

Use this SAME helper in:
- `run_paper2_receiver_variant.m`
- `diagnose_cfar_detection.m`
- `diagnose_trm_contribution.m`
- any TRM ablation that slices the matched-filter output

No duplicated window-bound logic.

## 1.2 Replace the fake integration test

Current `test_mf_diagnostic_window_bounds.m` merely re-implements the correct expression locally; it can pass while the real diagnostic scripts are still wrong.

Rewrite the test to call `extract_mf_local_window` directly and verify:
- `length(mf) > length(rx_noisy)` style case
- peak near end of rx but not end of mf
- requested post-peak samples are retained when available in mf
- `win_end <= length(mf)`

Add this test to `run_paper2_full_pipeline`.

Search repository for:
```text
min(length(rx_noisy), peak_idx + 200)
min(length(sig_pb), peak_idx + 200)
```
and eliminate all matched-filter window uses that cap against the wrong array.

---

# PART 2 — One final CFAR falsification

After Part 1 only, rerun:
`diagnose_cfar_detection('freeze')`

Use exactly:
- 30 MC
- Pfa `[1e-2,1e-3,1e-4]`
- Order `[0.50,0.75]`
- SNR `[-10,0]`
- all 3 local Bellhop clusters
- no kappa tuning
- raw masks, not fallback

Predeclared pass rule remains:
minimum recall >= 0.90 across all three profiles at 0 dB.

If no configuration passes:
set a persistent config/document flag:
```matlab
cfg.trm_primary_contribution = false;
```

and print:
```text
CFAR_EXTRACTION_FAILURE
HYBRID_TRM_NOT_SUPPORTED_AS_PRIMARY_CONTRIBUTION
```

Do not perform another rescue/tuning round.
The operational strongest-path fallback may remain for receiver continuity, but manuscript claims must treat TRM as a conventional/safety front-end, not a primary innovation.

If a configuration passes:
freeze Pfa/order and run Hybrid-vs-OS diagnostic.
Do not tune kappa.

---

# PART 3 — Expose the missing Bayesian innovation telemetry

Modify `lib/hvb_akf_delay_tracker.m` to return, for every symbol:

```matlab
meta.innovation = z_k - H*x_pred;
meta.S = H*P_pred*H' + R_eff;
meta.NIS = meta.innovation^2 / max(meta.S, eps);
meta.P_pred_diag = diag(P_pred);
```

The tracker currently receives `u_k` and `u_prev` but does not use them.
Do NOT invent a use for them in this round.

Propagate these histories into `run_paper2_receiver_variant.m`.

Remove the current diagnostic placeholder:
```matlab
abs_innovation = NaN(...)
```

and export real values.

---

# PART 4 — Add innovation-consistency telemetry, but DO NOT use it to control the filter yet

We first need evidence.

For each receiver trial, maintain a W=5 rolling innovation window.

For valid windows calculate:

## Directional consistency
```matlab
d_k = abs(sum(nu_window)) / (sum(abs(nu_window)) + eps);
```

Range [0,1]:
- high: innovations persist in one direction
- low: innovations alternate / are incoherent

## Coherent energy fraction
```matlab
mu_nu = mean(nu_window);
var_nu = var(nu_window, 1);
coherent_fraction = mu_nu^2 / (mu_nu^2 + var_nu + eps);
```

## NIS statistics
Use the tracker-provided NIS.

Store:
```text
innovation
abs_innovation
NIS
directional_consistency
coherent_fraction
```

Do not feed any of these back into R or Q in this round.

---

# PART 5 — Structural-Q ablation: identify the remaining failure source

Add diagnostic-only tracker modes.

Do NOT replace publication Variant E.

Use E-CAL reliability in all four diagnostic variants below.

### EQ0 — current
Current E-CAL:
- heteroscedastic relative reliability
- current adaptive Q11 + Q22

### EQ1 — fixed Q
Keep:
```matlab
Q = diag([0.05, 0.002])
```
for the whole packet.

No Q adaptation.

### EQ2 — Q22-only
Keep:
```matlab
Q11 = 0.05
```
fixed.

Allow only Q22 to adapt using the CURRENT existing Q estimator/update rule.

### EQ3 — Q11-only
Keep:
```matlab
Q22 = 0.002
```
fixed.

Allow only Q11 to adapt using the CURRENT existing Q estimator/update rule.

These are diagnostic variants only.
Do not put EQ0-EQ3 into final A/B/C/D/E publication labels.

Implement via explicit diagnostic config:
```matlab
cfg.hvb.q_adaptation_mode = 'both' | 'fixed' | 'q22_only' | 'q11_only';
```

Default current behavior remains `'both'`.

---

# PART 6 — Run a 50-MC Q-attribution diagnostic

Create:
`src/diagnose_hvb_q_attribution.m`

Use the exact same four S0-S3 impairment scenarios and exact same seed sharing.

Variants:
- C
- E-original (reference)
- EQ0 E-CAL current
- EQ1 E-CAL fixed-Q
- EQ2 E-CAL Q22-only
- EQ3 E-CAL Q11-only

Exactly 50 MC per scenario.

Same Bellhop P1 local cluster.
Same 15 dB diagnostic SNR.
Same true timing trajectory.
Same true fade masks.

For every variant/scenario export:
- median RMSE
- mean RMSE
- median tracking bias
- BER
- valid rate
- K_delay median/P10/P90
- R_vb
- R_eff/R_vb
- Q11
- Q22
- innovation median magnitude
- NIS median/P90
- directional_consistency median
- coherent_fraction median

For fade scenarios export PRE / FADE / POST separately.

Save:
```text
results/diagnostic/q_attribution_summary.csv
results/diagnostic/q_attribution_phase_stats.csv
results/diagnostic/q_attribution_raw.mat
```

---

# PART 7 — Predeclared classification

Do not choose a winner by visual inspection.

For each EQ variant compute:
```text
ratio_S0 = RMSE / RMSE_C
ratio_S1 = RMSE / RMSE_C
ratio_S2 = RMSE / RMSE_C
ratio_S3 = RMSE / RMSE_C
```

Classify:

## Q_ADAPTATION_PRIMARY_SUSPECT
YES if either fixed-Q or Q22-only:
- improves S1 by at least 10% relative to EQ0, AND
- does not worsen S3 relative to EQ0 by more than 10%.

## Q11_INFLATION_PRIMARY_SUSPECT
YES if Q22-only materially outperforms Q11-only in S1/S3 and keeps Q11 at baseline.

## VB_R_RECURSION_STILL_SUSPECT
YES if fixed-Q and Q22-only remain nearly as poor as EQ0.

Also analyze innovation consistency:

Report whether, in S1 Warp:
```text
median directional_consistency
median coherent_fraction
```
are materially higher than in S0 Static and/or pure fade.

Do NOT invent a numerical threshold after seeing the result.
Just report distributions and effect sizes.

---

# PART 8 — Decision for the NEXT algorithm, not this round

This round must NOT implement a dynamic-consistency-gated final tracker.

At the end only recommend one of these evidence-based next paths:

### Path A — Structured process-noise attribution
If Q11 inflation is the main issue:
recommend a final design that keeps delay-position process noise bounded/fixed and routes coherent dynamics primarily through the drift state Q22.

### Path B — Reliability + dynamic-consistency gating
If innovation consistency clearly separates true warp from fade/noise:
recommend a new candidate where:
- reliability identifies measurement quality,
- innovation consistency identifies true persistent dynamics,
- measurement degradation inflates R,
- coherent motion updates process/drift uncertainty instead of being suppressed as bad measurement.

Do NOT implement this candidate until reviewed.

### Path C — Revisit VB R recursion
If fixed/structured Q does not solve the residual degradation:
stop and audit alpha/beta/R_vb dynamics.

---

# PART 9 — Pipeline integrity

Reorder `run_paper2_full_pipeline` so unresolved formal results are not generated first.

Required conceptual order:
1. unit/integration gates
2. local-cluster verification
3. final-method diagnostic/falsification
4. CFAR final falsification
5. only after a method is accepted/frozen: c2 selection, boundary scan
6. only after freeze: final Quick Validation and final Quick Stress

For now, because E-CAL is rejected:
- do not run c2 sensitivity as a final-selection step
- do not run boundary scan for a “final E”
- do not generate publication Validation/Stress pretending E is frozen

The pipeline should terminate with:
```text
FINAL_TRACKER_UNRESOLVED
PILOT_BLOCKED
```

---

# PART 10 — Documentation

Update `PAPER_CODE_ALIGNMENT.md`.

The upper claim table must not say VERIFIED for:
- Hybrid TRM efficacy
- OS-CFAR efficacy
- c2 final value
- reliability-aware final tracker

Use distinctions such as:
- IMPLEMENTED
- MECHANISM VERIFIED
- EFFICACY NOT VERIFIED
- REJECTED AS FINAL
- UNDER DIAGNOSTIC

Status should clearly say:
```text
Bellhop local-cluster model: VERIFIED
E-CAL: REJECTED AS FINAL BY 50-MC PREDECLARED GATE
Final tracker: UNRESOLVED
c2 final: NOT FROZEN
TRM primary contribution: pending one corrected CFAR rerun
Pilot: BLOCKED / NOT RUN
Paper: NOT RUN
```

Fix the typo:
`Paper: NOT RUNPipeline...`

---

# PART 11 — Required tests

Add/update tests:

1. `test_mf_diagnostic_window_bounds`
   - calls the centralized helper, not duplicated logic.

2. `test_hvb_q_modes`
   - fixed: Q remains exactly [0.05,0.002]
   - q22_only: Q11 remains exactly 0.05
   - q11_only: Q22 remains exactly 0.002
   - both: legacy behavior preserved

3. `test_hvb_innovation_telemetry`
   - innovation/S/NIS finite and correctly sized.

4. Existing noiseless/Bellhop/ground-truth gates must still pass.

---

# HARD STOP

DO NOT RUN:
```matlab
run_paper2_full_pipeline('pilot')
```

DO NOT RUN:
```matlab
run_paper2_full_pipeline('paper')
```

DO NOT change c2.
DO NOT promote E-CAL.
DO NOT change the 1.25 historical gate.
DO NOT implement the final dynamic-consistency tracker in this round.

---

# REQUIRED FINAL REPORT

## 1. Git
- commit SHA
- changed files

## 2. CFAR final rerun
- confirm window helper used everywhere
- 30-MC table
- PASS or permanent demotion decision

## 3. E-CAL historical gate
- explicitly state S1 ratio ~1.272 FAIL
- explicitly state final E remains UNRESOLVED

## 4. Q attribution
Table:
- C
- E-original
- EQ0
- EQ1
- EQ2
- EQ3
for S0-S3 RMSE and ratios.

## 5. Mechanism telemetry
S0-S3:
- Q11/Q22
- K
- R_eff/R_vb
- NIS
- directional consistency
- coherent fraction

## 6. Classification
- Q_ADAPTATION_PRIMARY_SUSPECT yes/no
- Q11_INFLATION_PRIMARY_SUSPECT yes/no
- VB_R_RECURSION_STILL_SUSPECT yes/no

## 7. Recommended next path
Only A, B, or C from Part 8.

## 8. Final line
`PILOT BLOCKED — final tracker unresolved; waiting for scientific review.`
