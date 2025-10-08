"""
# ------------------------------------------------------------
# EMRIO Monte Carlo Experiment Setup Script
# ------------------------------------------------------------
This script prepares the Julia environment and loads all modular components
required to perform Monte Carlo–based uncertainty experiments on the EMRIO model.

### Purpose
- To assemble the necessary helper functions and modules that perform:
  - Parsing of subsegment labels
  - Retrieval of firm/other split ratios (`row_share`, `col_share`)
  - Identification of Firm→Firm candidate links
  - Reallocation logic of FF→(FO, OF)
  - Monte Carlo generation of transaction-matrix scenarios

### Workflow
1. Define current working directory and load shared package imports via
   `using(joinpath(PATH, "modules", "using_package.jl"))`.
2. Load all dependent module scripts:
   - `_parse_sub_label.jl` : defines parsing logic for subsegment labels.
   - `_col_row_shares.jl`  : provides accessors for row/column firm shares.
   - `_candidate_FF_pairs.jl` : enumerates eligible Firm–Firm link pairs.
   - `_realloc_FF_to_FO_OF!.jl` : performs local 2×2 reallocation preserving balances.
   - `generate_T_scenarios_FF_reallocation.jl` : main Monte Carlo generator.
3. Execute the generator to produce:
   - `Ts` : a vector of `R` transaction-matrix realizations with randomized FF reallocation.
   - `meta` : metadata describing sampling rate, number of candidates, and seed.

### Output
After execution:
```julia
Ts, meta = generate_T_scenarios_FF_reallocation(em; R=30, rate=0.10, cross_border=true)
````

* `Ts` stores 30 randomized transaction matrices.
* `meta` summarizes sampling information for traceability.

### Notes

* Designed for Julia 1.5+ (no `replace=false` keyword in `rand()`).
* No Leontief or GDP/GVC computations are performed at this stage;
  these are handled in subsequent modules (e.g., GVC indicator estimation).
"""

PATH = pwd()
using(joinpath(PATH, "modules", "using_package.jl"))
using(joinpath(PATH, "modules", "_parse_sub_label.jl"))
using(joinpath(PATH, "modules", "_col_row_shares.jl"))
using(joinpath(PATH, "modules", "_candidate_FF_pairs.jl"))
using(joinpath(PATH, "modules", "_realloc_FF_to_FO_OF!.jl"))
using(joinpath(PATH, "modules", "generate_T_scenarios_FF_reallocation.jl"))

Ts, meta = generate_T_scenarios_FF_reallocation(em; R=30, rate=0.10, cross_border=true)