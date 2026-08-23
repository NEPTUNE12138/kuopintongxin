# WUWNET Paper 2 — Round-8.1 Pilot Plumbing Integrity Patch

Repository:
`NEPTUNE12138/kuopintongxin`

Start from commit:
`21eacc7e9393c889b40dd3cbba6edd7eb478cff4`

This is NOT an algorithm-design round.

The scientific architecture is already frozen:

```text
NO TRM
NO equalizer
E-FQ proposed tracker
Q = diag([0.05, 0.002]) fixed
Kcal = 8
c2 = 1/50 = 0.02
Bellhop local-cluster channel
publication variants = IAE / VB-FQ / E-FQ
```

The final boundary scan has already selected:

```text
Pilot SNR range = -16:-10 dB
```

DO NOT change this range.
DO NOT rerun parameter selection.
DO NOT tune c2, Q, Kcal, equalizer, TRM, reliability formula, fade depth, or warp parameters.
DO NOT run 200-MC Pilot.
DO NOT run Paper mode.

Purpose:
fix the remaining execution/config/output inconsistencies so the approved 200-MC Pilot will actually run the frozen experiment.

---

# 1. Persist the selected Pilot SNR range in configuration

Current bug:

`paper2_config.m` still contains:

```matlab
cfg.snr_range = -14:1:0;
cfg.pilot_snr_range = [];
```

even though `results/final_freeze/final_snr_range.txt` contains:

```text
-16:-10
```

This means future Pilot execution would NOT automatically use the selected Pilot SNR range.

Fix:

```matlab
cfg.pilot_snr_range = -16:1:-10;
```

Keep a separate legacy/diagnostic range only if needed:

```matlab
cfg.quick_snr_range = -14:1:0;
```

For mode behavior:

```matlab
case 'quick'
    cfg.snr_range = cfg.quick_snr_range;
case 'pilot'
    cfg.snr_range = cfg.pilot_snr_range;
case 'paper'
    cfg.snr_range = cfg.pilot_snr_range;
```

Do not change the selected range.

Add test:

```text
test_pilot_snr_range_persistence
```

assert:
- pilot range exactly `-16:1:-10`
- pilot-mode `cfg.snr_range` exactly equals it
- paper-mode `cfg.snr_range` exactly equals it

---

# 2. Make final smoke explicitly use the frozen Pilot SNR range

Current Round-8 smoke called:

```matlab
main_WUWNET_Paper_Validation('quick')
```

so the generated smoke CSV actually covers the old `-14:0` range, not the selected `-16:-10` range.

This must be corrected.

Preferred approach:
extend `main_WUWNET_Paper_Validation` with explicit optional overrides, e.g.:

```matlab
[csv_file, run_meta] = main_WUWNET_Paper_Validation(mode, snr_override, mc_override)
```

If override is supplied:
- use exactly that SNR vector
- use exactly that MC count

Round-8.1 smoke must call:

```matlab
main_WUWNET_Paper_Validation('quick', -16:1:-10, 20)
```

Do NOT alter algorithm settings.

`run_meta` should include:
- variants_internal
- variant_labels
- snr_range
- num_mc
- frontend_use_trm
- equalizer_enabled
- final_tracker_variant
- c2
- Q

---

# 3. Freeze the dynamic Stress SNR explicitly

Current `main_WUWNET_Paper_Stress.m` does:

```matlab
if ~isempty(cfg.pilot_snr_range)
    snr_db = median(cfg.pilot_snr_range);
else
    snr_db = 15;
end
```

Because the range was empty, Round-8 smoke silently ran at 15 dB.

Do not let stress SNR depend accidentally on whether another field is populated.

The dynamic stress experiment is intended to isolate delay-tracking behavior under physical warp + deep fade, so explicitly freeze:

```matlab
cfg.stress_snr_db = 15;
```

This is the same high-SNR stress condition used throughout the diagnostic/held-out development and is NOT a newly optimized value.

Modify Stress so it always uses:

```matlab
snr_db = cfg.stress_snr_db;
```

unless an explicit diagnostic override is passed.

Return `run_meta.stress_snr_db`.

Add test:

```text
test_final_stress_snr_frozen
```

assert:
```text
15 dB
```

Do NOT switch stress to -13 dB in this round.

---

# 4. Fix the mislabeled Q telemetry in Stress

Current bug in `main_WUWNET_Paper_Stress.m`:

```matlab
if isfield(meta, 'P_pred_diag')
    Q11_fade = mean(meta.P_pred_diag(1, fade_idx));
    Q22_fade = mean(meta.P_pred_diag(2, fade_idx));
end
```

This stores predicted state covariance P under names Q11/Q22.

Evidence:
Round-8 smoke reports E-FQ `Mean_Q11_Fade` around 0.33–0.36 even though the true frozen Q11 is exactly 0.05.

Fix to use:

```matlab
meta.Q_diag
```

For E-FQ the exported medians must be exactly:

```text
Q11 = 0.05
Q22 = 0.002
```

