# WUWNET Paper 2 — Round-7 Common MMSE Equalizer Front-End Ablation

Repository:
`NEPTUNE12138/kuopintongxin`

Start from commit:
`0304fef2ebbe638a0a9ec7bd05cc7444c74e94b3`

PURPOSE:
Decide, with a fair controlled ablation, whether a conventional preamble-aided regularized linear MMSE equalizer should be included as a COMMON receiver front-end before the final tracker parameter freeze.

This equalizer is NOT a Paper-2 innovation.
It must be identical for IAE, VB-FQ and E-FQ.
The proposed contribution remains the fixed-Q reliability-calibrated Bayesian delay tracker.

DO NOT run Pilot.
DO NOT run Paper.
DO NOT tune c2.
DO NOT tune Q.
DO NOT revive Hybrid TRM / OS-CFAR.
DO NOT tune the equalizer using BER or tracker RMSE.

---

# 0. Frozen scientific facts entering Round-7

## Tracker candidate

Round-6 held-out confirmation on P2/P3, SNR {0,15} dB, 50 MC/condition:

```text
Gate 7.1 Validity: PASS
Gate 7.2 Dynamic safety: PASS
Gate 7.3a median E-FQ/IAE: PASS = 0.7914
Gate 7.3b E-FQ wins vs IAE: PASS = 14/16
Gate 7.4 Reliability mechanism: PASS
Gate 7.5 median E-FQ/VB-FQ: PASS = 0.9355
```

Therefore:

```text
FIXEDQ_TRACKER_HELDOUT_PASS
CANDIDATE_READY_FOR_FINAL_PARAMETER_FREEZE
```

The candidate architecture is:

```text
E-FQ
relative reliability calibration
Kcal = 8
c2 = 1/50 (still NOT finally frozen)
heteroscedastic VB measurement-noise adaptation
Q = diag([0.05,0.002]) fixed for the packet
```

Do not alter this tracker architecture in Round-7.

## TRM decision

Permanent:

```text
cfg.trm_primary_contribution = false
HYBRID_TRM_NOT_SUPPORTED_AS_PRIMARY_CONTRIBUTION
```

Do not run another CFAR search.

---

# 1. Integrity cleanup first

## 1.1 Candidate semantics

`E-FQ` and `VB-FQ` currently have `uses_trm=true` in `paper2_variant_definition.m`
and rely on an external override.

Correct this semantic mismatch.

For:
```text
E-FQ
VB-FQ
```

set intrinsically:

```matlab
uses_trm = false;
uses_hybrid = false;
```

Their tracker definitions must be independent of failed TRM.

Legacy A/B/C/D/E diagnostic definitions may remain for historical reproduction.

## 1.2 PAPER_CODE_ALIGNMENT.md

The upper claim table still says VERIFIED for Hybrid TRM / OS-CFAR although the lower status says the primary contribution was rejected.

Correct the upper table.

Use distinctions such as:

```text
IMPLEMENTED — EFFICACY REJECTED
UNIT SEMANTICS VERIFIED — NOT A PRIMARY CONTRIBUTION
```

Update Round-6 state:

```text
Fixed-Q calibrated HVB held-out confirmation: PASS
E-FQ: CANDIDATE READY FOR FRONT-END / PARAMETER FREEZE
Final publication mapping: NOT YET FROZEN
c2 final: NOT FROZEN
TRM primary contribution: REJECTED
Pilot: NOT RUN
Paper: NOT RUN
```

## 1.3 Preserve all Round-6 gates

Do not remove the existing held-out result files or tests.

---

# 2. Equalizer philosophy

We are NOT designing a sparse path detector.

Do NOT reuse OS-CFAR.

Use the known HFM preamble as a dense training waveform and estimate a local FIR channel by regularized least squares.

Receiver chain under test:

```text
raw received packet
    -> raw HFM coarse acquisition
    -> dense preamble-aided local CIR estimation
    -> regularized linear MMSE inverse filter
    -> full packet equalization
    -> HFM re-synchronization on equalized packet
    -> DSSS despreading / DLL tracker
```

The same equalized waveform and the same post-EQ synchronization result must be shared by IAE, VB-FQ and E-FQ.

No tracker-specific equalizer is allowed.

---

# 3. Fixed equalizer design — no BER-based tuning

