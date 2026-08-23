# WUWNET Paper 2 — Round-8 Final Architecture Freeze & Pilot Admission

Repository:
`NEPTUNE12138/kuopintongxin`

Start from commit:
`644d5a087c66b06fa7f4f51e51e635d33fd3a846`

This round closes algorithm/front-end design.

DO NOT invent a new tracker.
DO NOT rescue TRM.
DO NOT rescue or retune the equalizer.
DO NOT optimize Q.
DO NOT optimize Kcal.
DO NOT optimize c2 after this point.
DO NOT run the 200-MC Pilot until the end-of-round admission decision is reviewed.
DO NOT run Paper mode.

---

# 0. Scientific state entering Round-8

## 0.1 Final tracker architecture has passed held-out confirmation

Round-6:

```text
FIXEDQ_TRACKER_HELDOUT_PASS
median E-FQ / IAE = 0.7914
E-FQ wins vs IAE = 14/16 held-out conditions
median E-FQ / VB-FQ = 0.9355
all predeclared gates passed
```

Therefore E-FQ architecture is accepted.

## 0.2 TRM is permanently rejected as a primary contribution

Corrected 30-MC CFAR falsification failed.

Permanent:

```text
cfg.trm_primary_contribution = false
```

Do not run another CFAR calibration.

## 0.3 Common practical MMSE equalizer is rejected

Round-7:

```text
EQ-1 numerical validity: PASS
EQ-2 physical suppression: FAIL
EQ-3 E-FQ tracker safety: FAIL
EQ-4 shared-front-end fairness: PASS
EQ-5: PRACTICAL_CHANNEL_ESTIMATION_LIMITED
COMMON_MMSE_EQUALIZER_REJECTED
```

Examples:
- P2 0 dB residual ISI:
  No-EQ ≈ 0.4926
  Practical EQ ≈ 0.6466
  Oracle EQ ≈ 0.3333

- Dynamic E-FQ EQ/NoEQ failures included approximately:
  P1 15 dB ≈ 1.2486
  P2 0 dB ≈ 2.2409
  P3 15 dB ≈ 2.1832

Therefore final receiver front-end is NO-EQ.

Do not retune channel length, equalizer length, regularization, or decision delay.
Equalizer code may remain as a rejected ablation.

---

# 1. Freeze the final publication architecture

The final proposed receiver is:

```text
Bellhop-derived local arrival cluster channel
-> HFM coarse packet synchronization
-> NO TRM
-> NO equalizer
-> DSSS Early/Late discriminator
-> relative reliability calibration
-> heteroscedastic VB measurement covariance
-> fixed process covariance Q
-> delay/drift Bayesian tracking
-> differential detection
```

Final tracker settings:

```matlab
cfg.final_tracker_variant = 'E-FQ';
cfg.final_architecture_frozen = true;

cfg.frontend.use_trm = false;
cfg.trm_primary_contribution = false;

cfg.equalizer.enabled = false;
cfg.equalizer.adopted = false;

cfg.reliability.mode = 'relative_calibrated';
cfg.reliability.calibration_symbols = 8;

cfg.hvb.q_adaptation_mode = 'fixed';
cfg.hvb.use_heteroscedastic = true;

cfg.final_Q = diag([0.05, 0.002]);

cfg.c2 = 1/50;
cfg.c2_frozen = true;
```

IMPORTANT:
`c2=1/50` is frozen because this exact value was used in the successful independent held-out confirmation.

Do NOT now optimize c2 on P2/P3.
Doing so would contaminate the held-out confirmation.

Future c2 sensitivity is descriptive robustness analysis only and may NEVER change the frozen value.

Add a test verifying the frozen final configuration exactly.

---

# 2. Clean publication variant semantics

Do not use legacy A/B/C/D/E as the final paper experiment set.

Publication experiment set:

```text
IAE      -> current Variant A semantics, no TRM
VB-FQ    -> fixed-Q VB ablation, Lambda = 1
E-FQ     -> proposed method
```

Optional diagnostic-only failure reference:
```text
Adaptive-Q HVB
```
may appear in an ablation table, but not as the main proposed method.

Legacy B/C/D/E remain only for reproducibility of rejected development paths.

Update comments and names in:
- `paper2_variant_definition.m`
- experiment scripts
- documentation

Do not call old Hybrid-TRM E "Proposed" anymore.

---

# 3. Replace the formal BER Validation script

Current `main_WUWNET_Paper_Validation.m` is invalid for the final paper because it still uses:

```matlab
{'A','B','C','D','E'}
```

Replace/refactor it so final modes use:

```matlab
variants = {'A','VB-FQ','E-FQ'};
```

All three:
- NO TRM
- NO equalizer
- same Bellhop local cluster
- same bits
- same noise
- same raw waveform
- same HFM coarse sync

Use `conv(...,'full')`.

Use deterministic shared seeds.

Output publication labels:
```text
IAE
VB-FQ
Proposed E-FQ
```

Do not expose old internal A label in final CSV if avoidable.

---

# 4. Fix BER / FER / synchronization statistics before Pilot

Do not hide synchronization failure as NaN-only reporting.

