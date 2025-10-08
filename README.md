---

Author: Yuya Katafuchi
Date: October 5, 2025 (JST)

---

# Enterprise-level Multi-Regional Input-Output (EMRIO) Synthetic Model: Monte Carlo-based Internal Robustness Analysis
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

Builds a sector-level MRIO and expands it into a twofold EMRIO used throughout the example.

First, a two-country, three-sector MRIO is constructed with internally consistent accounting: intermediate transactions `T`, final demand `y`, value added `va`, total output `x`, technical coefficients `A = T ./ x'`, value-added coefficients `v = va ./ x`, and a destination-specific final demand matrix `y_s` that splits `y` into domestic versus foreign absorption.

Second, the sector MRIO is disaggregated into subsegments `{Firm, Other}` on both rows and columns using per-country-sector shares `r` (supply side) and `c` (use side). Expansion matrices `R` and `C` map the sector system to a twofold system of size `(2N × 2N)` via `T_E = R * T * C'`, and column-oriented vectors are mapped consistently (`xcol = C * x`, `y = C * y`, `va = C * va`, `y_s_q = C * y_s`). The expanded coefficients `(A, v)` are recomputed in the twofold space and the column identities are checked again.

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

| Variable               | Type                                                                                                                                                                                                                                                                                                                                 | Description                                                   |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------- |
| `sector`               | NamedTuple（`T::Matrix{Float64}, y::Vector{Float64}, va::Vector{Float64}, x::Vector{Float64}, A::Matrix{Float64}, v::Vector{Float64}, y_s::Matrix{Float64}, countries::Vector{String}, sectors::Vector{String}, idx_country::Vector{String}, idx_sector::Vector{String}`）                                                             | 6×6 synthetic sector-level MRIO with `T, y, va, x, A, v, y_s` |
| `em`                   | NamedTuple（`nodes::Vector{NamedTuple}, map::Vector{Int}, tags::Vector{Symbol}, R::Matrix{Float64}, C::Matrix{Float64}, T::Matrix{Float64}, y::Vector{Float64}, va::Vector{Float64}, xcol::Vector{Float64}, A::Matrix{Float64}, v::Vector{Float64}, y_s_q::Matrix{Float64}, base_labels::Vector{String}, sub_labels::Vector{String}`） | 12×12 twofold EMRIO（Firm/Other Subsegment disaggregation）     |
| `COUNTRIES`, `SECTORS` | `Vector{String}`                                                                                                                                                                                                                                                                                                                     | Dimension labels                                              |
| `N`, `Nc`, `Ns`        | `Int`                                                                                                                                                                                                                                                                                                                                | Dimension constants                                           |


Notes:

* Numbers are synthetic and chosen to satisfy accounting identities.
* Twofold expansion uses shares `r, c ∈ [0, 1]` per country-sector; labels for base sectors and subsegments are provided for later block operations.
* The expanded destination-specific final demand `y_s_q` follows the global country ordering and is required by Step 3.

---

### Step 2 - Scenario Generation (`generate_T_scenarios.jl`)

Generates randomized transaction matrices (`T`) for Monte Carlo analysis by randomly removing a fraction of firm-to-firm (FF) links and locally reallocating the removed values within the same base-sector block.

This process simulates structural incompleteness in firm-level data and tests how EMRIO’s results respond to potential link loss.

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

| Variable | Type                                                                                                      | Description                                                                |
| -------- | --------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| `Ts`     | `Vector{Matrix{Float64}}`                                                                                 | Vector of `R` transaction matrices after FF removal and local reallocation |
| `meta`   | `NamedTuple`（`Ncand::Int, kdrop::Int, rate::Float64, cross_border::Bool, seed::Int, max_excess::Float64`） | Metadata（sampling rate, number removed/candidates, seed, diagnostics）      |


Notes:

* A fixed share (`rate`) of FF links is randomly selected without replacement (restricted to cross-border links if `cross_border=true`) and set to zero.
* The removed FF values are then locally redistributed within the same 2×2 base-sector block, preserving the row and column totals of the block.
* The reallocation procedure represents local substitution among firm and non-firm segments while maintaining base-sector supply and demand balance.
* Compatible with Julia ≥ 1.5 (avoids `replace=false` keyword in `rand()`).

---

### Step 3 - GVC Indicator Computation (`calculate_gvc.jl`)

Computes GVC indicators for each Monte Carlo scenario and summarizes uncertainty across scenarios.

For each transaction matrix `T` in `Ts`, the routine recomputes coefficients and the Leontief inverse, builds an export-selection diagonal including both intermediate and final exports, forms the value-added flow matrix `F = v̂ * L * ê` [(Casella *et al.,* 2019)](#reference), and aggregates country totals for DVA, FVA, DVX, Exports, and GVCPR. The per-scenario results are then pooled to report medians, confidence intervals, relative uncertainty, and a normalized elasticity.

Modules used:

* `_parse_sub_label.jl`, `_country_index_sets.jl`, `_solve_after_T.jl`
* `_build_ehat_from_T_and_y.jl`, `compute_gvc_unctad_for_T_simple.jl`
* `compute_gvc_unctad_and_summarize_simple.jl`

Example:

```julia
df_each, df_sum = compute_gvc_unctad_and_summarize_simple(em, Ts, ["A", "B"])
```

Outputs:

| Variable  | Type                | Description                                                                          |
| --------- | ------------------- | ------------------------------------------------------------------------------------ |
| `df_each` | `Vector{DataFrame}` | Per-scenario tables with columns: `ISO_COUNTRY, DVA, FVA, DVX, Exports, GVCPR`       |
| `df_sum`  | `DataFrame`         | Country-level summary including `Median, P2.5, P97.5, U (±% of median), ε (per 10%)` |


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

See the [LICENSE](./LICENSE) file for details.

## Reference

- Katafuchi, Y., Li, X., Moran, D., Yamada, T., Fujii, H., & Kanemoto, K. (2024). Construction of An Enterprise-Level Global Supply Chain Database. Preprint at https://doi.org/10.21203/rs.3.rs-3651986/v3.
- Casella, B., Bolwijn, R., Moran, D., & Kanemoto, K. (2019). UNCTAD insights: Improving the analysis of global value chains: the UNCTAD-Eora Database. *Transnational corporations* 26, 115–142.

---

Prepared by Yuya Katafuchi (Tohoku University / RIHN)
Date: October 5, 2025 (JST)

---