Create configuration:

```matlab
cfg.equalizer.enabled = false;          % legacy/default
cfg.equalizer.channel_len = cfg.symbol_samples;
cfg.equalizer.eq_len = cfg.symbol_samples;
cfg.equalizer.decision_delay = cfg.equalizer.channel_len - 1; % zero-based conceptual delay
cfg.equalizer.noise_guard_fraction = 0.5;
cfg.equalizer.method = 'preamble_rls_mmse';
```

Current system:

```text
fs = 48 kHz
symbol_samples = 186
one DSSS symbol ≈ 3.875 ms
```

A 186-sample channel window covers the current Bellhop local-cluster spreads, including the ~3 ms P2 cluster.

Do NOT sweep channel length or equalizer length in this round.

Do NOT optimize decision delay.

---

# 4. Dense regularized preamble channel estimator

Create:

```matlab
lib/estimate_channel_from_hfm_ls.m
```

Inputs should include:
- raw received waveform
- preamble
- raw coarse-sync metadata
- cfg

Let:

```matlab
Lh = cfg.equalizer.channel_len;
Np = length(preamble);
```

Extract a training observation beginning at the raw estimated preamble arrival:

```text
length = Np + Lh - 1
```

Build a convolution matrix `P` such that:

```matlab
y_train ≈ P * h
```

Do not depend on `convmtx` if a simple local helper avoids an extra toolbox dependency.

## Noise estimate

Use the latter half of the known 50-ms guard interval between preamble and payload.

This is physically available to the receiver.

Exclude the early part of the guard so the local channel tail does not contaminate the noise estimate.

Estimate:

```matlab
sigma_n2 = mean(abs(noise_guard).^2);
```

Estimate received signal power from the preamble-bearing region:

```matlab
sigma_y2 = mean(abs(y_preamble_core).^2);
sigma_s2 = max(sigma_y2 - sigma_n2, eps);
eta = sigma_n2 / sigma_s2;
```

## Regularization

Use a scale-normalized Tikhonov value:

```matlab
G = P' * P;
lambda_h = eta * trace(G) / Lh;
```

Then:

```matlab
h_hat = (G + lambda_h * eye(Lh)) \ (P' * y_train);
```

This is data-driven from the training waveform and estimated noise.

Do NOT introduce a manually tuned scalar multiplier in Round-7.

Return metadata:
- sigma_n2
- sigma_y2
- eta
- lambda_h
- h_hat energy
- condition number before/after regularization

---

# 5. Regularized linear MMSE inverse equalizer

Create:

```matlab
lib/design_linear_mmse_equalizer.m
```

Inputs:
- h_hat
- estimated eta
- cfg

Let:

```matlab
Lh = cfg.equalizer.channel_len;
Leq = cfg.equalizer.eq_len;
D = cfg.equalizer.decision_delay;
```

Construct convolution matrix `H` mapping equalizer taps to the combined channel.

Target:

```matlab
d = zeros(Lh + Leq - 1,1);
d(D + 1) = 1;
```

Use:

```matlab
G = H' * H;
lambda_eq = eta * trace(G) / Leq;

w = (G + lambda_eq * eye(Leq)) \ (H' * d);
```

Do not normalize `w` after solving unless mathematically required by an explicit derivation.
The unit target impulse already fixes scale.

Return:
- w
- lambda_eq
- decision delay
- norm(w)^2
- predicted combined response `conv(h_hat,w)`

---

# 6. Apply equalizer safely

Create:

```matlab
lib/apply_paper2_equalizer.m
```

Apply using full convolution:

```matlab
rx_eq = conv(rx_raw, w, 'full');
```

Do not truncate the equalizer tail.

After equalization:
run HFM coarse synchronization again on `rx_eq`.

All tracker variants under the EQ condition receive:
- identical `rx_eq`
- identical post-EQ sync metadata

Raw coarse sync is used only for equalizer training/acquisition.

If channel estimation/equalizer solve is numerically invalid:
mark the EQ front-end trial invalid.
Do not silently fall back to No-EQ and count it as an EQ success.

---

# 7. Oracle equalizer only as a diagnostic upper bound

Implement an optional diagnostic:

```text
ORACLE-EQ
```

using the true normalized Bellhop local cluster padded to `Lh`.

