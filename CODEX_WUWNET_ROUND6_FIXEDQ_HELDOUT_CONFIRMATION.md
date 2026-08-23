# WUWNET Paper 2 — Round-6 Candidate Closure & Held-Out Confirmation

Repository:
`NEPTUNE12138/kuopintongxin`

Start from commit:
`e5a8da4ea8afe467c6cd1d4de31e42e1a1440401`

This is a candidate-architecture closure and HELD-OUT confirmation round.

DO NOT run Pilot.
DO NOT run Paper.
DO NOT tune parameters after seeing held-out results.
DO NOT rescue Hybrid TRM.
DO NOT implement dynamic-consistency feedback.
DO NOT change c2 in this round.

---

# 0. Scientific conclusions entering Round-6

## 0.1 Corrected CFAR falsification is final

The matched-filter window bug was corrected by using a shared MF-window helper.

The final corrected 30-MC CFAR calibration still fails the predeclared rule:
minimum recall >= 0.90 across all three profiles at 0 dB.

Observed best cases include:
- P1, 0 dB: recall = 0 for every tested setting
- P2, 0 dB: best median recall = 0.75 at Pfa=1e-2, order=0.50
- P3, 0 dB: best median recall = 0.50 at Pfa=1e-2, order=0.50

Therefore the decision is permanent:

```text
CFAR_EXTRACTION_FAILURE
HYBRID_TRM_NOT_SUPPORTED_AS_PRIMARY_CONTRIBUTION
```

Do not tune kappa.
Do not add new CFAR grids.
Do not change the threshold.
Do not attempt another TRM rescue.

Hybrid/OS-CFAR code may remain for historical/optional/supplementary use, but it is NOT a primary contribution and must not be required by the final proposed tracker.

## 0.2 E-CAL with adaptive Q is rejected

Historical predeclared 50-MC gate:
- S1 Warp: E-CAL/C = ~1.272 > 1.25 -> FAIL
- S3 Warp+Fade: ~1.233 -> PASS

Thus E-CAL with current adaptive Q remains rejected as final.

## 0.3 Round-5 Q attribution gives a clear result

P1, 15 dB, 50-MC median RMSE:

| Scenario | C | EQ0 adaptive-both | EQ1 fixed-Q | EQ2 Q22-only | EQ3 Q11-only |
|---|---:|---:|---:|---:|---:|
| S0 Static | 0.4503 | 0.6321 | 0.3065 | 0.4733 | 0.5693 |
| S1 Warp | 0.5392 | 0.6859 | 0.4840 | 0.6204 | 0.6761 |
| S2 Fade | 0.4271 | 0.5803 | 0.2733 | 0.4267 | 0.5099 |
| S3 Warp+Fade | 0.5381 | 0.6633 | 0.4726 | 0.5973 | 0.6299 |

EQ1 fixed-Q improves relative to EQ0 by approximately:
- S0: 51.5%
- S1: 29.4%
- S2: 52.9%
- S3: 28.8%

EQ1/C ratios:
- S0: ~0.681
- S1: ~0.898
- S2: ~0.640
- S3: ~0.878

Therefore:
```text
Q_ADAPTATION_PRIMARY_SUSPECT = YES
VB_R_RECURSION_STILL_SUSPECT = NO
```

Do not overclaim:
Q11-only is worse than Q22-only, but Q22-only is also worse than fixed-Q and its Q22 becomes very large.
Therefore the supported statement is:

> The CURRENT innovation-energy-driven Q adaptation is harmful; the evidence does not justify adapting Q22 with the current estimator either.

## 0.4 Dynamic-consistency telemetry is NOT sufficiently discriminative

For EQ0:
- S0 directional-consistency median ~0.135
- S1 directional-consistency median ~0.158
- S0 coherent-fraction median ~0.014
- S1 coherent-fraction median ~0.019

For fixed-Q EQ1:
- S0 directional-consistency median ~0.221
- S1 ~0.209
- S0 coherent-fraction ~0.040
- S1 ~0.032

This does NOT provide a clean static-vs-warp separation.

Therefore:
```text
DYNAMIC_CONSISTENCY_GATE_NOT_JUSTIFIED
```

