# Reliability Measurement Alignment Audit

## Purpose
This document audits the coordinate-frame alignment between the raw DLL delay measurement ($z_k$) and the ground truth continuous time-warp delay ($\epsilon_{true,k}$) before calculating the measurement error $e_{meas}$. This fulfills the Stage 1 priority requirement of the WUWNet'26 codex protocol.

## Measurement Extraction
The measurement $z_k$ used for this analysis is captured **before** the Kalman correction. It corresponds directly to:
```matlab
D_k = (L_pwr - E_pwr) / (E_pwr + L_pwr + 1e-9);
z_res = D_k * delta;
z_k = x_pre(1) + z_res;
```
This telemetry is strictly the raw Early/Late physical measurement of the channel delay.

## Coordinate Frame Alignment
The raw measurement $z_k$ and the ground truth delay $\epsilon_{true,k}$ originate from different initial reference frames due to:
1. The coarse synchronization process locating an initial peak that absorbs a bulk propagation delay.
2. Initial preamble time-of-flight.

A direct subtraction (`e_meas = z_k - epsilon_true`) is mathematically invalid because the origin is arbitrary. 

To resolve this, we remove a common origin (relative referencing) using the exact same convention as the final stress RMSE pipeline:
```matlab
% Reference ground truth to the first symbol
eps_true_rel = eps_true_per_symbol - eps_true_per_symbol(1);

% Reference the measurement to the first symbol
z_k_rel = z_k - z_k(1);

% Calculate the aligned measurement error
e_meas = z_k_rel - eps_true_rel;
```

This guarantees that the initial symbol is defined as delay = 0 for both the tracker and the ground truth, purely isolating the dynamic tracking performance from bulk delay offsets.

## Conclusion
The alignment strictly follows the established relative referencing rules of the repository, preventing false errors arising from bulk delay bias. The resulting $e_{meas}$ is scientifically valid for reliability evaluation.
