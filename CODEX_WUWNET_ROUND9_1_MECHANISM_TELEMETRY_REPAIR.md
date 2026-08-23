# WUWNET Paper 2 — Round-9.1 Mechanism Telemetry Repair & Paper Admission Recheck

Repository:
`NEPTUNE12138/kuopintongxin`

Start from Pilot result commit:
`61adf3a369da0b1f917e4b5cf558933d01130976`

Scientific state:
- 200-MC BER Pilot completed.
- 200-MC Stress Pilot completed.
- PILOT-1, PILOT-2, PILOT-3, PILOT-5, PILOT-6 are supported by the actual numerical evidence.
- PILOT-4 is NOT yet validly demonstrated because required PRE/FADE/POST mechanism telemetry is missing from the saved Stress results.
- 3000-MC Paper remains BLOCKED until this is repaired and independently rechecked.

THIS IS NOT AN ALGORITHM-DESIGN ROUND.

DO NOT:
- change Q
- change c2
- change Kcal
- change reliability equation
- change VB recursion
- change Early/Late spacing
- change SNR grid
- change Bellhop cluster policy
- change warp/fade parameters
- change random seeds
- rerun BER Pilot
- rerun CFAR
- rerun equalizer experiments
- run 3000-MC Paper
- alter any predeclared Pilot gate

---

# 0. Why Round-9.1 is required

Current `pilot_mechanism_table.csv` contains for E-FQ:

```text
Median_m_PRE       = NaN
Median_m_FADE      = NaN
Median_m_POST      = NaN

Median_Reff_Rvb_PRE  = NaN
Median_Reff_Rvb_POST = NaN

Median_K_PRE       = NaN
Median_K_POST      = NaN
```

Only FADE values currently survive for some quantities.

Current PILOT-4 code uses logic like:

```matlab
if ~isnan(m_m_f) && ~isnan(m_m_p) && ~(m_m_f < m_m_p)
    P4_pass = false;
end
```

Thus missing values do NOT fail the gate.

This is a vacuous PASS and must be corrected.

The predeclared PILOT-4 remains exactly:

```text
for E-FQ in every profile:

Median_m_FADE < Median_m_PRE
Median_R_eff_R_vb_FADE > Median_R_eff_R_vb_PRE
Median_K_FADE < Median_K_PRE

Median_Q11 == 0.05
Median_Q22 == 0.002
```

No condition may be removed or weakened.

---

# 1. Preserve existing Pilot results

Do NOT delete or overwrite the existing Round-9 raw files:

```text
results/pilot/paper2_ber_validation_20260823_230226.mat
results/pilot/paper2_ber_validation_20260823_230226.csv

results/pilot/paper2_stress_pilot_20260823_230235.mat
results/pilot/paper2_stress_summary_20260823_230235.csv
```

Do NOT rerun the 200-MC BER Validation.

The Round-9 BER/FER evidence remains frozen.

The tracking/bootstrap values from the original 200-MC Stress are also preserved as historical evidence.

Round-9.1 may rerun ONLY the 200-MC Stress experiment under exactly identical conditions/seeds in order to save missing telemetry.

---

# 2. Add complete per-phase telemetry to Stress result storage

Modify:

```text
src/main_WUWNET_Paper_Stress.m
```

For every valid trial and every variant, using the already-computed physical masks:

```matlab
pre_idx
fade_idx
post_idx
```

store per-trial phase summaries.

Required arrays:

```text
m_pre
m_fade
m_post

Reff_Rvb_pre
Reff_Rvb_fade
Reff_Rvb_post

K_pre
K_fade
K_post

Q11_pre
Q11_fade
Q11_post

Q22_pre
Q22_fade
Q22_post
```

Use receiver telemetry:

```matlab
meta.m_reliability
meta.R_eff
meta.R_vb
meta.K_gain(1,:)
meta.Q_diag
```

For each trial use phase MEDIANS:

```matlab
results...m_pre(mc) =
    median(meta.m_reliability(pre_idx), 'omitnan');

results...m_fade(mc) =
    median(meta.m_reliability(fade_idx), 'omitnan');

results...m_post(mc) =
    median(meta.m_reliability(post_idx), 'omitnan');

ratio = meta.R_eff ./ max(meta.R_vb, eps);

results...Reff_Rvb_pre(mc) =
    median(ratio(pre_idx), 'omitnan');

results...Reff_Rvb_fade(mc) =
    median(ratio(fade_idx), 'omitnan');

results...Reff_Rvb_post(mc) =
    median(ratio(post_idx), 'omitnan');

results...K_pre(mc) =
    median(meta.K_gain(1,pre_idx), 'omitnan');

results...K_fade(mc) =
    median(meta.K_gain(1,fade_idx), 'omitnan');

results...K_post(mc) =
    median(meta.K_gain(1,post_idx), 'omitnan');
```