up to numerical tolerance.

CSV must include BOTH:
```text
Median_Q11_Fade
Median_Q22_Fade
```

If predicted covariance is scientifically useful, export it separately as:
```text
Median_Ppred11_Fade
Median_Ppred22_Fade
```

Never label P as Q.

Add end-to-end test on final Stress telemetry.

This correction does NOT invalidate the Round-8 RMSE/BER results; it only fixes telemetry labeling.

---

# 5. Fix final BER/FER CSV schema

The statistics helper correctly computes:

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

But final Validation CSV currently exports only a subset.

Export ALL fields above.

Use these exact meanings:

- `BER_Valid`: BER conditional on a successfully processed frame.
- `FER_Valid`: frame-error rate among successfully processed frames.
- `FER_Overall`: receiver-processing failures + erroneous valid frames divided by all attempted frames.

Do NOT count a failed frame as 120 bit errors.

For scientific wording:
the current coarse HFM routine always returns the maximum correlation peak and does not use a calibrated acquisition threshold.
Therefore do NOT describe `SyncFailRate` as a full packet-detection miss/false-alarm probability.

In code/docs preferably rename/report it as:

```text
ReceiverFailCount
ReceiverFailRate
```

or clearly document:
```text
SyncFailRate = receiver processing / tracking failure after coarse peak selection,
not an acquisition-detector miss probability.
```

Do NOT add or tune a new synchronization threshold in this round.

Update boundary CSV to export the complete statistics too.

---

# 6. Fix smoke artifact handling

Current Round-8 pipeline uses wildcard copy:

```matlab
copyfile('paper2_ber_validation_*.csv', 'final_smoke_validation.csv')
```

and this created a DIRECTORY named:

```text
final_smoke_validation.csv/
```

containing multiple historical CSV files.

Same problem exists for:

```text
final_smoke_stress.csv/
```

Fix by having Validation and Stress RETURN the exact generated CSV filename.

For example:

```matlab
[csv_file, run_meta] = main_WUWNET_Paper_Validation(...);
[stress_csv_file, stress_meta] = main_WUWNET_Paper_Stress(...);
```

Then:

```matlab
copyfile(csv_file, fullfile(final_dir,'final_smoke_validation.csv'));
copyfile(stress_csv_file, fullfile(final_dir,'final_smoke_stress.csv'));
```

Before writing:
- remove the erroneous directories named `final_smoke_validation.csv` and `final_smoke_stress.csv`
- create exactly two regular CSV files at those paths

Add test:
```text
test_final_smoke_artifact_paths
```
verifying they are files, not directories.

Do not copy old timestamped runs into the final-freeze artifact names.

---

# 7. Replace hard-coded admission gates FINAL-7 / FINAL-8

Current pipeline contains:

```matlab
FINAL_7 = true;
FINAL_8 = true;
```

This is not an actual gate.

Use returned `run_meta` from the actual smoke runs.

FINAL-7 must check runtime metadata:

```text
variants_internal == {'A','VB-FQ','E-FQ'}
labels == {'IAE','VB-FQ','E-FQ'}
frontend_use_trm == false
equalizer_enabled == false
snr_range == -16:1:-10
num_mc == 20 for smoke
```

FINAL-8 must check actual Stress runtime metadata:

```text
variants_internal == {'A','VB-FQ','E-FQ'}
frontend_use_trm == false
equalizer_enabled == false
stress_snr_db == 15
all three Bellhop profiles were executed
physical PRE/FADE/POST masks were used
```

Do not set either gate to true without checking the actual run.

---

# 8. Strengthen FINAL-9

Current FINAL-9 only checks whether `final_snr_range.txt` can be split by ":".

That is insufficient.

Do NOT rerun the full boundary scan unless needed.

Read the existing boundary CSV and verify the selected frozen values:

```text
P1 lower = -16 dB
P1 upper = -12 dB

P2 lower = -13 dB
P2 upper = -10 dB

P3 lower = -16 dB
P3 upper = -12 dB

common range = -16:-10 dB
```

Rules:
- lower = highest tested SNR with E-FQ FER_Overall >= 0.50
- upper = lowest tested SNR with E-FQ FER_Overall <= 0.05
- common min/max exactly -16/-10

If the existing CSV does not support those facts, FAIL.
Do not select a different range.

Create:
```text
results/final_freeze/final_boundary_summary.txt
```

with the per-profile values.

---

# 9. Strengthen FINAL-10 output-schema check

FINAL-10 must not merely mean "function returned without error".

After the corrected smoke:
read:
```text
final_smoke_validation.csv
final_smoke_stress.csv
```

Verify:

Validation:
- exactly 3 profiles
- exactly 7 SNR values: -16 through -10
- exactly 3 variants
- expected rows = 3 * 7 * 3 = 63
- complete statistics fields present

Stress:
- exactly 3 profiles
- exactly 3 variants
- expected rows = 9
- stress SNR metadata = 15 dB
- Q11 and Q22 fields present
- E-FQ Q11=0.05 and Q22=0.002