It may use the same MMSE inverse design but NOT the preamble channel estimator.

Purpose:
distinguish:

```text
linear equalization itself is ineffective
```

from:

```text
the practical preamble channel estimate is the bottleneck
```

ORACLE-EQ must never:
- be called a proposed method
- be included in final BER comparison
- be used to tune the practical equalizer

---

# 8. Mechanism metrics

Create:

```matlab
lib/compute_equalizer_metrics.m
```

For diagnostic access to the TRUE selected Bellhop local cluster only, compute:

For No-EQ, Practical-EQ and Oracle-EQ:

```text
combined-channel RMS delay spread
main-tap energy concentration
residual ISI energy fraction
peak-to-sidelobe ratio
equalizer noise-enhancement = norm(w)^2
```

Suggested residual ISI metric:

```matlab
g = conv(h_true_cluster, w);
main = abs(g(D+1))^2;
total = sum(abs(g).^2);
residual_isi_fraction = max(0,(total-main)/max(total,eps));
```

For No-EQ use the strongest true channel tap as the main reference.

Also calculate practical channel-estimation NMSE for diagnostics only.
Before NMSE, align a single complex scalar between `h_hat` and `h_true_padded`:

```matlab
a = (h_hat' * h_true) / max(h_hat' * h_hat, eps);
nmse = norm(a*h_hat - h_true)^2 / max(norm(h_true)^2,eps);
```

Do NOT use true h for practical equalizer construction.

---

# 9. Round-7 experiment

Create:

```matlab
src/diagnose_common_mmse_equalizer.m
```

Profiles:

```text
P1
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
S3_Warp_Fade
```

MC:

```text
30 trials per condition
```

Trackers:

```text
A       % IAE, no TRM
VB-FQ
E-FQ
```

Front-ends:

```text
NO-EQ
PRACTICAL-MMSE-EQ
```

Additionally collect ORACLE-EQ mechanism results as a diagnostic upper bound.
It is not part of the primary tracker comparison.

All variants in a given front-end/trial share:
- bits
- Bellhop local cluster
- time warp
- fade
- noise
- front-end output
- final sync

Use deterministic seeds.

Do not change E-FQ parameters.

---

# 10. Fairness requirement

The experiment must be organized by FRONT-END first, then tracker.

Correct conceptual flow:

```matlab
for trial
    construct one raw received packet

    frontend_noeq = raw packet + shared raw sync

    frontend_eq:
        raw sync
        estimate h once
        design w once
        equalize once
        post-EQ sync once

    for tracker
        run tracker on exactly the selected shared frontend waveform
    end
end
```

Incorrect:
each tracker estimates its own equalizer.

Add an automated equality/hash/norm test proving the same EQ waveform is passed to all trackers.

---

# 11. Predeclared equalizer adoption rules

The equalizer is a conventional front-end, so the question is whether it is useful and safe.

## Gate EQ-1 — numerical validity

Practical equalizer valid rate:

```text
>= 0.95
```

for every Profile × SNR × Scenario condition.

## Gate EQ-2 — physical multipath suppression

For P2 (the largest local cluster), practical EQ must reduce median residual ISI fraction by at least 20% relative to No-EQ at both tested SNRs.

For P1/P3 it must not worsen median residual ISI fraction by more than 10%.

No BER is used to choose the equalizer.

## Gate EQ-3 — proposed tracker safety

For every S3 Warp+Fade Profile × SNR condition:

```text
median RMSE(E-FQ + EQ)
    <= 1.10 * median RMSE(E-FQ + NO-EQ)
```

Across all six S3 conditions:

```text
median RMSE ratio (EQ / NO-EQ) <= 1.00
```

## Gate EQ-4 — common-front-end fairness

Under EQ, all three trackers must receive bit-identical/numerically identical equalized waveform and same sync metadata for each trial.

## Gate EQ-5 — practical vs oracle sanity

If ORACLE-EQ strongly improves residual ISI but practical EQ does not, classify:

```text
PRACTICAL_CHANNEL_ESTIMATION_LIMITED
```

Do NOT adopt the practical EQ.

If even ORACLE-EQ does not materially reduce residual ISI, classify:

```text
LINEAR_EQUALIZATION_NOT_USEFUL_FOR_CURRENT_LOCAL_CLUSTER
```

Do NOT adopt EQ.

