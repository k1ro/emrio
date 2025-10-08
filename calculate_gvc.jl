"""
# ------------------------------------------------------------
# GVC Indicator Computation Script (UNCTAD-style)
# ------------------------------------------------------------
This script loads all modular components necessary to compute
Global Value Chain (GVC) indicators — DVA, FVA, DVX, Exports,
and GVCPR — from the Monte Carlo–generated EMRIO transaction
matrices.

### Purpose
To evaluate and summarize GVC indicators for multiple `T` scenarios
produced by the `generate_T_scenarios_FF_reallocation()` routine.
Each scenario is processed using the UNCTAD accounting framework
(`F = v̂ * L * ê`) (Casella et al, 2019), followed by aggregation and uncertainty analysis.

### Workflow
1. **Load environment and dependencies**
   ```julia
   PATH = pwd()
   using(joinpath(PATH, "modules", "using_package.jl"))
   using(joinpath(PATH, "modules", "_parse_sub_label.jl"))
   using(joinpath(PATH, "modules", "_country_index_sets.jl"))
   using(joinpath(PATH, "modules", "_solve_after_T.jl"))
   using(joinpath(PATH, "modules", "_build_ehat_from_T_and_y.jl"))
   using(joinpath(PATH, "modules", "compute_gvc_unctad_for_T_simple.jl"))
   using(joinpath(PATH, "modules", "compute_gvc_unctad_and_summarize_simple.jl"))
````

These modules provide:

* `_parse_sub_label.jl` : label parsing for subsegments (e.g., `"A:Primary:Firm"`).
* `_country_index_sets.jl` : utility for row/column index grouping by country.
* `_solve_after_T.jl` : recalculation of `(A, v, L)` after transaction reallocation.
* `_build_ehat_from_T_and_y.jl` : construction of export diagonal including both intermediate and final exports.
* `compute_gvc_unctad_for_T_simple.jl` : computes DVA/FVA/DVX/GVCPR for a single scenario.
* `compute_gvc_unctad_and_summarize_simple.jl` : runs all scenarios and summarizes results.

2. **Execute batch computation**

   ```julia
   df_each, df_sum = compute_gvc_unctad_and_summarize_simple(em, Ts, countries)
   ```

   * `em` : Twofold EMRIO object (Firm/Other split)
   * `Ts` : Vector of Monte Carlo transaction matrices
   * `countries` : e.g., `["A", "B"]`

### Outputs

| Variable  | Type                | Description                                                           |
| --------- | ------------------- | --------------------------------------------------------------------- |
| `df_each` | `Vector{DataFrame}` | Per-scenario GVC indicators (one DataFrame per Monte Carlo run).      |
| `df_sum`  | `DataFrame`         | Country-level summary with medians, confidence intervals, ±U%, and ε. |

### Indicators (UNCTAD definitions)

* `DVA`: Domestic value added in exports
* `FVA`: Foreign value added in exports
* `DVX`: Domestic value added re-exported via other countries
* `Exports`: Total exports (intermediate + final)
* `GVCPR`: Global value chain participation rate = (FVA + DVX) / Exports

### Notes

* Designed for two-country synthetic EMRIO, but extensible to N-country models.
* Computations include both intermediate and destination-specific final exports.
* Results can be visualized or compared across reallocation rates to evaluate internal robustness.

### Example

```julia
df_each, df_sum = compute_gvc_unctad_and_summarize_simple(em, Ts, ["A","B"])
first(df_sum)
```

### Reference
Casella, B., Bolwijn, R., Moran, D. & Kanemoto, K. UNCTAD insights: Improving the analysis of global value chains: the UNCTAD-Eora Database. Transnational corporations 26, 115–142 (2019).

"""
PATH = pwd()
using(joinpath(PATH, "modules", "using_package.jl"))
using(joinpath(PATH, "modules", "_parse_sub_label.jl"))
using(joinpath(PATH, "modules", "_country_index_sets.jl"))
using(joinpath(PATH, "modules", "_solve_after_T.jl"))
using(joinpath(PATH, "modules", "_build_ehat_from_T_and_y.jl"))
using(joinpath(PATH, "modules", "compute_gvc_unctad_for_T_simple.jl"))
using(joinpath(PATH, "modules", "compute_gvc_unctad_and_summarize_simple.jl"))

df_each, df_sum = compute_gvc_unctad_and_summarize_simple(em, Ts, countries)