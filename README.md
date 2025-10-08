---

Author: Yuya Katafuchi
Date: October 5, 2025 (JST)

---

# README: EMRIO Synthetic Model: Monte Carlo-based Internal Robustness Analysis
## Overview

This repository provides a minimal and reproducible example for the Monte Carlo-based internal robustness analysis used in the EMRIO framework of [Katafuchi *et al.* (2024)](#reference).
It reproduces the logic of the uncertainty experiment described in the manuscript: generating randomized transaction matrices and evaluating Global Value Chain (GVC) indicators under simulated data perturbations.

All modular components are organized under the `modules/` directory.

---

## Directory Structure

```
emrio/
├── define_data.jl              # Step 1: Build sector MRIO and twofold EMRIO
├── generate_T_scenarios.jl     # Step 2: Generate Monte Carlo transaction matrices
├── calculate_gvc.jl            # Step 3: Compute and summarize GVC indicators
├── modules/
│   ├── using_package.jl
│   ├── _default_firm_shares.jl
│   ├── _sector_index_of.jl
│   ├── make_sector_mrio_from_T.jl
│   ├── make_emrio_twofold.jl
│   ├── _parse_sub_label.jl
│   ├── _col_row_shares.jl
│   ├── _candidate_FF_pairs.jl
│   ├── _realloc_FF_to_FO_OF!.jl
│   ├── generate_T_scenarios_FF_reallocation.jl
│   ├── _country_index_sets.jl
│   ├── _solve_after_T.jl
│   ├── _build_ehat_from_T_and_y.jl
│   ├── compute_gvc_unctad_for_T_simple.jl
│   └── compute_gvc_unctad_and_summarize_simple.jl
├── .gitignore
├── LICENSE
└── README.md
```

Each `.jl` file under `modules/` provides a self-contained helper or computational routine imported by the main scripts.

---

## System Requirements

### Environment
- Julia version: ≥ 1.5 (tested with Julia 1.10.4)
- Operating system: macOS, Linux, or Windows (64-bit)
- Hardware: any standard CPU (RAM ≥ 2 GB recommended)

This code does not require GPU or distributed computation.
All Monte Carlo operations are performed in-memory on a single CPU thread.

### Required Packages
All dependencies are listed in `modules/using_package.jl`.
The key Julia packages and tested versions are:

| Package | Version | Purpose |
|----------|----------|---------|
| `DataFrames` | ≥ 0.22.1 | Tabular data manipulation |
| `DataFramesMeta` | ≥ 0.6.0 | Convenient data transformations |
| `SparseArrays` | built-in | Sparse matrix support |
| `LinearAlgebra` | built-in | Matrix operations |
| `Statistics`, `StatsBase` | ≥ 0.33.2 | Statistical summaries |
| `Random` | built-in | Random number generation |
| `CSV` | ≥ 0.8.2 | Data I/O (optional) |
| `ProgressMeter` | ≥ 1.3.0 | Progress display for long runs |
| `JLD2` | ≥ 0.4.3 | Saving and loading Julia data files |
| `Combinatorics` | ≥ 1.0.2 | Index combinations for reallocation |
| `Unicode`, `Printf`, `StringEncodings` | built-in / stdlib | Encoding and formatted output |

All packages can be installed by running:
```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
````

After installation, the example scripts can be executed in sequence as described in the “Execution Order” section below.

---

## Naming Conventions

The repository follows a consistent rule to distinguish public scripts, public functions, and internal helpers.

| Category                              | Prefix           | Typical Examples                                                                                         | Intended Use                                                                                              |
| ------------------------------------- | ---------------- | -------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Top-level executable scripts          | none             | `define_data.jl`, `generate_T_scenarios.jl`, `calculate_gvc.jl`                                          | Standalone scripts representing each analysis step. Executed directly in sequence.                        |
| Public functions and modules          | none             | `make_emrio_twofold.jl`, `compute_gvc_unctad_for_T_simple.jl`, `generate_T_scenarios_FF_reallocation.jl` | Functions that can be imported and called by other scripts. Represent well-defined analytical procedures. |
| Internal helper functions             | underscore (`_`) | `_solve_after_T.jl`, `_build_ehat_from_T_and_y.jl`, `_realloc_FF_to_FO_OF!.jl`                           | Supporting routines used internally by higher-level functions. Not intended for direct execution.         |
| Shared internal utilities (protected) | underscore (`_`) | `_country_index_sets.jl`, `_col_row_shares.jl`                                                           | Internal functions reused across multiple modules but kept non-public.                                    |
| File-function correspondence          | one-to-one       | Each file defines one main function of the same name.                                                    | Ensures transparent structure and traceability.

---

## Workflow Summary

### Step 1 - Data Definition (`define_data.jl`)

Builds a small two-country, three-sector EMRIO structure for demonstration purposes.

Modules used:

* `using_package.jl`, `_default_firm_shares.jl`, `_sector_index_of.jl`
* `make_sector_mrio_from_T.jl`, `make_emrio_twofold.jl`

Example:

```julia
const COUNTRIES = ["A", "B"]
const SECTORS   = ["Primary", "Secondary", "Tertiary"]

sector = make_sector_mrio_from_T()
em     = make_emrio_twofold(sector)
```

Outputs:

| Variable                                | Description                                    |
| --------------------------------------- | ---------------------------------------------- |
| `sector`                                | 6×6 synthetic sector-level MRIO                |
| `em`                                    | 12×12 twofold EMRIO (Firm/Other decomposition) |
| `COUNTRIES`, `SECTORS`, `N`, `Nc`, `Ns` | Dimension constants                            |

---

### Step 2 - Scenario Generation (`generate_T_scenarios.jl`)

Generates randomized transaction matrices (`T`) for Monte Carlo analysis by reallocating a portion of firm-to-firm (FF) transactions.

Modules used:

* `_parse_sub_label.jl`, `_col_row_shares.jl`, `_candidate_FF_pairs.jl`
* `_realloc_FF_to_FO_OF!.jl`, `generate_T_scenarios_FF_reallocation.jl`

Example:

```julia
Ts, meta = generate_T_scenarios_FF_reallocation(
    em; R=30, rate=0.10, cross_border=true
)
```

Outputs:

| Variable | Description                                                      |
| -------- | ---------------------------------------------------------------- |
| `Ts`     | Vector of `R` transaction matrices with randomized reallocations |
| `meta`   | Metadata (sampling rate, number of candidates, seed)             |

Notes:

* Compatible with Julia ≥ 1.5 (avoids `replace=false` keyword in `rand()`).
* No GVC computation is performed in this step.

---

### Step 3 - GVC Indicator Computation (`calculate_gvc.jl`)

Computes Global Value Chain indicators for each scenario using the UNCTAD-style formulation `F = v̂ * L * ê`.

Modules used:

* `_parse_sub_label.jl`, `_country_index_sets.jl`, `_solve_after_T.jl`
* `_build_ehat_from_T_and_y.jl`, `compute_gvc_unctad_for_T_simple.jl`
* `compute_gvc_unctad_and_summarize_simple.jl`

Example:

```julia
df_each, df_sum = compute_gvc_unctad_and_summarize_simple(em, Ts, ["A", "B"])
```

Outputs:

| Variable  | Type              | Description                                    |
| --------- | ----------------- | ---------------------------------------------- |
| `df_each` | Vector{DataFrame} | Per-scenario GVC indicators                    |
| `df_sum`  | DataFrame         | Country-level summary (median, 95% CI, ±U%, ε) |

---

## Execution Order

```julia
include("define_data.jl")          # Step 1
include("generate_T_scenarios.jl") # Step 2
include("calculate_gvc.jl")        # Step 3
```

All scripts assume execution in the same working directory.

---

## Key Indicators

| Symbol | Name                                  | Definition                               |
| ------ | ------------------------------------- | ---------------------------------------- |
| DVA    | Domestic value added in exports       | GDP_actual − GDP_no-export               |
| FVA    | Foreign value added                   | Imported value in exports                |
| DVX    | Re-exported domestic value added      | DVA embodied in other countries’ exports |
| GVCPR  | Global value chain participation rate | (FVA + DVX) / Exports                    |

---

## Parameters

Default settings in the synthetic example:

| Parameter      | Description                                      | Default    |
| -------------- | ------------------------------------------------ | ---------- |
| `R`            | Number of Monte Carlo iterations                 | 30         |
| `rate`         | Share of firm-to-firm links randomly reallocated | 0.10       |
| `cross_border` | Allow cross-border reallocation                  | true       |
| `countries`    | Countries included in the summary                | ["A", "B"] |

These values mirror those used in the manuscript’s uncertainty experiment.
They can be modified directly in `generate_T_scenarios.jl`.

---

## Output Description

* `df_each`: per-scenario indicator tables containing columns for `country`, `DVA`, `FVA`, `DVX`, `Exports`, and `GVCPR`.
* `df_sum`: aggregated results including medians and 95% nonparametric confidence intervals.

All numbers are dimensionless synthetic values intended for demonstration only.

---

## Notes

* This example is provided solely to illustrate the computational logic of the internal robustness analysis described in the manuscript.
* It uses no proprietary data and does not replicate the full EMRIO database.
* The randomization procedure and indicator calculation are simplified to preserve transparency and reproducibility.
* The numerical outputs should not be interpreted in an economic or policy context.
* This repository does not reproduce the full construction process of the EMRIO database. The actual EMRIO estimation relies on a complex integration of multiple proprietary and public datasets, including:
  - Firm-level financial and corporate structure data from FactSet (FS), Bureau van Dijk (Orbis/Osiris), Bloomberg, and the NEEDS Financial Database.
  - Bills of Lading (BoL) and customs shipment records from FS, ManifestDB, and Importers Databases (IDS).
  - Sector-level input-output and supply-use tables from national statistical offices and the United Nations Statistics Division (UNSNA, UN Comtrade).
  - Supplementary macroeconomic aggregates from the UN Main Aggregates (MA) and Official Country (OC) datasets.
* These sources are combined through institution-specific preprocessing, harmonization, and balancing procedures that cannot be made public. The internal data structures are licensed and their disclosure would reveal schema information under contractual restriction. Only this synthetic and structure-independent example is made available to demonstrate the computational logic.

---

## Disclaimer

This repository is distributed for academic and educational purposes only. The data are entirely synthetic and do not contain any proprietary or confidential content. The real EMRIO data and related firm-level sources (FactSet, Bloomberg, Bureau van Dijk, NEEDS, ManifestDB, Importers Databases) are licensed and not redistributable. Use of this repository does not grant access to those materials.

The code is provided “as is” without warranty of any kind, express or implied, including but not limited to fitness for a particular purpose or non-infringement. Use of this code is at the user’s own risk. The authors and their affiliated institutions assume no responsibility for any loss or damage resulting from its use.

---

## License
The EMRIO Synthetic Model repository is licensed under [CC BY-NC-ND 4.0](https://creativecommons.org/licenses/by-nc-nd/4.0/) with an Additional Permission clause.

You may:
- Use and modify the code for noncommercial academic research,
  provided that modified versions are not redistributed.
- Not use any part of the code or data for commercial purposes
  without prior written consent from the authors.

See the `LICENSE` file for details.

## Reference

Katafuchi, Y., Li, X., Moran, D., Yamada, T., Fujii, H., & Kanemoto, K. (2024). Construction of An Enterprise-Level Global Supply Chain Database. Preprint at https://doi.org/10.21203/rs.3.rs-3651986/v3.

---

Prepared by Yuya Katafuchi (Tohoku University / RIHN)
Date: October 5, 2025 (JST)

---