---

# 12. Decision

If EQ-1 through EQ-4 pass and practical EQ demonstrates meaningful physical suppression:

```text
COMMON_MMSE_EQUALIZER_ADOPTED
```

The future final receiver chain becomes:

```text
HFM acquisition
-> preamble-aided regularized MMSE equalization
-> DSSS correlation / DLL
-> E-FQ reliability-calibrated fixed-Q VB tracking
```

The equalizer remains explicitly conventional.

If the gates fail:

```text
COMMON_MMSE_EQUALIZER_REJECTED
```

Keep the simpler no-EQ E-FQ receiver that already passed held-out confirmation.

Do NOT tune equalizer lengths, lambdas, c2 or Q after this result.

---

# 13. Required outputs

Under:

```text
results/equalizer_diagnostic/
```

save:

```text
equalizer_summary.csv
equalizer_mechanism.csv
equalizer_phase_stats.csv
equalizer_raw.mat
equalizer_decision.txt
```

`equalizer_summary.csv`:

```text
Profile
SNR_dB
Scenario
Frontend
Tracker
ValidRate
RMSE_Median
RMSE_Mean
BER
SyncFailRate
```

`equalizer_mechanism.csv`:

```text
Profile
SNR_dB
Frontend
ChannelEstNMSE
RMSDelaySpread
MainTapConcentration
ResidualISIFraction
PSLR
NoiseEnhancement
```

---

# 14. Required tests

Add:

### test_equalizer_channel_estimator_noiseless
Using a synthetic known short FIR:
- estimate h
- aligned NMSE finite and small
- no use of true h inside estimator

### test_equalizer_mmse_inverse
Known FIR:
- combined channel residual ISI lower after EQ
- finite w
- finite lambda

### test_equalizer_full_convolution
Tail is retained.

### test_equalizer_shared_frontend
Same equalized waveform and sync for A/VB-FQ/E-FQ.

### test_equalizer_no_oracle_leakage
Practical equalizer API cannot receive true Bellhop h.

### test_candidate_no_trm_semantics
E-FQ and VB-FQ intrinsically use no TRM.

Keep all existing gate tests.

---

# 15. Pipeline behavior

Round-7 pipeline may run:

1. all gate tests
2. equalizer diagnostic
3. decision
4. stop

DO NOT:
- run c2 final selection
- run SNR boundary scan
- run 200-MC Pilot
- run 3000-MC Paper

Those occur only after the common-front-end decision.

---

# 16. Documentation status

At the end update `PAPER_CODE_ALIGNMENT.md` according to actual evidence.

If EQ adopted:

```text
E-FQ held-out tracker architecture: PASS
Common MMSE equalizer: ADOPTED AS CONVENTIONAL FRONT-END
TRM primary contribution: REJECTED
Final tracker parameters: awaiting c2 freeze
Pilot: NOT RUN
```

If EQ rejected:

```text
E-FQ held-out tracker architecture: PASS
Common MMSE equalizer: REJECTED / NOT REQUIRED
Final architecture: no-EQ E-FQ candidate
TRM primary contribution: REJECTED
Final tracker parameters: awaiting c2 freeze
Pilot: NOT RUN
```

---

# REQUIRED FINAL REPORT

## Git
- commit SHA
- changed files

## Round-6 preserved
- held-out E-FQ PASS status unchanged

## Equalizer implementation
- Lh
- Leq
- decision delay
- noise-estimation interval
- LS regularization rule
- MMSE regularization rule

## Physical mechanism table
P1/P2/P3 at 0/15 dB:
- No-EQ residual ISI
- Practical-EQ residual ISI
- Oracle-EQ residual ISI
- Practical channel-estimation NMSE
- noise enhancement

## Tracker table
For S0 and S3:
- A noEQ / EQ RMSE
- VB-FQ noEQ / EQ RMSE
- E-FQ noEQ / EQ RMSE
- BER and valid rate

## Gates
- EQ-1
- EQ-2
- EQ-3
- EQ-4
- EQ-5 interpretation

## Decision
Exactly one:

```text
COMMON_MMSE_EQUALIZER_ADOPTED
```

or

```text
COMMON_MMSE_EQUALIZER_REJECTED
```

Final line:

```text
PILOT NOT RUN — waiting for scientific review.
```