Do NOT implement Path B.
Proceed with process/measurement uncertainty separation using fixed Q as the new candidate.

---

# 1. Integrity fixes before any new experiment

## 1.1 Add the MF window test to the real pipeline

`test_mf_diagnostic_window_bounds.m` exists but is currently NOT invoked by `run_paper2_full_pipeline.m`.

Add:
```matlab
test_mf_diagnostic_window_bounds;
```

The full gate suite must call it.

## 1.2 Reset phase structs

In:
- `diagnose_hvb_q_attribution.m`
- and audit `diagnose_hvb_failure.m`

before assigning NORMAL or PRE/FADE/POST for every scenario/trial:
```matlab
phases = struct();
```

Fade scenarios must NOT inherit a stale `NORMAL` field from previous scenarios.

Re-export Round-5 phase telemetry only if needed for corrected mechanism tables.
The Round-5 RMSE summary is not invalidated by this bug; only phase-field bookkeeping is affected.

## 1.3 Propagate all promised Bayesian telemetry

`hvb_akf_delay_tracker.m` already outputs:
- innovation
- S
- NIS
- P_pred_diag

But `run_paper2_receiver_variant.m` currently does not preserve complete per-symbol histories for S and P_pred_diag.

Add:
```matlab
meta.S
meta.P_pred_diag
```

with correct dimensions.

Add/update an integration-level telemetry test that checks receiver histories, not only the one-step tracker.

## 1.4 Make TRM demotion persistent

Add to `paper2_config.m`:
```matlab
cfg.trm_primary_contribution = false;
```

Do not only print:
`Setting TRM_PRIMARY_CONTRIBUTION = false`.

The configuration, documentation, and final experiment scripts must agree.

## 1.5 Correct PAPER_CODE_ALIGNMENT.md

The upper table still incorrectly marks:
- Hybrid TRM (CFAR+ACF): VERIFIED
- OS-CFAR: VERIFIED
- HFM ACF floor: VERIFIED
- fixed c2 as final: VERIFIED

Use accurate distinctions:
- implementation exists
- unit semantics verified
- efficacy rejected / not supported as primary contribution
- c2 final not frozen
- final tracker unresolved

The final status must explicitly say:
```text
Hybrid TRM primary contribution: REJECTED BY CORRECTED 30-MC CFAR FALSIFICATION
E-CAL adaptive-Q: REJECTED AS FINAL
Fixed-Q calibrated HVB: CANDIDATE ONLY
Final tracker: UNRESOLVED
c2 final: NOT FROZEN
Pilot: BLOCKED
Paper: NOT RUN
```

---

# 2. Define the new candidate without renaming publication Variant E yet

Create a diagnostic candidate:

```text
E-FQ
```

Meaning:

**Reliability-calibrated heteroscedastic VB delay tracker with fixed process covariance.**

Exact settings:

```matlab
Kcal = 8
c2 = 1/50
reliability = relative calibrated
heteroscedastic R = enabled
Q = diag([0.05, 0.002])
Q adaptation = disabled
Q freeze = irrelevant because Q is fixed
```

These Q values are the inherited initial values already present before the Round-5 result.
Do NOT optimize them in this round.

Do NOT map publication Variant E to E-FQ yet.

Create a clean implementation path, e.g.:
```matlab
cfg.hvb.q_adaptation_mode = 'fixed';
cfg.reliability.mode = 'relative_calibrated';
```

If using a diagnostic label, extend variant handling explicitly and add a test.

---

# 3. Create a fixed-Q Bayesian ablation

To isolate whether reliability contributes beyond simply fixing Q, create:

```text
VB-FQ
```

Exact definition:
- VB covariance inference enabled
- heteroscedastic reliability penalty disabled (`Lambda=1`)
- fixed Q = diag([0.05,0.002])
- no Q adaptation

This is different from the old `E-VB-only`, which did not guarantee fixed Q.

The confirmatory backend comparison must include:
1. IAE baseline
2. VB-FQ
3. E-FQ proposed candidate

Optionally retain original adaptive-Q E only as a failure-reference, not as a primary competitor.

---