Likewise Q11/Q22 phase medians from `meta.Q_diag`.

Do NOT use P_pred as Q.

Keep older mean fields if needed for backward compatibility, but the mechanism gate must use these new phase-median fields.

---

# 3. Telemetry completeness assertions

For E-FQ, every VALID Stress trial must have finite:

```text
m_pre
m_fade
m_post

Reff_Rvb_pre
Reff_Rvb_fade
Reff_Rvb_post

K_pre
K_fade
K_post

Q11_pre/fade/post
Q22_pre/fade/post
```

Add:

```matlab
test_pilot_mechanism_telemetry_complete
```

The test must execute a real E-FQ receiver trial and assert:
- all required receiver meta vectors exist;
- phase masks are non-empty;
- all phase summaries above are finite.

Do not accept NaN as a valid value.

---

# 4. Correct PILOT-4 gate semantics

In:

```text
src/analyze_paper2_pilot.m
```

PILOT-4 must use FAIL-CLOSED semantics.

For each profile:

```matlab
required = [m_pre, m_fade, rr_pre, rr_fade, ...
            K_pre, K_fade, Q11, Q22];

if any(~isfinite(required))
    P4_pass = false;
    mechanism_status = 'PILOT4_MISSING_TELEMETRY';
end
```

Only after completeness is established check:

```matlab
m_fade < m_pre
rr_fade > rr_pre
K_fade < K_pre
abs(Q11 - 0.05) <= tolerance
abs(Q22 - 0.002) <= tolerance
```

Use tolerance:

```matlab
1e-6
```

for Q.

No NaN-skipping logic is allowed in gate admission.

---

# 5. Rerun ONLY the Stress Pilot

Use exactly:

```text
SNR = 15 dB
MC = 200
Profiles = P1/P2/P3
Variants = IAE/VB-FQ/E-FQ

warp v0 = 0.5 m/s
warp amp = 1.5 m/s
warp frequency = 0.2 Hz
phase = 0

fade = frozen 100-ms Gaussian deep fade

same master seed
same trial seed rule
same Bellhop local clusters
same frozen algorithm
```

Do NOT rerun BER.

Save the new telemetry-complete Stress run as a new timestamped MAT/CSV.

Do not overwrite the original Round-9 Stress MAT.

---

# 6. Deterministic reproduction check

Because the Stress rerun uses the exact same seeds and algorithm, its tracking results must reproduce the original Round-9 Pilot.

Compare old vs new for all Profile × Variant:

```text
RMSE_Overall_Median
RMSE_PRE_Median
RMSE_FADE_Median
RMSE_POST_Median
BER_Valid
FER_Overall
```

Expected:
- identical or floating-point-equivalent results.

Use tolerance:

```text
absolute difference <= 1e-10
```

for raw deterministic arrays when possible.

If the implementation change only adds telemetry and all algorithm input/output is untouched, the rerun should be deterministic.

If tracking metrics do NOT reproduce:

```text
ROUND9_1_REPRODUCTION_FAILURE
PAPER_BLOCKED
```

Do not continue.

Create:

```text
results/pilot_review/pilot_stress_reproduction_check.csv
```

Columns:

```text
Profile
Variant
Metric
OldValue
NewValue
AbsDifference
Pass
```

---

# 7. Regenerate mechanism table from telemetry-complete run

Regenerate:

```text
results/pilot_review/pilot_mechanism_table.csv
```

Required columns:

```text
Profile
Variant

Median_m_PRE
Median_m_FADE
Median_m_POST

Median_Reff_Rvb_PRE
Median_Reff_Rvb_FADE
Median_Reff_Rvb_POST

Median_K_PRE
Median_K_FADE
Median_K_POST

Median_Q11_PRE
Median_Q11_FADE
Median_Q11_POST

Median_Q22_PRE
Median_Q22_FADE
Median_Q22_POST
```

For each cell:
- first compute the per-trial phase median;
- then report the median across the 200 valid trials.

No required E-FQ mechanism field may be NaN.

---

# 8. Do NOT recompute already-valid BER evidence from another random run

Use the original Round-9 BER evidence unchanged:

```text
pilot_ber_summary.csv
pilot_transition_thresholds.csv
```

Already-audited threshold evidence:

```text
P1:
IAE   SNR50=-15, SNR05=-12
E-FQ  SNR50=-15, SNR05=-12

P2:
IAE   SNR50=-12, SNR05=-10
E-FQ  SNR50=-13, SNR05=-10

P3:
IAE   SNR50=-15, SNR05=-13
E-FQ  SNR50=-15, SNR05=-12
```

Thus E-FQ minus IAE:

```text
P1: Delta SNR50 =  0 dB, Delta SNR05 = 0 dB
P2: Delta SNR50 = -1 dB, Delta SNR05 = 0 dB
P3: Delta SNR50 =  0 dB, Delta SNR05 = +1 dB
```

