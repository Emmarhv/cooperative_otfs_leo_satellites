# Cooperative Waveform Transmission and Design for LEO Satellites

This repository contains the MATLAB source code and result files associated with the
Bachelor Thesis *"Cooperative Waveform Transmission and Design for LEO Satellites"*
(Emma Rodriguez Hervas, Universidad Carlos III de Madrid, 2026).

The repository version corresponding to the thesis submission is tagged `v1.0-tfg`.

## Repository structure

| Path | Description |
|---|---|
| `pipeline/` | Final MATLAB simulation, validation and reporting code. |
| `results/` | Frozen `.mat` result files, generated figures (PNG/PDF/FIG) and tables (CSV). |
| `archive/` | Historical result files retained to support baseline validation and to reconstruct the consolidated result files. Not part of the primary execution path. |
| `ARCHITECTURE.md` | Per-file reference: what every script and function in `pipeline/` does, and the exact command to run each entry-point script. |

### `pipeline/` contents

| Subfolder | Role |
|---|---|
| `main/` | Entry-point scripts for each transmission scheme (baseline, proposal, no-compensation, load trade-off) and for figure/table generation. |
| `reconstruction/` | Scripts that rebuild the consolidated result files (`final_comparison_results.mat`, `load_tradeoff_official_results.mat`) from `archive/`. Not required to reproduce thesis figures -- only for auditing how those files were assembled. |
| `validation/` | Regression checks of the simulation engines against historical reference data in `archive/`. |
| `config/`, `channel/`, `compensation/`, `modulation/`, `otfs/`, `receiver/`, `metrics/`, `utils/`, `framing/`, `mapper/`, `resource_allocation/`, `operators/`, `timing_residual/`, `los_channel_noise/` | Supporting functions used by the scripts above. |

For a description of every individual file in `pipeline/` (what it does, and
the exact command to run each entry-point script on its own), see
[`ARCHITECTURE.md`](ARCHITECTURE.md).

## Software requirements

- MATLAB (developed and tested with R2024a)
- Communications Toolbox

No other toolboxes are required.

## Reproducing the results

Two independent levels of reproduction are supported.

### 1. Reproduce the thesis figures and tables (recommended)

This regenerates every figure and table reported in the thesis directly from the frozen
result files in `results/`. No simulation is executed, this completes in seconds.

```matlab
run('pipeline/main/run_final_reporting.m')
```

Additional scripts in `pipeline/main/` regenerate specific figure sets (e.g.
`run_sensitivity_reporting.m`, `run_load_tradeoff_pipeline.m` - see comments at the top
of each file).

### 2. Audit or reconstruct the consolidated result files

This step is optional and is provided only for traceability. It rebuilds the consolidated
`.mat` files in `results/` from the historical experiment outputs stored in `archive/`,
and internally re-validates every reconstructed value against its original source.

```matlab
run('pipeline/reconstruction/run_build_final_comparison.m')
run('pipeline/reconstruction/run_load_tradeoff_pipeline.m')
```

### 3. Validate the simulation engines against historical reference data

```matlab
run('pipeline/validation/run_official_baseline_validation.m')
run('pipeline/validation/run_official_no_compensation_validation.m')
run('pipeline/validation/run_official_proposal_validation.m')
```

### Running Monte Carlo simulation

The scripts in `pipeline/main/` (e.g. `main_baseline.m`, `main_different_grid.m`,
`main_no_compensation.m`) can be run directly to generate new results with the production
budget (200 target errors or 2x10^7 bits per operating point). This is **not required**
to reproduce the thesis results and can take a substantial amount of time depending on
the configuration.

## Notes

- All scripts add the full repository to the MATLAB path automatically on execution; no
  manual path configuration is required.
- `archive/` is retained for traceability and is not part of the primary execution path
  described above.