# 4. Remove failed Hybrid TRM from the confirmatory main chain

Because Hybrid TRM is now scientifically demoted, the held-out tracker confirmation must not depend on it.

Add a common front-end override such as:

```matlab
cfg.frontend.use_trm = false;
```

or an equivalent explicit mechanism.

For ALL confirmatory variants:
- use the same HFM coarse synchronization
- use no TRM focusing
- use the same received waveform
- use the same sync result
- use the same noise realization
- only the delay tracker changes

Do NOT silently use strongest-path fallback as “Hybrid TRM”.

This held-out test is intended to isolate the tracker contribution.

Keep the Bellhop local-cluster channel and `conv(...,'full')`.

---

# 5. Held-out confirmatory experiment

Create:
`src/confirm_fixedq_tracker_heldout.m`

The candidate was generated from:
- P1
- 15 dB
- S0-S3

Therefore the confirmatory environments must be held out.

Use:

Profiles:
```text
P2
P3
```

SNR:
```matlab
[0, 15]
```

Scenarios:
```text
S0_Static
S1_Warp
S2_Fade
S3_Warp_Fade
```

Trials:
```text
50 MC per condition
```

Variants:
```text
IAE
VB-FQ
E-FQ
```

All variants share:
- bits
- Bellhop local cluster
- channel output
- time warp
- fade envelope
- noise
- coarse sync

Use deterministic seeds.
No seed search.

No parameter may be changed after viewing results.

---

# 6. Exact held-out scenario definitions

Reuse the existing physical helpers and definitions:

Warp:
```matlab
v0_mps = 0.5
velocity_amp_mps = 1.5
velocity_freq_hz = 0.2
phase_rad = 0
```

Fade:
same 100-ms Gaussian fade definition already used in the diagnostic.

Use true symbol-center timing ground truth from `apply_paper2_time_warp`.

Use true fade masks from the physical fade envelope.

Do not use thirds.

---

# 7. PREDECLARED acceptance rules

These rules are defined BEFORE held-out results.

## 7.1 Validity gate
For E-FQ:
```text
valid trial rate >= 0.95
```
for every held-out condition.

## 7.2 Dynamic tracking safety gate
For every P2/P3 × SNR condition in S1 and S3:

```text
median RMSE_EFQ <= 1.10 * median RMSE_IAE
```

No exceptions.

## 7.3 Overall generalization gate

Across all 16 held-out conditions:

```text
median of (RMSE_EFQ / RMSE_IAE) <= 0.95
```

and:

```text
at least 12/16 conditions have RMSE_EFQ <= RMSE_IAE
```

## 7.4 Reliability mechanism gate

For fade scenarios S2/S3, aggregated separately per profile/SNR:

```text
median(Reff/Rvb)_FADE > median(Reff/Rvb)_PRE
median(K_delay)_FADE < median(K_delay)_PRE
```

For normal/static S0:
```text
median(Reff/Rvb) <= 1.15
```

## 7.5 Bayesian ablation gate

Report E-FQ vs VB-FQ.

Do NOT require E-FQ to win every condition.
But the reliability mechanism can only be claimed to improve tracking if:
```text
median held-out RMSE ratio E-FQ / VB-FQ < 1
```

If this condition is not met, the reliability penalty may remain a mechanism but must not be claimed as a performance improvement.

---

# 8. Required outputs

Save under:
```text
results/confirmatory/
```

Files:

```text
fixedq_heldout_summary.csv
fixedq_heldout_phase_stats.csv
fixedq_heldout_raw.mat
fixedq_heldout_decision.txt
```

Summary CSV columns:

```text
Profile
SNR_dB
Scenario
Variant
ValidRate
RMSE_Median
RMSE_Mean
Bias_Median
BER
SyncFailRate
```

Phase CSV:
```text
Profile
SNR_dB
Scenario
Variant
Phase
Metric
Mean
Median
P10
P90
```

Metrics:
- m_reliability
- rho_raw
- rho_relative
- Lambda
- R_vb
- R_eff
- R_eff_R_vb
- K_delay
- Q11
- Q22
- innovation
- abs_innovation
- S
- NIS
- Ppred11
- Ppred22
- tracking_error