For every Profile × SNR × Variant report separately:

```text
Trials_Total
Trials_Valid
SyncFailCount
SyncFailRate

BitErrors_Valid
Bits_Valid
BER_Valid

FrameErrors_Valid
FER_Valid

FrameErrors_Overall
FER_Overall

Wilson_Lower_ValidBER
Wilson_Upper_ValidBER
```

Definitions:

```text
BER_Valid:
bit errors / bits only among successfully decoded frames.

FER_Valid:
fraction of successfully synchronized frames containing >=1 bit error.

FER_Overall:
(sync failures + successfully synchronized frames with >=1 bit error)
/
all attempted frames.
```

A sync failure therefore counts as an overall frame failure.

Do NOT silently count all bits of a sync-failed frame as bit errors.
Keep BER and synchronization outage separated.

Create/update one statistics helper and unit tests for:
- all successful error-free
- successful with bit errors
- mixed sync failures
- all sync failures

---

# 5. Fix final Stress experiment

Current `main_WUWNET_Paper_Stress.m` still uses legacy:

```matlab
{'C','D','E'}
```

Replace final stress set with:

```text
IAE
VB-FQ
E-FQ
```

Use:
- NO TRM
- NO EQ
- real `apply_paper2_time_warp`
- physical fade envelope
- true symbol-center ground truth
- true PRE / FADE / POST masks

Do not use frame thirds.

Run all three Bellhop profiles, not P1 only.

Final stress condition remains:
```text
Warp + 100-ms deep fade
```

For Pilot/Paper use the frozen stress SNR selected below.

Export:
- RMSE PRE / FADE / POST
- overall RMSE
- BER_Valid
- FER_Overall
- SyncFailRate
- median m
- median R_eff/R_vb
- median K_delay
- Q11/Q22 (must remain fixed for E-FQ)

---

# 6. Archive the Round-7 equalizer result honestly

Do not rerun equalizer adoption.

One known archival issue:
`compute_equalizer_metrics.m` currently labels `RMSDelaySpread` but calculates RMS delay spread from the true input channel before applying w, so the CSV value is identical for NO-EQ/PRACTICAL/ORACLE.

This did NOT determine the Round-7 rejection; rejection was based on:
- residual ISI
- tracker safety
- practical vs oracle behavior

Fix future code/documentation in one of two ways:

Preferred:
rename the current metric to:
```text
InputChannelRMSDelaySpread
```

and, if a combined-response metric is retained, explicitly compute:
```text
CombinedRMSDelaySpread
```
from `g = conv(h_true,w)`.

Do NOT change the historical Round-7 adoption decision.

Add a note to alignment documentation:
```text
Round-7 RMS-delay-spread column was input-channel RDS; not used in adoption gates.
```

---

# 7. Final low-SNR boundary scan

Old boundary scans used rejected tracker/front-end definitions and are obsolete.

Create:

```matlab
src/scan_final_snr_boundary.m
```

Use the FROZEN final receiver only:

Variants:
```text
IAE
VB-FQ
E-FQ
```

Profiles:
```text
P1 P2 P3
```

Initial scan:
```matlab
SNR = -20:1:2;
MC = 30;
```

No warp/fade for the BER boundary scan.

Report the statistics from Section 4.

The boundary scan is for selecting an experimental SNR RANGE, not algorithm parameters.

---

# 8. Deterministic Pilot SNR-range selection rule

Do not eyeball the curves.

For the proposed E-FQ, for each profile determine:

## Lower transition point
Highest SNR value for which:
```text
FER_Overall >= 0.50
```

If no point satisfies it within the scan, extend downward by 2 dB increments until found or -26 dB.

## Upper reliable point
Lowest SNR value for which:
```text
FER_Overall <= 0.05
AND
SyncFailRate <= 0.05
```

If no point satisfies it within the scan, extend upward by 2 dB increments until found or +6 dB.

Then common Pilot range:

```text
pilot_snr_min = min(lower transition points across P1/P2/P3)
pilot_snr_max = max(upper reliable points across P1/P2/P3)
```

Clamp only to tested values.

Use:
```matlab
cfg.pilot_snr_range = pilot_snr_min:1:pilot_snr_max;
```

The purpose is to ensure the common SNR grid spans failure-to-reliable transition for all profiles.

Do not choose a range to make E-FQ look good.

Save:
```text
results/final_freeze/final_snr_boundary.csv
results/final_freeze/final_snr_range.txt
```

---

# 9. Final frozen-method smoke validation

After setting the SNR range, run a small final smoke only:

```text
20 MC per profile × SNR × variant
```

using the final Validation implementation.

This is NOT the 200-MC Pilot.

Purpose:
- confirm no legacy TRM/E path remains
- confirm output schema
- confirm no crashes
- confirm E-FQ Q is fixed
- confirm common randomness/fairness
- confirm result directories

Do not derive algorithm changes from this smoke.

---

# 10. Pilot admission gates

Pilot admission may be declared only if ALL are true:

