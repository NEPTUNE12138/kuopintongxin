# Bellhop Profile Statistics Audit

This document reproduces the multipath statistics for the retained local cluster.

## Retention Rule
Used the exact same `select_bellhop_local_cluster.m` as the final paper pipeline:
- Sort arrivals by delay.
- Retain earliest contiguous cluster.
- Stop before first gap > 50 ms.

## Reproduced Statistics

| Profile | Tx/Rx/Range | Retained paths | Cluster span (ms) | RMS delay spread (ms) | Dominant Energy Fraction |
|---------|-------------|----------------|-------------------|-----------------------|--------------------------|
| P1 | Profile P1: Tx15m / 20km / Rx34m | 3 | 0.312 | 0.061 | 0.633 |
| P2 | Profile P2: Tx15m / 20km / Rx3467m | 2 | 3.008 | 1.504 | 0.507 |
| P3 | Profile P3: Tx100m / 45km / Rx110m | 2 | 1.833 | 0.134 | 0.995 |