---

# 9. Decision logic

If ALL acceptance gates pass:

print:
```text
FIXEDQ_TRACKER_HELDOUT_PASS
CANDIDATE_READY_FOR_FINAL_PARAMETER_FREEZE
PILOT_STILL_NOT_RUN
```

Do NOT run Pilot automatically.

If any gate fails:

print:
```text
FIXEDQ_TRACKER_HELDOUT_FAIL
FINAL_TRACKER_UNRESOLVED
PILOT_BLOCKED
```

Do not tune Q or c2 in this round.

---

# 10. Scientific interpretation rules

If E-FQ passes:

The supported architectural conclusion is:

> Separating measurement uncertainty adaptation from process uncertainty avoids the innovation-leakage failure observed with simultaneous adaptive Q, while calibrated reliability retains selective measurement down-weighting during fades.

Do NOT say:
- adaptive Q22 is validated
- dynamic-consistency gating is validated
- Hybrid TRM is validated
- fixed Q is universally optimal
- sea-trial performance is proven

If E-FQ fails:
do not invent another tracker in this round.

---

# 11. Manuscript framing checkpoint

Do NOT rewrite the full manuscript in Codex.

Only update code-alignment/status documentation.

If E-FQ passes held-out confirmation, the next manuscript direction for ChatGPT review will be approximately:

```text
Reliability-Calibrated Heteroscedastic Bayesian Delay Tracking
with Process–Measurement Uncertainty Separation
for Underwater Acoustic DSSS Communications
```

Hybrid TRM should no longer appear in the title or contribution list as a primary innovation.

---

# 12. Required tests

Add:

### test_fixedq_candidate_definition
Verify:
- E-FQ uses relative calibration
- E-FQ uses heteroscedastic R
- Q remains exactly diag([0.05,0.002])

### test_vbfq_ablation_definition
Verify:
- Lambda = 1
- Q remains fixed

### test_frontend_trm_override
Verify:
- no TRM filter is built when confirmatory front-end override is false
- all tracker variants receive the same unfocused waveform

### test_receiver_telemetry_histories
Verify correct lengths and finiteness of:
- innovation
- S
- NIS
- P_pred_diag

### test_phase_mask_reset
Verify fade scenarios contain only PRE/FADE/POST and non-fade scenarios contain only NORMAL.

And ensure:
```matlab
test_mf_diagnostic_window_bounds;
```
is actually executed by the main gate suite.

---

# 13. Pipeline behavior

`run_paper2_full_pipeline` must NOT run publication Validation/Stress while final tracker is unresolved.

For this round it may run:
1. gate tests
2. held-out fixed-Q confirmation
3. terminate

Do not rerun CFAR calibration automatically; that decision is already final.

Expected end before review:
```text
PILOT NOT RUN
PAPER NOT RUN
```

---

# REQUIRED FINAL REPORT

## Git
- commit SHA
- changed files

## Integrity
- MF helper test included in pipeline: yes/no
- phase reset fixed: yes/no
- S/Ppred telemetry propagated: yes/no
- `cfg.trm_primary_contribution=false`: yes/no

## Permanent TRM decision
```text
HYBRID_TRM_NOT_SUPPORTED_AS_PRIMARY_CONTRIBUTION
```

## Held-out table
For P2/P3 × 0/15 dB × S0-S3:
- IAE median RMSE
- VB-FQ median RMSE
- E-FQ median RMSE
- E-FQ/IAE
- E-FQ/VB-FQ
- valid rate

## Mechanism table
For S2/S3:
- PRE and FADE m
- PRE and FADE Reff/Rvb
- PRE and FADE K

## Acceptance
- validity gate
- dynamic safety gate
- overall generalization gate
- reliability mechanism gate
- Bayesian ablation result

## Final decision
Either:
```text
FIXEDQ_TRACKER_HELDOUT_PASS
CANDIDATE_READY_FOR_FINAL_PARAMETER_FREEZE
```

or:
```text
FIXEDQ_TRACKER_HELDOUT_FAIL
FINAL_TRACKER_UNRESOLVED
```

Final line:
```text
PILOT NOT RUN — waiting for scientific review.
```