```text
FINAL-1: all unit/integration tests pass
FINAL-2: cfg.final_tracker_variant == 'E-FQ'
FINAL-3: c2_frozen == true and c2 == 1/50
FINAL-4: Q == diag([0.05,0.002]) for every E-FQ symbol
FINAL-5: frontend.use_trm == false
FINAL-6: equalizer.enabled == false / adopted == false
FINAL-7: final BER Validation uses only IAE/VB-FQ/E-FQ
FINAL-8: final Stress uses only IAE/VB-FQ/E-FQ and physical masks
FINAL-9: final SNR range successfully brackets transitions
FINAL-10: smoke validation completes with valid output schema
```

If all pass print:

```text
FINAL_ARCHITECTURE_FROZEN
PILOT_READY_FOR_200MC
PILOT_NOT_RUN
```

If any fail:

```text
PILOT_BLOCKED
```

Do NOT automatically run Pilot.

---

# 11. Documentation freeze

Update `PAPER_CODE_ALIGNMENT.md`.

Final scientific status should become approximately:

```text
Bellhop local-cluster channel model: VERIFIED
Hybrid TRM primary contribution: REJECTED
Common MMSE equalizer: REJECTED / NOT ADOPTED
Adaptive-Q E-CAL: REJECTED
E-FQ fixed-Q architecture: HELD-OUT CONFIRMED
Final front-end: HFM synchronization only
Final process covariance: Q=diag([0.05,0.002]) FROZEN
Final Kcal: 8 FROZEN
Final c2: 1/50 FROZEN
Final publication variants: IAE / VB-FQ / E-FQ
Pilot SNR range: <actual selected result>
Pilot: READY BUT NOT RUN
Paper: NOT RUN
```

Do not leave:
```text
Full Quick Pipeline: FAILED / NOT COMPLETE
```
if the new final-freeze pipeline actually passes.

Do not mark old A/B/C/D/E validation as final paper evidence.

---

# 12. Final paper contribution wording checkpoint

Do not write the manuscript in Codex.

Only archive the evidence needed for ChatGPT.

The supported method story after freeze is:

1. Relative reliability calibration estimates instantaneous DSSS measurement quality relative to the packet/channel nominal correlation.
2. Reliability modulates the effective VB measurement covariance.
3. Fixed process covariance deliberately separates process uncertainty from measurement-quality adaptation and prevents innovation-energy leakage into Q.
4. The architecture was selected on P1 and independently confirmed on held-out P2/P3 profiles.

Do NOT claim:
- adaptive Q innovation
- TRM innovation
- equalizer innovation
- sea-trial validation
- full Bellhop multi-second path use
- routing

---

# 13. Required tests

Add/update:

### test_final_architecture_freeze
assert:
```matlab
final_tracker_variant == 'E-FQ'
c2 == 1/50
c2_frozen == true
final_architecture_frozen == true
trm_primary_contribution == false
frontend.use_trm == false
equalizer.enabled == false
equalizer.adopted == false
final_Q == diag([0.05,0.002])
Kcal == 8
```

### test_final_publication_variant_set
Final validation/stress contain only:
```text
A / VB-FQ / E-FQ
```
with A exported as IAE.

### test_final_ber_statistics
Test sync failure / BER / FER definitions.

### test_final_EFQ_fixedQ_history
End-to-end E-FQ:
```text
Q11 == 0.05
Q22 == 0.002
```
for all processed symbols.

### test_final_no_trm_no_eq
Final E-FQ must not call TRM or equalizer.

### test_final_stress_masks
PRE/FADE/POST derived from actual fade envelope.

Keep all existing valid tests.

---

# 14. Required outputs

Under:

```text
results/final_freeze/
```

save:

```text
final_snr_boundary.csv
final_snr_range.txt
final_smoke_validation.csv
final_smoke_stress.csv
final_freeze_manifest.txt
```

`final_freeze_manifest.txt` must include:

```text
commit SHA
final tracker = E-FQ
TRM = disabled
equalizer = disabled
Q = [0.05,0.002]
Kcal = 8
c2 = 0.02
c2 frozen = true
channel model = bellhop_local_cluster
cluster gap = 0.05 s
publication variants = IAE, VB-FQ, E-FQ
pilot SNR range = ...
pilot MC = 200
paper MC = 3000
```

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

Round-8 is the FINAL pre-Pilot admission round.

---

# REQUIRED FINAL REPORT

## Git
- commit SHA
- changed files

## Architecture
- final tracker
- Q
- Kcal
- c2
- TRM state
- equalizer state

## Equalizer archival note
- confirm rejection unchanged
- confirm RDS label correction/documentation

## Boundary
Per profile:
- lower FER>=0.50 transition
- upper FER<=0.05 & SyncFail<=0.05 point
- final common Pilot SNR range

## Smoke
- all final variants
- validity
- BER/FER output correctness
- fixed-Q verification

## Admission gates
FINAL-1 through FINAL-10 PASS/FAIL

## Final decision

If all pass:
```text
FINAL_ARCHITECTURE_FROZEN
PILOT_READY_FOR_200MC
PILOT_NOT RUN
```

Otherwise:
```text
PILOT_BLOCKED
```

Final line:
```text
WAITING FOR SCIENTIFIC REVIEW BEFORE 200-MC PILOT.
```