Only then:
```text
FINAL_10 = true
```

---

# 10. Manifest integrity

Current committed manifest says:

```text
commit SHA = 644d5a...
```

although it is stored in Round-8 commit `21eacc...`.

A committed file cannot reliably contain its own final Git SHA without a follow-up commit, so do not use a misleading field.

Change manifest terminology to:

```text
freeze_basis_sha = 21eacc7e9393c889b40dd3cbba6edd7eb478cff4
generated_from_worktree = Round-8.1
```

or, if Codex performs two commits:
- implementation commit
- result/manifest commit

then record the implementation commit SHA explicitly as:
```text
freeze_implementation_sha = ...
```

Do not label the parent SHA simply as `commit SHA`.

Manifest must include:

```text
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
pilot SNR range = -16:-10
stress SNR = 15 dB
pilot MC = 200
paper MC = 3000
```

---

# 11. Update PAPER_CODE_ALIGNMENT.md

Current file still contains stale statements such as:

```text
Pilot SNR range: [Pending Scan]
```

despite the final range already being selected.

Update to:

```text
Bellhop local-cluster model: VERIFIED
TRM primary contribution: REJECTED
Common MMSE equalizer: REJECTED / NOT ADOPTED
Adaptive-Q E-CAL: REJECTED
E-FQ fixed-Q architecture: HELD-OUT CONFIRMED
Final front-end: HFM coarse synchronization only
Final Q: diag([0.05,0.002]) FROZEN
Kcal: 8 FROZEN
c2: 1/50 FROZEN
Pilot SNR range: -16:-10 dB FROZEN
Dynamic stress SNR: 15 dB FROZEN
Final publication variants: IAE / VB-FQ / E-FQ
Pilot: READY ONLY IF corrected FINAL-1..10 pass
Paper: NOT RUN
```

Also remove/replace stale upper-table claim:

```text
Variants A/B/C/D/E ... VERIFIED
```

with the final publication set.

Do not mark legacy rejected variants as final evidence.

---

# 12. Corrected Pilot admission gates

Run all existing tests plus the new integrity tests.

Required gates:

```text
FINAL-1  all tests pass
FINAL-2  final tracker = E-FQ
FINAL-3  c2 = 1/50 and frozen
FINAL-4  actual E-FQ per-symbol Q history fixed at [0.05,0.002]
FINAL-5  TRM disabled
FINAL-6  equalizer disabled/not adopted
FINAL-7  actual final smoke Validation runtime metadata correct
FINAL-8  actual final Stress runtime metadata correct
FINAL-9  existing boundary evidence verifies P1/P2/P3 transitions and -16:-10
FINAL-10 exact smoke CSV schemas/row counts/content checks pass
```

Additional integrity conditions:
```text
final_smoke_validation.csv is a FILE
final_smoke_stress.csv is a FILE
Pilot-mode cfg.snr_range == -16:-10
Stress SNR == 15
E-FQ stress Q11 == 0.05
E-FQ stress Q22 == 0.002
```

If all pass:

```text
ROUND8_1_INTEGRITY_PASS
FINAL_ARCHITECTURE_FROZEN
PILOT_READY_FOR_200MC
PILOT_NOT_RUN
```

If any fail:

```text
PILOT_BLOCKED
```

---

# 13. Do NOT rerun scientifically settled work

Do NOT rerun:
- Round-4 E-CAL falsification
- Q attribution
- held-out Round-6
- CFAR falsification
- equalizer adoption study

Do NOT change:
- c2
- Q
- Kcal
- channel cluster policy
- Pilot SNR range
- stress model
- publication variants

Only rerun:
- unit/integration gates
- corrected 20-MC final smoke Validation on -16:-10
- corrected 20-MC final Stress at 15 dB

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

The 200-MC Pilot remains blocked until ChatGPT reviews Round-8.1.

---

# REQUIRED FINAL REPORT

## Git
- base SHA
- new commit SHA
- changed files

## Frozen architecture
- E-FQ
- Q
- Kcal
- c2
- TRM
- EQ
- Pilot SNR range
- Stress SNR

## Boundary evidence
- P1 lower/upper
- P2 lower/upper
- P3 lower/upper
- common range

## Corrected smoke
Validation:
- row count
- SNR range
- variants
- full stats schema

Stress:
- row count
- profiles
- variants
- stress SNR
- E-FQ Q11/Q22

## Artifact integrity
- final_smoke_validation.csv regular file: yes/no
- final_smoke_stress.csv regular file: yes/no

## Admission
FINAL-1 through FINAL-10 with evidence, not hard-coded booleans.

## Final decision

If all pass:

```text
ROUND8_1_INTEGRITY_PASS
FINAL_ARCHITECTURE_FROZEN
PILOT_READY_FOR_200MC
PILOT_NOT_RUN
```

Final line:

```text
WAITING FOR SCIENTIFIC REVIEW BEFORE 200-MC PILOT.
```
