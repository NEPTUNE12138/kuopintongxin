# Bellhop Reproducibility Report

## Environment Sources
The physical channel models are derived from the Bellhop acoustic ray-tracing simulator located in `Bellhop2YS/`.

## Target Channels
| Channel File | Environment | Fields Used |
|---|---|---|
| `channel_15m_20km_34m.mat` | Shallow-Water (20 km, Flat, 34m depth) | delay, amplitude (from ray tracing) |
| `channel_15m_20km_3467m.mat` | Shallow-Water (20 km, Slope, 34->67m) | delay, amplitude |
| `channel_100m_45km_110m.mat` | Deep-Sea (45 km, SOFAR, 110m depth) | delay, amplitude |

## Normalization
All extracted CIRs from Bellhop are normalized to have unit energy (sum of squared amplitudes = 1) before scaling by path loss and SNR in the main simulations.

## Notes
- These MAT files must be present to successfully execute the Paper 2 pipeline in its authoritative mode. Do not delete them.
