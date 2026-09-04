# ARCHITECTURE.md

Reference for every file in `pipeline/`: what it does, and (for entry-point
scripts) how to run it. For the two-line "how do I reproduce the thesis
results" version, see `README.md`. This document goes one level deeper: one
entry per file, grouped by subfolder, with the description taken directly
from each file's own header comment.

## Contents

- [`pipeline/main/`](#pipelinemain) --- Entry points: baseline / proposal / no-compensation / load trade-off
- [`pipeline/reconstruction/`](#pipelinereconstruction) --- Reconstruction (optional, audits how the frozen results/*.mat files were built)
- [`pipeline/validation/`](#pipelinevalidation) --- Validation (regression checks against archive/ reference data)
- [`pipeline/config/`](#pipelineconfig) --- Configuration builders
- [`pipeline/channel/`](#pipelinechannel) --- Channel and precoder model
- [`pipeline/compensation/`](#pipelinecompensation) --- Precoder application (receiver-side)
- [`pipeline/modulation/`](#pipelinemodulation) --- Modulation / symbol mapping
- [`pipeline/otfs/`](#pipelineotfs) --- OTFS modulator / demodulator core
- [`pipeline/receiver/`](#pipelinereceiver) --- Receiver combining
- [`pipeline/metrics/`](#pipelinemetrics) --- Result metrics and BER bounds
- [`pipeline/utils/`](#pipelineutils) --- Small utility / seed-code helpers
- [`pipeline/framing/`](#pipelineframing) --- Proposal physical framing
- [`pipeline/mapper/`](#pipelinemapper) --- Frozen resource-mapper catalog access
- [`pipeline/resource_allocation/`](#pipelineresource_allocation) --- Resource-mapper index construction
- [`pipeline/reporting/`](#pipelinereporting) --- Figure and table generation
- [`pipeline/operators/`](#pipelineoperators) --- Cross-grid modulate/demodulate operators (different-grid proposal)
- [`pipeline/timing_residual/`](#pipelinetiming_residual) --- Timing-residual stream combination helpers
- [`pipeline/los_channel_noise/`](#pipelinelos_channel_noise) --- Line-of-sight noise/SNR combination helpers
- [`results/` and `archive/`](#results-and-archive)

## `pipeline/main/`

Entry points: baseline / proposal / no-compensation / load trade-off

### `main_baseline.m`

**Run:** `results = main_baseline(...)` (call from within `pipeline/main/`, or after `cd`-ing there so MATLAB can locate it -- see README.md).

```text
 Official entry point for the same-grid published baseline
 (M=1024, N=32, P=3 truncated precoder).

 Runs one physical BER Monte Carlo point per requested
 (modulation, NR) combination, using the validated official
 chain:

   build_official_config('baseline', ...) -> run_baseline_point

 Input:
 - requests : struct array with fields
     .modulation  ('QPSK' or '16-QAM')
     .NR
   If omitted, a small nominal spot-check set is used:
     QPSK and 16-QAM, each at NR=256.

 Output:
 - results : struct array of unified result structs, one per
             request, see build_result_struct.m

 Each point uses build_official_config's own deterministic,
 isolated per-point seed (NOT the continuous-RNG sweep of the
 frozen main_baseline_no_geom.m script). See
 build_official_config.m for the reproducibility-policy note.
```

### `main_different_grid.m`

**Run:** `results = main_different_grid(...)` (call from within `pipeline/main/`, or after `cd`-ing there so MATLAB can locate it -- see README.md).

```text
 Official entry point for the heterogeneous-grid cooperative
 proposal.

 One physical Monte Carlo point is executed per requested
 operating configuration.

 Request fields:

   .modulation
   .k
   .powerPolicy
   .NR

 Optional common overrides:

   'Seed'
   'MaxBits'
   'TargetErrors'

 Example:

   req.modulation = 'QPSK';
   req.k = 8;
   req.powerPolicy = 'boosted';
   req.NR = 256;

   results = main_different_grid(req);

 For a short regression:

   results = main_different_grid(req, ...
       'MaxBits', 5e5, ...
       'TargetErrors', 20);
```

### `main_load_tradeoff.m`

**Run:** `results = main_load_tradeoff(...)` (call from within `pipeline/main/`, or after `cd`-ing there so MATLAB can locate it -- see README.md).

```text
 Official, read-only load-tradeoff pipeline.

 Loads the ALREADY VALIDATED AND SAVED load-tradeoff BER
 Monte Carlo archives and the already-computed rate/SE
 results, joins them by key (modulation, k, NR, powerPolicy),
 filters to the officially characterized family, and packages
 every point into the common official result-struct schema
 (build_result_struct.m / build_load_tradeoff_result.m).

 This script launches NO Monte Carlo simulation and calls NO
 B2/B3/B4 simulation engine (run_baseline_point,
 run_no_compensation_point, run_proposal_point,
 main_different_grid, ...). It only reads:

   archive/load_tradeoff/
       load_tradeoff_ber_boosted.mat
       load_tradeoff_ber_unboosted.mat
       rate_per_load_results.mat

 Officially characterized family (nominal marked with *):

   QPSK    k = 7*, 8, 9, 10
   16-QAM  k = 4*, 5, 6, 7, 8

 k > 10 (QPSK) / k > 8 (16-QAM) exist in the saved archives
 as additional experimental spot-checks (partial N_R
 coverage) but are NOT part of the officially characterized
 family and are explicitly excluded here. The archive .mat
 files themselves are never modified.

 N_R grid: only the four values that actually have saved
 Monte Carlo results are used here: [64 144 256 400]. N_R=100
 and N_R=576 belong to the later final-comparison grid
 (build_official_config.m finalComparisonNR) and are
 deliberately NOT interpolated or fabricated in this
 load-tradeoff study.

 Output:
 - results : struct with fields
     .boosted    : 1x36 array of common result structs
     .unboosted  : 1x36 array of common result structs
     .all        : 1x72 array, [boosted, unboosted]
```

### `main_no_compensation.m`

**Run:** `results = main_no_compensation(...)` (call from within `pipeline/main/`, or after `cd`-ing there so MATLAB can locate it -- see README.md).

```text
 Official entry point for the B3 ablation: same-grid baseline
 physics without satellite-2 TX compensation
 (applyPrecoder=false, the physically meaningful default).

 Runs one physical BER Monte Carlo point per requested
 (modulation, NR) combination, using the validated official
 chain:

   build_official_config('no_compensation', ...)
       -> run_no_compensation_point

 Input:
 - requests : struct array with fields
     .modulation  ('QPSK' or '16-QAM')
     .NR
   If omitted, a small nominal spot-check set is used:
     QPSK and 16-QAM, each at NR=256.

 Output:
 - results : struct array of unified result structs, one per
             request, see build_result_struct.m

 This entry point always uses applyPrecoder=false (the actual
 ablation). The applyPrecoder=true validation mode is only
 used inside official/validation/, never here.
```

### `run_baseline_point.m`

**Run:** `results = run_baseline_point(...)` (call from within `pipeline/main/`, or after `cd`-ing there so MATLAB can locate it -- see README.md).

```text
 Single-operating-point physical BER Monte Carlo engine for
 the official same-grid baseline (M=1024, N=32, P=3 truncated
 precoder), reproducing the published reference scenario.

 Physical chain (unchanged from main_baseline_no_geom.m):

   bits -> QAM symbols -> M-by-N DD grid
   Sat1: otfs_modulate -> los_channel(0,0,0,1)
   Sat2: apply_precoder_blocks -> otfs_modulate
         -> los_channel(iEff,kEff,kappaEff,1)
   combine_weighted_links (gamma1, gamma2)
   add_normalized_complex_noise (gammaOut)
   otfs_demodulate
   /gammaOut -> QAM detection -> BER

 Reproducibility: this function resets rng() once, from a
 seed built only out of this config's own fields (base seed,
 modulation code, N_R code). Every call with the same config
 therefore reproduces exactly, independent of call order or
 of any other operating point. This is a DIFFERENT
 reproducibility policy than the frozen historical script
 main_baseline_no_geom.m, which draws all of its
 modulation x N_R sweep from one continuous RNG stream. See
 build_official_config.m and
 official/validation/run_legacy_baseline_sweep.m for the
 historical-equivalence regression.

 Input:
 - config : struct returned by
            build_official_config('baseline', ...)

 Output:
 - result : common official result struct, see
```

### `run_final_no_compensation.m`

**Run:** `run('pipeline/main/run_final_no_compensation.m')`

```text
 One-click, resumable launcher for the FINAL B3 ablation
 Monte Carlo (same cooperative data, same-grid baseline
 physics, satellite-2 WITHOUT TX compensation).

 Runs EXACTLY these 12 operating points and nothing else:

   QPSK,   NR = [64 100 144 256 400 576]
   16-QAM, NR = [64 100 144 256 400 576]

 at TargetErrors=200, MaxBits=20e6 (production budget), using
 the already-validated official B3 chain:

   build_official_config('no_compensation', ...)
       -> run_no_compensation_point (ApplyPrecoder=false)

 This script does NOT touch B2 (baseline), B4 (proposal), the
 legacy Scenario A/B/C/D checkpoints, or any historical
 results file. It opens no new k values, power policies,
 mappers, or studies beyond these 12 points.

 Checkpointing / resumability:
   Each completed point is appended to the output .mat file
   IMMEDIATELY after it finishes (not batched at the end). On
   a fresh run, the script loads the output file if it already
   exists, builds the set of already-completed
   (modulation, NR) keys, and SKIPS any point already present.
   Re-running this script after an interruption therefore
   resumes from the next missing point instead of repeating
   completed ones.

 Output file (official B3 result archive, created here, never
 overwriting any historical file):

   results/
       no_compensation_final_results.mat
```

### `run_final_reporting.m`

**Run:** `run('pipeline/main/run_final_reporting.m')`

```text
 One-click launcher for the FINAL TFG reporting pipeline.

 This script performs NO simulation.

 It only loads the already-frozen official/historical result
 archives and generates:

   - main BER comparison figures
   - proposal boosted/unboosted figures
   - nominal payload-SE comparison
   - load BER figures for different k
   - load SE-vs-BER trade-off figures
   - final CSV result tables

 Numerical Monte Carlo results are never modified.
```

### `run_no_compensation_point.m`

**Run:** `results = run_no_compensation_point(...)` (call from within `pipeline/main/`, or after `cd`-ing there so MATLAB can locate it -- see README.md).

```text
 Single-operating-point physical BER Monte Carlo engine for
 the official B3 ablation.

 B3 uses the same physical model as the compensated baseline:

   M = 1024
   N = 32
   same residual delay and Doppler
   same link budget
   same noise model
   same receiver processing
   same Monte Carlo seed policy

 The only physical toggle is satellite-2 TX compensation:

   applyPrecoder = true
       Validation mode. Satellite 2 applies the same
       compensation as the official baseline.

   applyPrecoder = false
       Actual B3 scenario. Satellite 2 transmits xDD directly,
       without apply_precoder_blocks.

 The same resolved seed is deliberately used in both modes.
 This creates a paired Monte Carlo comparison: common frames
 use the same transmitted bits and random-noise sequence, so
 the relevant physical difference is the presence or absence
 of satellite-2 TX compensation.

 Physical chain:

   bits -> QAM symbols -> M-by-N DD grid

   Sat1:
       otfs_modulate
       -> los_channel(0,0,0,1)

   Sat2:
       optional apply_precoder_blocks
       -> otfs_modulate
       -> los_channel(iEff,kEff,kappaEff,1)

   weighted time-domain combination
   -> normalized complex noise
   -> OTFS demodulation
   -> equalization
   -> QAM detection
   -> BER

 Input:
 - config : struct returned by
            build_official_config('no_compensation', ...)

 Output:
 - result : common official result struct
```

### `run_proposal_point.m`

**Run:** `results = run_proposal_point(...)` (call from within `pipeline/main/`, or after `cd`-ing there so MATLAB can locate it -- see README.md).

```text
 Single-operating-point physical BER Monte Carlo engine for
 the official N1~=N2 cooperative proposal.

 This is a single-point specialization of the validated
 load-tradeoff BER engine. The physical chain is unchanged.

 Physical chain:

   common cooperative payload
   -> active-symbol power policy
   -> RCP framing and relative timing
   -> physical differential Doppler
   -> linear combination of satellite streams
   -> common AWGN realization
   -> Sat1/Sat2 receiver references
   -> equalization
   -> SNR-weighted cooperative combining
   -> detection
   -> BER

 Input:
 - config : struct returned by build_official_config.m

 Output:
 - result : common official result struct
```

### `run_residual_sensitivity_analysis.m`

**Run:** `run('pipeline/main/run_residual_sensitivity_analysis.m')`

```text
 Final, one-click and resumable sensitivity analysis for the
 heterogeneous-grid proposal (N1~=N2).

 The experiment isolates three physical effects:

   1) residual timing mismatch;
   2) residual Doppler mismatch;
   3) unequal satellite slant ranges through the link budget.

 This is NOT an orbital-geometry reconstruction. Satellite
 trajectories are not generated. The analysis varies directly
 the equivalent parameters already used by the validated
 physical communication model.

 Frozen proposal design:

   QPSK   -> k=7, boosted
   16-QAM -> k=4, boosted

 No mapper is recomputed or optimized during the sweeps.

 Sweep 1: residual timing [samples]

   delta = [-3069 -1023 -504 0 504 1023 3069]

 Sweep 2: residual Doppler [Hz]

   nuRelHz = [-26460 -13230 -6615 0 6615 13230 26460]

 Sweep 3: slant-range imbalance [km]

   Delta_r = r2-r1 = [0 35 69.89 105 140] km

   r1 = 588.08 km is fixed.

 Published nominal operating point:

   delta       = 504 samples
   nuRelHz     = -13.23 kHz
   r1          = 588.08 km
   r2          = 657.97 km
   r2-r1       = 69.89 km

 This nominal physical point belongs to all three sweeps:

   logical plotting points = (7+7+5)*2*6 = 228
   unique Monte Carlo runs = (7+7+5-2)*2*6 = 204

 The nominal result is simulated once and reused for the two
 other logical occurrences having exactly the same physical
 configuration.

 Production budget:

   TargetErrors = 200
   MaxBits      = 20e6
   N_R          = [64 100 144 256 400 576]

 Checkpointing:

   Every completed logical point is saved immediately.
   Re-running the script resumes from the next missing point.

 Output:

   results/sensitivity_analysis/
       residual_sensitivity_results.mat
```

### `run_sensitivity_reporting.m`

**Run:** `run('pipeline/main/run_sensitivity_reporting.m')`

```text
 One-click reporting launcher for the final sensitivity
 analyses of the heterogeneous-grid proposal.

 Generates:

   1) Residual timing sensitivity:
      - QPSK
      - 16-QAM

   2) Residual Doppler sensitivity:
      - QPSK
      - 16-QAM

   3) Slant-range imbalance sensitivity:
      - QPSK
      - 16-QAM

   4) Joint timing-Doppler 2-D sensitivity:
      - QPSK
      - 16-QAM

 Input:

   results/sensitivity_analysis/

 Output:

   results/sensitivity_analysis/
       figures/

 No simulation is performed here. This script only loads
 completed production results and calls reporting functions.
```

### `run_timing_doppler_2d_sensitivity.m`

**Run:** `run('pipeline/main/run_timing_doppler_2d_sensitivity.m')`

```text
 Final 2-D residual timing-Doppler sensitivity analysis for
 the heterogeneous-grid proposal (N1~=N2).

 Purpose:
   Complement the three one-dimensional sensitivity sweeps
   with a joint timing-Doppler study.

 This verifies the behaviour when both residual
 synchronization errors vary simultaneously.

 This is NOT an orbital-geometry reconstruction.

 Frozen proposal:

   QPSK   -> k=7, boosted
   16-QAM -> k=4, boosted

 Fixed receive-array size:

   N_R = 256

 Fixed slant ranges:

   Sat1 = 588.08 km
   Sat2 = 657.97 km

 Timing grid [samples]:

   delta = [-1023 -504 0 504 1023]

 Doppler grid [Hz]:

   nuRelHz = [-26460 -13230 0 13230 26460]

 Total:

   5 timing x 5 Doppler x 2 modulations = 50 points

 Published nominal operating point:

   delta   = 504 samples
   nuRelHz = -13.23 kHz

 Monte Carlo budget:

   TargetErrors = 200
   MaxBits      = 20e6

 Checkpointing:

   Every completed point is saved immediately.
   Re-running resumes automatically.

 Output:

   results/sensitivity_analysis/
       timing_doppler_2d_sensitivity_results.mat
```

## `pipeline/reconstruction/`

Reconstruction (optional, audits how the frozen results/*.mat files were built)

### `run_build_final_comparison.m`

**Run:** `run('pipeline/reconstruction/run_build_final_comparison.m')`

```text
 One-click, read-only launcher that consolidates the FOUR
 official main scenarios into a single canonical archive:

   results/final_comparison_results.mat

 for finalComparisonNR = [64 100 144 256 400 576], QPSK and
 16-QAM:

   1. single_satellite
   2. baseline_compensated
   3. no_compensation
   4. proposal (nominal, boosted only: QPSK k=7 / 16-QAM k=4)

 The canonical archive contains two separate result sets:

   mainResults
       Four main comparison scenarios:
       - single_satellite
       - baseline_compensated
       - no_compensation
       - proposal boosted

   proposalPowerResults
       Separate boosted-vs-unboosted analysis of the nominal
       heterogeneous-grid proposal.

 Explicitly OUT OF SCOPE:
   - legacy independent-data / interference Scenario B.

 Proposal unboosted results are official, but they belong only
 to proposalPowerResults and are never treated as a fifth main
 scenario.

 Source files:
   single_satellite      : comparison_scenarios/results/
                           montecarlo_scenario_a_b_results.mat
                           (allResultsA.QPSK / .QAM16)
   baseline_compensated  : archive/baseline_validation_reference/
                           baseline_no_geom_ber_results.mat
   no_compensation       : results/
                           no_compensation_final_results.mat
   proposal QPSK k=7     : results/los_channel_noise/data/
                           checkpoint_f_ber_montecarlo_results_finalized.mat
   proposal 16-QAM k=4   : archive/proposal_16qam/
                           results/
                           checkpoint_f_16qam_ber_montecarlo_boosted_results.mat
```

### `run_load_tradeoff_pipeline.m`

**Run:** `run('pipeline/reconstruction/run_load_tradeoff_pipeline.m')`

```text
 One-click launcher for the official, read-only load-tradeoff
 pipeline (main_load_tradeoff.m).

 This script:
   1. Adds the complete project to the MATLAB path.
   2. Calls main_load_tradeoff(), which reads the already
      validated and saved BER/rate archives and packages them
      into the common official result-struct schema.
   3. Prints a compact per-scenario summary.

 No Monte Carlo simulation is executed by this script or by
 main_load_tradeoff.m. Every number comes from:

   archive/load_tradeoff/
       load_tradeoff_ber_boosted.mat
       load_tradeoff_ber_unboosted.mat
       rate_per_load_results.mat
```

## `pipeline/validation/`

Validation (regression checks against archive/ reference data)

### `build_frozen_mapper_catalog.m`

**Run:** `results = build_frozen_mapper_catalog(...)` (call from within `pipeline/validation/`, or after `cd`-ing there so MATLAB can locate it -- see README.md).

```text
 Promote the physically characterized heterogeneous-grid
 mappers from the experimental load-tradeoff results into a
 frozen catalog used by the official runtime pipeline.

 This function is a one-time promotion/validation utility.
 The official runtime does NOT call the experimental mapper
 design pipeline.

 Promoted family:

   QPSK    k = 7, 8, 9, 10
   16-QAM  k = 4, 5, 6, 7, 8

 Output:

   official/mapper/frozen_mapper_configs.mat
```

### `run_official_baseline_validation.m`

**Run:** `run('pipeline/validation/run_official_baseline_validation.m')`

```text
 One-click validation launcher for the official same-grid
 baseline (M=1024, N=32, P=3 truncated precoder).

 This script:
   1. Adds the complete project to the MATLAB path.
   2. Runs the baseline-vs-frozen-script regression
      (bit-exact for the first two QPSK operating points,
      plus a 9-point link-budget cross-check).
   3. Runs a short, capped-budget spot check of the official
      run_baseline_point.m engine itself (deterministic
      isolated-point seed policy, NOT the continuous-RNG
      sweep used by the regression above).
   4. Stops with an error if any check fails.

 No full production Monte Carlo (minErrors=200,
 maxBits=2e7 across all 9 N_R x 2 modulations) is executed
 here.
```

### `run_official_no_compensation_validation.m`

**Run:** `run('pipeline/validation/run_official_no_compensation_validation.m')`

```text
 One-click launcher for the official B3 no-compensation
 regression.

 Run this script directly from MATLAB.
```

### `run_official_proposal_validation.m`

**Run:** `run('pipeline/validation/run_official_proposal_validation.m')`

```text
 One-click validation launcher for the official heterogeneous-
 grid cooperative proposal.

 This script:
   1. Adds the complete project to the MATLAB path.
   2. Creates the frozen official mapper catalog only if it
      does not exist yet.
   3. Runs the official mapper and physical-flow regressions.
   4. Reads the saved validation evidence.
   5. Stops with an error if any official regression fails.

 No full production Monte Carlo is executed here.
```

### `validate_official_baseline_vs_reference.m`

**Run:** `results = validate_official_baseline_vs_reference(...)` (call from within `pipeline/validation/`, or after `cd`-ing there so MATLAB can locate it -- see README.md).

```text
 Bit-exact cross-check of the official baseline physics
 (the same function calls used inside run_baseline_point.m)
 against real, saved evidence produced by an actual past
 execution of the frozen script main_baseline_no_geom.m:

   archive/baseline_validation_reference/baseline_no_geom_ber_results.mat

 The historical script resets rng() exactly ONCE
 (rng(berParams.randomSeed)) before its modulation x N_R
 sweep and then draws every frame from that single continuous
 stream, in a fixed loop order (QPSK then 16-QAM; N_R ordered
 as berParams.numRxElementsVec). Individual sweep points are
 therefore not independently reproducible in general -- EXCEPT
 the first one or two points immediately following the single
 reset, which this script reproduces exactly by replaying the
 same reset and the same first frames, with no shortcuts.

 This validation intentionally does NOT reset rng() per point
 (unlike the official runtime engine run_baseline_point.m,
 which uses a different, isolated-point seed policy -- see
 build_official_config.m). It exists only to prove that the
 physical chain reused by the official engine (otfs_modulate,
 los_channel, apply_precoder_blocks, combine_weighted_links,
 add_normalized_complex_noise, otfs_demodulate,
 demodulate_symbols, compute_ber) reproduces the frozen
 script bit-for-bit when driven the same way.
```

### `validate_official_no_compensation_vs_reference.m`

**Run:** `results = validate_official_no_compensation_vs_reference(...)` (call from within `pipeline/validation/`, or after `cd`-ing there so MATLAB can locate it -- see README.md).

```text
 Regression validation for the official B3
 no-compensation ablation.

 Three properties are checked:

 A. PHYSICAL-CONFIGURATION MATCH
    Baseline and no-compensation use the same physical and
    Monte Carlo parameters. The intended difference is the
    satellite-2 TX compensation toggle.

 B. COMPENSATED EQUIVALENCE
    With applyPrecoder=true, run_no_compensation_point.m must
    reproduce the official baseline Monte Carlo counts
    exactly for the same operating point.

 C. PAIRED ABLATION SANITY CHECK
    With applyPrecoder=false:

      - the same resolved Monte Carlo seed is used;
      - the receiver processing remains unchanged;
      - the BER is worse than the compensated baseline for
        the selected deterministic validation cases.

 The last condition is a sanity check for these fixed test
 cases, not a general mathematical requirement for every
 possible short Monte Carlo realization.
```

### `validate_official_proposal_vs_reference.m`

**Run:** `results = validate_official_proposal_vs_reference(...)` (call from within `pipeline/validation/`, or after `cd`-ing there so MATLAB can locate it -- see README.md).

```text
 Fast regression of the official heterogeneous-grid proposal.

 Validation has two independent layers:

   A. Frozen mapper catalog vs validated experimental source
   B. Official physical engine vs reference flow

 Both physical flows intentionally reuse the same validated
 low-level physical helpers. The regression therefore checks
 the official assembly, configuration, mapper promotion,
 seed convention, stopping logic and BER counters without
 reimplementing already validated physical functions.

 No full 20-million-bit Monte Carlo is required.
```

## `pipeline/config/`

Configuration builders

### `build_baseline_config.m`

```text
 Assemble the official same-grid configuration shared by the
 'baseline' (compensated) and 'no_compensation' scenarios.

 Both scenarios use the identical physical grid, residual
 offsets, precoder blocks and link budget; they differ only in
 whether the Satellite-2 residual precoder is actually applied
 at the receiver, controlled by the required 'ApplyPrecoder'
 name-value pair:

   'ApplyPrecoder', true   -> baseline (compensated)
   'ApplyPrecoder', false  -> no_compensation

 Every value assembled here is read directly from already
 validated sources; no new formulas are introduced:

   simulation_parameters('baseline')   -> M, N, cpLength,
                                           referenceCpLength,
                                           samplePeriod,
                                           precoderTruncationOrder,
                                           bandwidth
   channel_scenario()                  -> validationReference
                                           (iEff, kEff, kappaEff),
                                           satellite slant ranges,
                                           link-budget constants
   build_precoder_blocks_adapted(...)  -> precoderBlocks
   reference_ber_parameters()          -> seed, minErrors, maxBits,
                                           numRxElementsVec

 This mirrors the field-by-field mapping extracted (read-only)
 from the historical reference script main_baseline_no_geom.m.

 Optional overrides:

   'Seed'          Monte Carlo base seed
   'MaxBits'       Monte Carlo bit budget
   'TargetErrors'  Monte Carlo error-count stopping criterion

 If omitted, all three recover the frozen nominal values from
 reference_ber_parameters().
```

### `build_official_config.m`

```text
 Thin dispatcher preserving the original single-entry-point
 interface used throughout the pipeline:

   build_official_config(scenario, modulation, k, powerPolicy, NR, ...)

 The actual configuration logic lives in two dedicated
 builders, since 'baseline'/'no_compensation' and 'proposal'
 are structurally different configurations that happen to
 share a common calling convention:

   scenario = 'baseline'         -> build_baseline_config(..., 'ApplyPrecoder', true)
   scenario = 'no_compensation'  -> build_baseline_config(..., 'ApplyPrecoder', false)
   scenario = 'proposal'         -> build_proposal_config(...)

 For 'baseline' and 'no_compensation', k and powerPolicy are
 not applicable: callers must pass k = NaN and
 powerPolicy = 'not_applicable', matching every existing call
 site in the pipeline.
```

### `build_proposal_config.m`

```text
 Assemble the official heterogeneous-grid proposal
 configuration.

 Extracted unmodified from the 'proposal' branch of
 build_official_config.m (the previous single-scenario
 implementation). Only the input signature changed: the
 'scenario' argument was removed because this function is now
 called exclusively for the 'proposal' scenario, dispatched by
 build_official_config.m.

 Optional proposal-specific sensitivity overrides:

   'Delta'       residual timing offset [samples], integer
   'NuRelHz'     residual Doppler offset [Hz]
   'RangeSat1'   satellite-1 slant range [m], positive
   'RangeSat2'   satellite-2 slant range [m], positive

 If omitted, all four parameters recover exactly the frozen
 nominal proposal configuration.
```

### `channel_scenario.m`

```text
 Physical configuration shared by the cooperative baseline
 and the proposed different-grid method.

 This file contains scenario, geometry and link-budget
 parameters only. OTFS and simulation settings are defined in
 simulation_parameters.m.

 Published effective residual indices are kept only as
 validation references. They are not used as physical inputs.
```

### `nominal_proposal_config_1024_16_64.m`

```text
 Official nominal configuration of the N1~=N2 cooperative
 proposal after validation of the M=16 -> M=1024 scale-up.

 Lcp=M-1 is the current reference-case choice. It must not be
 interpreted as a universal RCP requirement.

 Independent parameters:
 - M
 - N1, N2
 - deltaF
 - Lcp
 - modOrder
 - activeRows

 Derived parameters:
 - Ncommon
 - K1, K2
 - sampleTime
```

### `reference_ber_parameters.m`

```text
 Configuration specific to the reference BER experiment.

 Physical parameters are defined in channel_scenario.m.
 OTFS and baseline simulation parameters are defined in
 simulation_parameters('baseline').

 This file contains only experiment-specific settings:
 - receive-array sweep;
 - tested modulations;
 - Monte Carlo stopping criteria;
 - random seed;
 - output configuration.
```

### `simulation_parameters.m`

```text
 Centralized configuration for all simulation scenarios.

 Scenarios:
 - 'awgn'           : QAM over AWGN
 - 'otfs_awgn'      : OTFS over AWGN
 - 'single_los'     : single-satellite LoS channel
 - 'dual_no_comp'   : two satellites without precoding
 - 'baseline'       : cooperative system with common OTFS grid
 - 'different_grid' : proposed system with different Doppler
                      grid sizes

 OTFS convention:
 - M : number of delay bins
 - N : number of Doppler bins

 Validation scenarios use Eb/N0.
 Physical cooperative scenarios use link-budget SNR gamma.
```

## `pipeline/channel/`

Channel and precoder model

### `build_precoder_blocks_adapted.m`

```text
 Build one L x L transmit-precoder block B^q for each output
 delay row q of a single-user, single-path residual OTFS link.

 The Doppler coefficients c^l follow eq. (9) of:
 "Cooperative Dual LEO Satellite Transmission in Multi-User
 OTFS Systems".

 The base matrix is formed as in eqs. (10)-(12):

   Cmat = [(c^0)^H, ..., (c^(L-1))^H]

 where column m corresponds to output Doppler index m, and each
 row corresponds to an input Doppler index r. Since the channel
 term reads input Doppler position

   r = (m-l) mod L,

 the coefficient multiplying input position r is

   c^l,  with l = (m-r) mod L.

 For q >= ieff, the implementation coincides with the published
 no-wrap expression.

 For q < ieff, the project-adapted channel model uses the wrap
 phase

   exp(-j*2*pi*r/L),

 with r the input Doppler index. In the precoder its conjugate
 therefore multiplies the rows of Cmat.

 The common Doppler phase for output delay row q is

   exp(j*2*pi*Omega*(q-ieff)/(M*L)),

 with Omega = keff + kappaeff.

 Inputs:
 - M, L        : number of delay and Doppler bins
 - ieff        : integer residual delay, 0 <= ieff < M
 - keff        : integer residual Doppler
 - kappaeff    : fractional residual Doppler
 - truncationOrder : optional non-negative integer P. When
                    provided, only the Doppler coefficients c^l
                    with l in the window {keff-P,...,keff+P}
                    (mod L) are kept; every other c^l is set to
                    zero. This reduces the number of active
                    Doppler taps to Ls = 2*P+1 <= L, matching the
                    reduced-coefficient precoder described in the
                    reference formulation. Omit or pass [] to keep
                    all L coefficients (default, current
                    validated behavior).

 Output:
 - precoderBlocks  : M x 1 cell array
                     precoderBlocks{q+1} contains the L x L
                     precoder B^q for output delay row q
 - numActiveCoeffs : number of non-zero Doppler coefficients
                     actually used (Ls). Equals L when no
                     truncation is applied.
 - cvec            : 1 x L row vector with the Doppler
                     coefficients c^l actually used (after
                     truncation, if any -- zeroed entries
                     outside the kept window). Exposed so
```

### `compute_link_snr.m`

```text
 Compute the effective received SNR of one satellite link
 from the physical link budget:

   gamma = EIRP * N_R * G_R
```

### `los_channel.m`

```text
 Single-path LoS channel over one useful OTFS block.

 Channel model:

   rx[n] = h ...
         * exp(j*2*pi*(k+kappa)*(n-l)/(M*N)) ...
         * tx[(n-l) mod (M*N)]

 Processing:
   circular integer delay
   -> integer/fractional Doppler
   -> complex LoS gain

 The circular delay represents the CP-protected equivalent
 block model. Explicit propagation delay, CP transmission and
 timing acquisition are not modeled inside this function.

 This physical channel convention follows:
 "Coordinated Multi-Satellite Transmission for OTFS-Based
 6G LEO Satellite Communication Systems", eqs. (8)-(10).

 Inputs:
 - tx      : useful time-domain OTFS block, row or column
 - M       : number of delay bins
 - N       : number of Doppler bins
 - l       : integer delay tap, 0 <= l < M
 - k       : integer Doppler tap
 - kappa   : fractional Doppler, -0.5 < kappa <= 0.5
 - h       : complex LoS channel gain

 Output:
 - rx      : received block, with the same orientation as tx
```

## `pipeline/compensation/`

Precoder application (receiver-side)

### `apply_precoder_blocks.m`

```text
 Apply the Doppler precoder blocks B^q and pre-compensate the
 residual integer-delay permutation at the transmitter.

 The blocks B^q are built according to the row-wise precoder
 formulation used in P7. They compensate the Doppler effect
 within each delay row.

 In the original P7 formulation, after precoding the symbols
 are still affected by the cyclic row permutation caused by
 lEff. This permutation is later handled at the receiver
 through the Pi^l term.

 In this project, the inverse row permutation is instead moved
 to the transmitter:

   temp[q,:] = B^q * xDD[q,:]
   pDD       = circshift(temp, -lEff, 1)

 Therefore, B^q compensates the Doppler effect and the final
 circshift pre-compensates the integer delay. This allows the
 satellite branch to be already delay-aligned before the two
 links are combined.

 Inputs:
 - xDD            : M x L delay-Doppler input grid
 - precoderBlocks : M precoder blocks B^q of size L x L
 - lEff           : residual integer delay, 0 <= lEff < M

 Output:
 - pDD : M x L precoded grid, ready for OTFS modulation
```

## `pipeline/modulation/`

Modulation / symbol mapping

### `demodulate_symbols.m`

```text
 Demodulate square M-QAM symbols using Gray mapping and
 unit-average-power normalization.

 Inputs:
 - symbols : received complex QAM symbols
 - params  : struct containing modOrder and bitsPerSymbol

 Output:
 - bits : estimated binary column vector
```

### `modulate_symbols.m`

```text
 Map binary data to square M-QAM symbols using Gray mapping
 and unit-average-power normalization.

 Supported orders include QPSK/4-QAM, 16-QAM and 64-QAM.

 Inputs:
 - bits   : binary input vector
 - params : struct containing modOrder and bitsPerSymbol

 Output:
 - symbols : complex QAM symbol column vector
```

## `pipeline/otfs/`

OTFS modulator / demodulator core

### `isfft.m`

```text
 Inverse Symplectic Finite Fourier Transform (ISFFT).
 Maps delay-Doppler domain symbols to the time-frequency domain.

 Grid convention:
 - Input  xDD(k,l) : k = 0..M-1 delay index   (ROWS)
                     l = 0..N-1 Doppler index (COLUMNS)
 - Output XTF(m,n) : m = 0..M-1 frequency index (ROWS)
                     n = 0..N-1 time-slot index (COLUMNS)

 Reference: Caus et al. (2022), Eq. (15).
 X[m,n] = (1/sqrt(M*N)) * sum_l sum_k x[k,l] * exp(-j*2*pi*m*k/M) * exp(+j*2*pi*n*l/N)

 Implemented as two separable unitary 1-D transforms:
   1) DFT of size M along the delay axis (rows) - delay -> frequency
   2) IDFT of size N along the Doppler axis (columns) - Doppler -> time

 Input:
 - xDD : M x N matrix of delay-Doppler domain symbols

 Output:
 - XTF : M x N matrix of time-frequency domain symbols
```

### `otfs_demodulate.m`

```text
 OTFS demodulator, inverse of otfs_modulate.m. Removes the
 single reduced cyclic prefix (RCP), applies the Wigner
 transform (rectangular pulse) and the SFFT to recover the
 delay-Doppler domain symbols.

 Grid convention:
 - YTF(m,n): rows = frequency, columns = time
 - yDD(k,l): rows = delay, columns = Doppler
 - Both grids have size M x N

 Processing chain:
   r
     -> remove RCP
   rxNoCp
     -> reshape
   rxGrid
     -> Wigner transform
   YTF
     -> SFFT
   yDD

 Inputs:
 - r         : received time-domain signal, (M*N + cpLength) x 1
 - M         : number of delay bins (rows of the DD grid)
 - N         : number of Doppler bins (columns of the DD grid)
 - cpLength  : length of the RCP that was prepended at the
               transmitter. Use 0 if no CP was used.

 Outputs:
 - xDDHat : M x N matrix, estimated delay-Doppler domain symbols
 - YTF    : M x N matrix, time-frequency domain grid (for
            inspection/debugging purposes)
```

### `otfs_modulate.m`

```text
 OTFS modulator with rectangular pulse shaping and a single
 reduced cyclic prefix (RCP) per frame, following 
 Caus et al., eqs. (13)-(15), and the RCP-OTFS scheme of
 Raviteja et al. [5] referenced therein.
 NOTE: In Caus et al. eq. (15), the first index of x[i,q] is
 Doppler and the second is delay. This implementation uses the
 opposite convention. Mathematically equivalent.

 Grid convention:
 - xDD(k,l): rows = delay, columns = Doppler
 - XTF(m,n): rows = frequency, columns = time
 - Both grids have size M x N

 Processing chain:
   xDD
     -> ISFFT
   XTF
     -> Heisenberg transform with rectangular pulses
   uGrid
     -> column-wise serialization
   u
     -> reduced cyclic prefix
   s

 Inputs:
 - xDD      : M x N matrix of delay-Doppler domain symbols
              (rows = delay index, columns = Doppler index)
 - cpLength : length of the single reduced cyclic prefix (RCP)
              prepended to the whole frame. Use 0 for no CP
              (e.g. Phase 2 AWGN-only BER validation).

 Outputs:
 - s   : time-domain transmit signal, (M*N + cpLength) x 1
 - XTF : time-frequency domain grid (M x N)
```

### `sfft.m`

```text
 Symplectic Finite Fourier Transform (SFFT).
 Inverse of isfft.m: maps time-frequency domain symbols back
 to the delay-Doppler domain.

 Grid convention:
 - Input  XTF(m,n) : m = 0..M-1 frequency index (ROWS)
                     n = 0..N-1 time-slot index (COLUMNS)
 - Output xDD(k,l) : k = 0..M-1 delay index   (ROWS)
                     l = 0..N-1 Doppler index (COLUMNS)

 Reference: Caus et al. (2022), Eq. (15).
 x[k,l] = (1/sqrt(M*N)) * sum_n sum_m X[m,n] * exp(-j*2*pi*n*l/N) * exp(+j*2*pi*m*k/M)

 Implemented as two separable unitary 1-D transforms:
   1) DFT of size N along the time-slot axis (columns) - time -> Doppler
   2) IDFT of size M along the frequency axis (rows) - frequency -> delay

 Input:
 - XTF : M x N matrix of time-frequency domain symbols

 Output:
 - xDD : M x N matrix of delay-Doppler domain symbols
```

## `pipeline/receiver/`

Receiver combining

### `combine_weighted_links.m`

```text
 Apply the frozen two-link weighted combination

   zClean = gamma1*r1 + gamma2*r2

 in the time domain, before noise addition and OTFS
 demodulation.

 gamma1 and gamma2 represent the effective link gains
 obtained from the link budget.

 IMPORTANT:
 This function performs no timing, Doppler or phase
 compensation. It only applies the two scalar link weights
 and adds the branch signals.

 Therefore:

 - In the compensated baseline, satellite 2 has already been
   aligned by the TX compensation mechanism before this
   function is called.

 - In the no-compensation B3 ablation, satellite 2 is
   deliberately not aligned. Its residual distortion is
   preserved and this function applies exactly the same
   receiver weighting as in the baseline.

 Keeping the same combiner in both cases isolates the effect
 of removing satellite-2 TX compensation.

 Noise is not added here. In the reduced baseline model, one
 normalized complex-noise realization is added after this
 clean combination using

   gammaOut = gamma1 + gamma2.

 Inputs:
 - r1, r2         : clean received branch signals, same size
 - gamma1, gamma2 : effective link SNRs in linear scale

 Output:
 - zClean : weighted clean signal before noise
```

## `pipeline/metrics/`

Result metrics and BER bounds

### `build_final_comparison_result.m`

```text
 Normalize one already-computed, already-saved production
 Monte Carlo point (from any historical or official source
 file) into the common official result-struct schema used by
 final_comparison_results.mat.

 This function performs NO simulation. It only reformats
 numbers that are already stored on disk and, when a source
 file did not itself store a one-sided 95%% zero-error upper
 bound, computes that bound from the already-recorded bit
 count (a pure post-hoc statistical calculation, not a new
 Monte Carlo run).

 Inputs:
 - scenario     : 'single_satellite' | 'baseline_compensated'
                  | 'no_compensation' | 'proposal'
 - modulation   : 'QPSK' or '16-QAM' (must be the explicit
                  label from the source experiment metadata,
                  never inferred from a stale cfg.modOrder
                  field)
 - k            : NaN when not applicable (single_satellite,
                  baseline_compensated, no_compensation)
 - powerPolicy  : 'not_applicable', 'boosted' or 'unboosted'
 - NR           : receive-array size
 - numErrors, numBits : verbatim counters from the source
 - storedUpper95 : the source file's own one-sided 95%% upper
                  bound if it stored one, otherwise []/NaN
 - numRealizations, throughputMbps, payloadSE, occupancyPct,
   boostDb, seed : verbatim/derived from the source
 - provenance   : struct describing exactly where this point
                  came from (sourceFile, sourceField, notes)

 Output:
 - result : struct with fields
     scenario, modulation, k, powerPolicy, NR
     BER, numErrors, numBits, upper95, numRealizations
     throughputMbps, payloadSE, occupancyPct, boostDb, seed
     provenance
```

### `build_load_tradeoff_result.m`

```text
 Package one already-computed load-tradeoff BER Monte Carlo
 result (a row from load_tradeoff_ber_boosted.mat or
 load_tradeoff_ber_unboosted.mat, joined with its matching
 row from rate_per_load_results.mat) into the common official
 result-struct schema used everywhere else in official/
 (see build_result_struct.m).

 This function performs NO simulation and calls NO B2/B3/B4
 engine. It only reformats numbers that are already stored on
 disk. All BER counters, error counts and stopping flags are
 taken verbatim from berRow; they are the source of truth and
 are never recomputed.

 Inputs:
 - berRow : one element of allResults from
            load_tradeoff_ber_boosted.mat or
            load_tradeoff_ber_unboosted.mat (already filtered
            to the officially characterized family and
            already matched to rateRow by modulation/k, and
            to the caller's requested NR/powerPolicy)
 - rateRow : the matching element of rateResults from
             rate_per_load_results.mat (same modulation/k)
 - simulationMetadata : the simulationMetadata struct stored
             alongside berRow in the same BER .mat file
 - bandwidth : occupied bandwidth [Hz] (not stored in
             simulationMetadata; supplied by the caller, same
             value used to build rateRow.payloadSE)

 Output:
 - result : common official result struct, same schema as
            build_result_struct.m, with an additional
            result.source = 'load_tradeoff_archive' marker
            and result.runtimeMetadata.candidateSeedCode /
            .componentIds / .assignment / .status carried
            through for traceability.
```

### `build_result_struct.m`

```text
 Assemble the common official result struct.

 The same output schema is intended for:

   proposal
   baseline
   no_compensation

 Scenario-specific quantities that do not have a physical
 meaning are represented as NaN or 'not_applicable'.

 In particular, baseline/no-compensation do not use the
 heterogeneous-grid load parameter k or active-resource boost.
```

### `compute_ber.m`

```text
 Bit Error Rate (BER) computation block.

 Purpose:
 - Compare transmitted and received bit streams
 - Count bit errors for Monte Carlo BER estimation

 Input:
 - txBits : transmitted binary vector
 - rxBits : received (estimated) binary vector

 Output:
 - numErrors        : number of bit errors detected
 - numBitsCompared  : total number of bits compared
```

### `compute_zero_error_upper_bound.m`

```text
 One-sided upper confidence bound on a bit error rate when
 ZERO errors were observed in numBits independent bit
 decisions. Exact Clopper-Pearson bound for zero successes:

   berUpper = 1 - (1-confidenceLevel)^(1/numBits)

 This is NOT an estimate of BER (which is undefined/0 with no
 observed errors) -- it is the largest true BER that would
 still have a (1-confidenceLevel) probability or higher of
 producing zero observed errors in numBits trials. Standard
 practice for reporting "no errors observed" Monte Carlo points
 without claiming BER=0.

 Inputs:
 - numBits         : number of independent bit trials with
                     zero observed errors (positive integer)
 - confidenceLevel  : e.g. 0.95 for a 95% upper bound

 Output:
 - berUpper : upper confidence bound on BER (linear scale)
```

## `pipeline/utils/`

Small utility / seed-code helpers

### `add_normalized_complex_noise.m`

```text
 Add proper complex Gaussian noise with total variance:

   E{|w|^2} = noiseVariance.

 The real and imaginary components therefore have variance

   noiseVariance / 2.

 This helper works directly with a specified noise variance and
 does not perform any Eb/N0 or Es/N0 conversion.

 Inputs:
 - signal        : input numeric array
 - noiseVariance : total complex-noise variance

 Output:
 - noisySignal   : signal + w
```

### `baseline_modulation_seed_code.m`

```text
 Fixed per-modulation seed code used to build reproducible
 deterministic seeds for the official baseline engine
 (run_baseline_point.m). Analogous in spirit to
 candidate_seed_code.m/nr_seed_code.m for the proposal, but
 trivial since the baseline has no heterogeneous-grid load
 parameter k.
```

### `candidate_seed_code.m`

```text
 Stable per-candidate seed code used to build reproducible
 Monte Carlo seeds for the N1~=N2 cooperative proposal.

 This is a direct, intentional mirror of the
 local_candidate_seed_code() local function defined inside
 the frozen/validated engine
 (historical) load_tradeoff/experiments/run_load_tradeoff_ber.m.

 It is duplicated here (not extracted into a shared file)
 because that engine is a closed, already-validated script and
 is not modified as part of building the official/ pipeline.
 Both copies are cross-checked against each other in
 official/validation/

 If this mapping is ever changed, it must be changed
 identically in both places or Monte Carlo results will stop
 being reproducible across the two engines.
```

### `normalize_modulation_label.m`

```text
 Normalize supported modulation labels to the canonical
 labels used by the official pipeline:

   QPSK
   16-QAM

 Accepted 16-QAM aliases:

   16-QAM
   16QAM
   QAM16
```

### `nr_seed_code.m`

```text
 Fixed, explicit per-N_R seed code used to build reproducible
 Monte Carlo seeds for the official proposal engine
 (run_proposal_point.m).

 IMPORTANT: codes are assigned by FIXED LOOKUP, not by sorted
 position within the current N_R grid. The four originally
 characterized receive-array sizes

   NR = 64, 144, 256, 400

 keep the exact same codes (1, 2, 3, 4) they had when the
 N_R grid only contained those four values. This preserves
 bit-exact reproducibility of every result already validated
 at those points.

 NR = 100 and NR = 576 were added later to complete the final
 comparison grid of six square receive arrays
 (finalComparisonNR, see build_official_config.m) and are
 assigned new codes (5, 6) appended at the end, never inserted
 between the existing ones.

 If additional N_R values are added in the future, append new
 codes here in the same way. Never renumber existing codes.
```

### `supertrama_grid_config.m`

```text
 Build a common analysis interval for two OTFS frame sequences
 with different Doppler dimensions N1 and N2.

 Each satellite keeps its own OTFS grid:

   Satellite 1: M x N1
   Satellite 2: M x N2

 Doppler-domain bookkeeping (Ncommon, K1, K2) is independent of
 cpLength: it only counts how many complete frames of each
 satellite fit inside the smallest common interval, in terms of
 Doppler-grid blocks, not physical sample length.

   Ncommon = lcm(N1, N2)

   K1 = Ncommon / N1
   K2 = Ncommon / N2

 cfg.frameLength1/2 and cfg.totalLength are USEFUL-sample
 quantities (cpLength ignored by construction, cfg.frameLength1
 = M*N1) so that:

   K1*M*N1 = K2*M*N2 = M*Ncommon

 They remain valid regardless of cpLength and are used by the
 cpLength=0 structural laboratory (Exp16-29).

 Ncommon is only an analysis/bookkeeping quantity. It is NOT
 a third OTFS grid and it is NOT a physical transmitted
 superframe. Each satellite still transmits its own sequence
 of independent OTFS frames.

 When cpLength > 0, each OTFS frame carries its own reduced
 cyclic prefix (RCP), one per frame (architecture decision,
 Raviteja et al., see also config/simulation_parameters.m,
 referenceCpLength convention). Because Sat1 groups K1 short
 frames per common block and Sat2 groups K2 long frames per
 common block, and each frame pays its own RCP cost, the two
 satellites' physical block lengths over one common-window
 repetition are in general DIFFERENT once cpLength > 0:

   blockLengthSat1 = K1*(M*N1+cpLength)
   blockLengthSat2 = K2*(M*N2+cpLength)

 These are reported in cfg.physical below and are NOT equal
 unless cpLength = 0. This physical mismatch (and the resulting
 drift between the two streams' block boundaries across
 repetitions) is a real architectural consequence of RCP, not
 a bug — see cfg.physical.driftPerBlock.

 Inputs:
 - M         : common delay dimension
 - N1        : Doppler dimension of satellite 1
 - N2        : Doppler dimension of satellite 2
 - modOrder  : QAM modulation order
 - cpLength  : reduced CP length per frame, >= 0. Use 0 for the
               cpLength=0 structural laboratory (Exp16-29).
               Use cpLength > 0 for the real RCP physical
               architecture (Phase 7, RCP block).

 Output:
 - cfg : common analysis configuration
```

## `pipeline/framing/`

Proposal physical framing

### `nominal_block_framing_16_64.m`

```text
 Physical block-length bookkeeping for the nominal cooperative
 framing.

 Option A uses a periodic cooperative block:
 - Sat1 transmits K1 short OTFS frames, each with one RCP.
 - Sat2 transmits K2 long OTFS frames, each with one RCP.
 - If the Sat2 active waveform is shorter, the remaining
   samples are filled with zeros so both branches have the same
   cooperative block duration.

 This function calls the existing supertrama_grid_config.m and
 converts the resulting block-length difference into the
 explicit Sat2 guard used by the nominal Option A architecture.

 It does not synthesize or demodulate waveforms. T1/T2/R1/R2
 remain responsible for waveform generation and processing.

 Input:
 - cfg : struct from nominal_proposal_config_16_64.m

 Output:
 - physical : framing information returned by
              supertrama_grid_config.m, plus:
              guardLength = driftPerBlock
```

## `pipeline/mapper/`

Frozen resource-mapper catalog access

### `get_mapper_config.m`

```text
 Load one frozen, physically characterized heterogeneous-grid
 mapper from the official mapper catalog.

 No mapper design, greedy growth, Jrobust computation or
 assignment optimization is executed at runtime.

 Selectable family:

   QPSK    k = 7, 8, 9, 10
   16-QAM  k = 4, 5, 6, 7, 8
```

## `pipeline/resource_allocation/`

Resource-mapper index construction

### `build_mapper_resource_indices.m`

```text
 Build the DD resource indices of a cooperative mapper for one
 or several delay rows.

 The mapper fixes the frame/Doppler allocation. The requested
 delay rows are then applied at the target delay dimension M.

 This supports the validated structural scale-up from the
 M=16 mapper design to the final M=1024 proposal. Therefore
 mapper.M is intentionally not required to equal M.

 Flattening:

   Sat1:
     frame*M*N1 + doppler*M + delay + 1

   Sat2:
           doppler*M + delay + 1

 Sat2 has one OTFS frame per common block in the current
 N1=16, N2=64 architecture, so mapper.sat2Frames must be zero.

 Mapper coordinates are 0-based. Returned MATLAB indices are
 1-based.

 Inputs:
 - mapper    : cooperative mapper
 - M         : target delay dimension
 - N1        : Sat1 Doppler dimension
 - delayRows : scalar/vector of 0-based delay rows

 Outputs:
 - sat1Idx   : active Sat1 DD indices
 - sat2Idx   : corresponding Sat2 DD indices
 - rowOfSlot : delay row associated with each resource pair
```

## `pipeline/reporting/`

Figure and table generation

### `export_final_results_tables.m`

```text
 Export the numerical results used by the final official
 reporting figures.

 Outputs:

   main_results.csv
   proposal_power_results.csv
   load_tradeoff_results.csv
   nominal_se_summary.csv

 No simulation is performed.
```

### `plot_load_ber_by_k.m`

```text
 Official BER load-tradeoff reporting.

 Generates:

   QPSK boosted
   QPSK unboosted
   16-QAM boosted
   16-QAM unboosted

 Each curve corresponds to one tested load k.

 Only OBSERVED positive BER values are connected.
 Zero-error runs are excluded from the curve and represented
 only through a dashed 95% upper-bound reference line.
```

### `plot_load_se_vs_ber.m`

```text
 Official payload-SE versus BER load-tradeoff figures.

 Representative operating point:

   N_R = 400

 Only positive BER values actually observed in Monte Carlo
 are drawn and connected.

 Zero-error cases are NOT represented as positive BER points
 and are NOT connected to measured data. Their conservative
 95% upper-bound level is shown as a dashed horizontal line.
```

### `plot_main_ber_comparison.m`

```text
 Final BER comparison between the four main TFG scenarios:

   1. Single satellite
   2. Cooperative baseline - compensated
   3. Cooperative baseline - no TX compensation
   4. Proposed heterogeneous-grid - boosted

 One figure is generated per modulation.

 IMPORTANT:
 - BER is always represented on a logarithmic y-axis.
 - Zero-error Monte Carlo runs are NOT plotted as BER points.
 - A dashed horizontal line indicates the conservative
   one-sided 95% upper-bound level when zero-error runs exist.
```

### `plot_nominal_se_comparison.m`

```text
 Compare the nominal payload spectral efficiency of the four
 main system configurations.

 The metric is payload bits / physical transmission time /
 bandwidth. It is therefore a NOMINAL payload SE and does
 not include BER or packet-success effects.
```

### `plot_proposal_power_comparison.m`

```text
 Compare the two official power policies of the nominal
 heterogeneous-grid proposal:

   boosted
   unboosted

 One figure is generated for QPSK and one for 16-QAM.

 Zero-error runs are excluded from the measured BER curves.
 Their 95% upper-bound level is shown using a dashed
 horizontal reference line.
```

### `plot_residual_sensitivity.m`

```text
 Official reporting for the three one-dimensional sensitivity
 studies of the heterogeneous-grid proposal:

   1) residual timing;
   2) residual Doppler;
   3) slant-range imbalance.

 Generates:

   QPSK timing sensitivity
   QPSK Doppler sensitivity
   QPSK range sensitivity

   16-QAM timing sensitivity
   16-QAM Doppler sensitivity
   16-QAM range sensitivity

 Horizontal axis:

   10log10(N_R) [dB]

 Each curve corresponds to one tested residual offset.

 Only OBSERVED positive BER values are connected.
 Zero-error runs are excluded from the curves and represented
 only through a dashed 95% upper-bound reference line.

 Inputs:

   inputFile
       residual_sensitivity_results.mat

   outputDir
       Destination folder for generated figures.
```

### `plot_timing_doppler_2d_sensitivity.m`

```text
 Official reporting for the joint residual timing-Doppler
 sensitivity analysis.

 Two heatmaps are generated:

   1) QPSK,   k=7, N_R=256
   2) 16-QAM, k=4, N_R=256

 Only OBSERVED positive BER values are represented by the
 heatmap color scale.

 Zero-error Monte Carlo runs are excluded from the BER color
 map and labelled as "0 err". Their one-sided 95% BER upper
 bound is reported separately.

 The nominal operating point is indicated only by a black
 outline around its corresponding cell. No marker or legend
 is placed over the measured values.

 Inputs:

   inputFile
       timing_doppler_2d_sensitivity_results.mat

   outputDir
       Destination folder for generated figures.
```

### `save_official_figure.m`

```text
 Export one official reporting figure in:

   PNG -- 300 dpi, convenient for quick inspection
   PDF -- vector format, intended for the thesis / Overleaf

 This function performs no simulation and modifies no
 numerical result.
```

## `pipeline/operators/`

Cross-grid modulate/demodulate operators (different-grid proposal)

### `r1_sat1_demodulate_block.m`

```text
 R1: process one cooperative block using Sat1 framing.

 Current proposal:
   N1 = 16, N2 = 64 -> K1 = 4 Sat1 frames per block.

 RX1 knows only Sat1's own frame boundaries. It splits the
 received block into K1 windows, removes the RCP expected by
 Sat1 in each window, and demodulates each M x N1 frame.

 RX1 does NOT know or remove Sat2's CP or guard structure.
 Any Sat2 waveform present is processed through the same
 Sat1-defined windows. This defines the cross-grid operator
 C_{1<-2} when R1 is applied to T2.

 Inputs:
 - sBlock : K1*(M*N1+Lcp) received time samples
 - M, N1  : Sat1 OTFS grid dimensions
 - Lcp    : Sat1 reduced CP length

 Output:
 - xDDBlock : (K1*M*N1)x1 DD samples, frame-major
```

### `r2_sat2_demodulate_block.m`

```text
 R2: process one cooperative block using Sat2 framing.

 RX2 knows only Sat2's own frame boundary. It reads its active
 M*N2+Lcp samples, removes Sat2's expected RCP, and
 demodulates the M x N2 OTFS frame.

 Trailing samples belong to the cooperative-block guard
 interval and are outside RX2's DD observation window.

 RX2 does NOT know or remove Sat1's internal CP structure.
 Any Sat1 waveform inside RX2's active window is processed as
 part of the received signal. This defines the cross-grid
 operator C_{2<-1} when R2 is applied to T1.

 Inputs:
 - sBlock : cooperative-block time-domain samples
 - M, N2  : Sat2 OTFS grid dimensions
 - Lcp    : Sat2 reduced CP length

 Output:
 - xDDBlock : (M*N2)x1 DD samples
```

### `t1_sat1_modulate_block.m`

```text
 T1: synthesize one Sat1 cooperative block.

 Current proposal:
   N1 = 16, N2 = 64 -> K1 = 4 Sat1 frames per block.

 Physical block:
   CP|f0  CP|f1  CP|f2  CP|f3

 Each OTFS frame has its own reduced cyclic prefix. The input
 is frame-major; each frame is flattened column-major
 (delay-fastest), consistent with reshape(..., M, N1).

 T1 only describes Sat1. It does not know Sat2 framing,
 guard samples, delta_sync, or the receiver.

 Inputs:
 - xDDBlock : (K1*M*N1)x1 DD symbols
 - M, N1    : Sat1 OTFS grid dimensions
 - Lcp      : reduced CP length per frame

 Output:
 - sBlock   : K1*(M*N1+Lcp) time-domain samples
```

### `t2_sat2_modulate_block.m`

```text
 T2: synthesize one Sat2 cooperative block.

 Current proposal:
   N1 = 16, N2 = 64 -> K2 = 1 Sat2 frame per block.

 Physical block:
   CP|F|guard

 The trailing guard contains zeros. It makes Sat2's physical
 block period equal to the common cooperative-block period.
 It does NOT compensate delta_sync or align received signals.

 T2 only describes Sat2. It does not know Sat1 framing,
 delta_sync, or the receiver.

 Inputs:
 - xDDBlock    : (M*N2)x1 DD symbols
 - M, N2       : Sat2 OTFS grid dimensions
 - Lcp         : reduced CP length
 - guardLength : trailing silent samples

 Output:
 - sBlock : M*N2+Lcp+guardLength time-domain samples
```

## `pipeline/timing_residual/`

Timing-residual stream combination helpers

### `build_and_combine_streams.m`

```text
 Build continuous Sat1/Sat2 streams from consecutive common
 blocks, apply the relative timing offset to Sat2 and return
 the combined waveform and central-block RX windows.

 Convention:
   delta > 0 : Sat2 arrives later than Sat1
   delta < 0 : Sat2 arrives earlier than Sat1

 RX1 remains aligned with Sat1. RX2 follows the shifted Sat2
 central block.

 Inputs:
 - dSat1Blocks : Sat1 DD payloads per common block
 - dSat2Blocks : Sat2 DD payloads per common block
 - cfg         : proposal configuration
 - delta       : integer timing offset [samples]

 Output:
 - result.y
 - result.s1Stream
 - result.s2Stream
 - result.rx1Window
 - result.rx2Window
 - result.commonBlockLength
 - result.validRange
 - result.centerBlockIndex
 - result.numBlocks
```

### `generate_common_block_payloads.m`

```text
 Generate independent common-block modulation payloads for
 cooperative transmission.

 Payloads are independent between common blocks. Within each
 block, Sat1 and Sat2 transmit the SAME symbol vector on their
 corresponding mapped DD resources.

 This function only creates DD-domain payloads. It does not
 perform OTFS modulation, timing shifts or waveform generation.

 The modulation format is defined by qamParams and handled by
 modulate_symbols.m.

 Inputs:
 - numBlocks       : number of common blocks
 - sat1IdxAllRows  : active Sat1 DD resource indices
 - sat2IdxAllRows  : corresponding active Sat2 DD indices
 - blockSizeSat1   : Sat1 DD vector length
 - blockSizeSat2   : Sat2 DD vector length
 - qamParams       : modulation configuration

 Output:
 - payloads.txBits
 - payloads.txSymbolsPerBlock
 - payloads.dSat1Blocks
 - payloads.dSat2Blocks
 - payloads.numActiveSymbols
 - payloads.numBitsPerBlock
```

### `linear_shift_combine.m`

```text
 Applies a linear timing offset to Sat2 and combines both
 time-domain streams:

   y[n] = s1[n] + s2[n - delta]

 Convention:
   delta > 0  -> Sat2 arrives later than Sat1.
   delta < 0  -> Sat2 arrives earlier than Sat1.

 Only samples supported by both generated input streams are
 considered valid. No circular wrap-around is used.

 Samples outside validRange are marked as NaN and must not
 be processed. The caller must verify that every requested
 receiver window lies completely inside validRange.

 Inputs:
 - s1Stream : Sat1 time-domain stream
 - s2Stream : Sat2 time-domain stream
 - delta    : integer timing offset [samples]

 Output:
 - result.y          : combined time-domain stream
 - result.validRange : [firstValidSample, lastValidSample]
```

### `required_side_blocks.m`

```text
 Computes the minimum number of common blocks required on
 each side of the central block for a set of timing offsets.

 At least one side block is always kept to represent a
 continuous transmission around the observed central block.

 Inputs:
 - deltaList : integer timing offsets [samples]
 - blockLen  : common-block length [samples]

 Output:
 - nSide     : required number of blocks on each side
```

## `pipeline/los_channel_noise/`

Line-of-sight noise/SNR combination helpers

### `combine_snr_weighted.m`

```text
 Combine two equalized estimates of the same cooperative
 symbols using link-SNR weights:

   dHat = (gamma1*d1 + gamma2*d2) / (gamma1 + gamma2)

 The weights follow inverse-noise-variance weighting for the
 reduced noise-only model, assuming negligible same-resource
 cross-branch noise covariance.

 The combiner does NOT model or cancel the structured
 cross-grid interference remaining after branch equalization.
 Therefore, it is not claimed to be optimal for the complete
 dual-satellite receiver.

 Inputs:
 - d1, d2         : equalized symbol estimates, same size
 - gamma1, gamma2 : non-negative finite link SNRs
                    (linear scale)

 Output:
 - dHat : combined symbol estimates, same size as d1 and d2
```

### `scale_active_symbols.m`

```text
 Scales the amplitude of the active cooperative resources of a
 single common-block DD vector, leaving inactive (zero)
 resources untouched.

 For the frozen mapper, 14 of the 64 common-Doppler-space
 positions per row are active. To make the sparse waveform's
 average transmit power match a fully-loaded reference grid
 (unit average power per common-space resource, same
 convention the baseline uses over its full M x N grid), the
 active symbols must be scaled by:

   amplitudeScale = sqrt(Ncommon / numActivePerRow) = sqrt(64/14)

 so that energy per row becomes
 numActivePerRow * amplitudeScale^2 = Ncommon, matching a
 fully-loaded unit-power row. This function only applies the
 scaling; it does not compute the factor (kept explicit at the
 call site so it is never silently guessed).

 Inputs:
 - block           : full common-block DD vector
                     (K1*M*N1 for Sat1, M*N2 for Sat2)
 - activeIdx        : indices of the active cooperative
                      resources within block
 - amplitudeScale   : real, positive scalar amplitude factor

 Output:
 - scaledBlock : same size as block, with
                 scaledBlock(activeIdx) = block(activeIdx)*amplitudeScale
                 and all other entries unchanged (zero, by
                 construction of the frozen-mapper payload).
```

## `results/` and `archive/`

Not code -- see the tables in `README.md` for what each subfolder contains
and how it is used (frozen results consumed directly, vs. historical data
consumed only by `pipeline/reconstruction/` and `pipeline/validation/`).