These satisfy the predeclared ±1-dB non-inferiority requirement.

Do not alter the threshold rule.

---

# 9. Preserve already-supported tracking evidence

Original Round-9 200-MC Stress results:

```text
P1:
IAE overall = 0.5365
VB-FQ       = 0.4870
E-FQ        = 0.4730

IAE fade    = 0.5401
VB-FQ fade  = 0.4929
E-FQ fade   = 0.4501
```

```text
P2:
IAE overall = 0.4016
VB-FQ       = 0.3214
E-FQ        = 0.3120

IAE fade    = 0.4297
VB-FQ fade  = 0.3429
E-FQ fade   = 0.3051
```

```text
P3:
IAE overall = 0.3701
VB-FQ       = 0.2756
E-FQ        = 0.2629

IAE fade    = 0.3801
VB-FQ fade  = 0.2862
E-FQ fade   = 0.2465
```

Original paired bootstrap also already supports E-FQ vs VB-FQ in FADE for ALL three profiles:

```text
P1 CI95 = [-0.048779, -0.028006]
P2 CI95 = [-0.045360, -0.023381]
P3 CI95 = [-0.050596, -0.034997]
```

Do not rerun/bootstrap-search until the deterministic Stress reproduction check passes.

After reproduction passes, bootstrap may be regenerated from the telemetry-complete identical Stress run and must agree with original results within Monte Carlo bootstrap randomness; keep bootstrap seed fixed at:

```text
20260909
```

---

# 10. Correct final Pilot admission report

Regenerate:

```text
results/pilot_review/pilot_gate_report.txt
```

PILOT-1:
- verify from frozen original BER and reproduced Stress.

PILOT-2:
- verify exact numerical tracking gates.

PILOT-3:
- verify exact fixed-Q reliability ablation and paired bootstrap.

PILOT-4:
- verify COMPLETE mechanism telemetry.
- missing value = FAIL.

PILOT-5:
- use original frozen BER thresholds.

PILOT-6:
- verify frozen architecture metadata.

Only if all six are truly supported:

```text
PILOT_200MC_PASS
PAPER_3000MC_READY
PAPER_NOT_RUN
```

Otherwise:

```text
PAPER_BLOCKED
```

---

# 11. Required mechanism interpretation

If PILOT-4 passes, the supported mechanism statement is:

```text
During the imposed fade, relative DSSS measurement reliability decreases,
the effective measurement-variance inflation R_eff/R_vb increases,
and the delay-state Kalman gain decreases, while the process covariance Q
remains fixed.
```

Do NOT claim:
- causal proof beyond this controlled simulation;
- real-sea validation;
- adaptive Q;
- universal optimality of fixed Q.

---

# 12. Required tests

Add:

```text
test_pilot_mechanism_telemetry_complete
test_pilot4_fail_closed_on_nan
test_round9_stress_reproduction
```

`test_pilot4_fail_closed_on_nan` must explicitly inject a NaN into one required mechanism field and confirm:

```text
PILOT-4 = FAIL
```

This prevents future vacuous PASS regressions.

---

# 13. Update status documentation

Update:

```text
PAPER_CODE_ALIGNMENT.md
```

Only after actual evidence.

Before successful Round-9.1:

```text
200-MC Pilot: TRACKING/BER GATES SUPPORTED; MECHANISM GATE UNDER REPAIR
3000-MC Paper: BLOCKED
```

If Round-9.1 passes:

```text
200-MC Pilot: ALL PREDECLARED GATES PASS
3000-MC Paper: READY, NOT RUN
```

---

# 14. HARD STOP

DO NOT RUN 3000-MC PAPER IN THIS ROUND.

Even if all corrected Pilot gates pass, stop and commit.

Final line must remain:

```text
WAITING FOR SCIENTIFIC REVIEW BEFORE 3000-MC PAPER RUN.
```

---

# REQUIRED FINAL REPORT

## Git
- base Pilot commit
- new Round-9.1 commit
- changed files

## Reproduction
For every P1/P2/P3 × IAE/VB-FQ/E-FQ:
- old/new overall RMSE
- old/new fade RMSE
- exact/tolerance reproduction status

## Mechanism
For E-FQ in P1/P2/P3:

```text
Median_m_PRE
Median_m_FADE

Median_Reff_Rvb_PRE
Median_Reff_Rvb_FADE

Median_K_PRE
Median_K_FADE

Median_Q11
Median_Q22
```

## Corrected gates
PILOT-1 through PILOT-6:
PASS / FAIL with numerical evidence.

## Final decision
Only if every predeclared gate is actually satisfied:

```text
PILOT_200MC_PASS
PAPER_3000MC_READY
PAPER_NOT_RUN
```

Otherwise:

```text
PAPER_BLOCKED
```

Final line:

```text
WAITING FOR SCIENTIFIC REVIEW BEFORE 3000-MC PAPER RUN.
```
