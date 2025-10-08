"""
# ------------------------------------------------------------
# EMRIO Base Setup Script
# ------------------------------------------------------------
Prepare the environment and core data structures for building a synthetic
Enterprise-level Multi-Regional Input–Output (EMRIO) model.

### Purpose
This script initializes basic constants, loads core module definitions,
and constructs:
- A **sector-level MRIO** (`sector`)
- Its **twofold-disaggregated EMRIO** (`em`)
where each base sector is split into {Firm, Other} subsegments.

### Workflow
1. **Set working directory and import utilities**
   ```julia
   PATH = pwd()
   using(joinpath(PATH, "modules", "using_package.jl"))
   using(joinpath(PATH, "modules", "_default_firm_shares.jl"))
   using(joinpath(PATH, "modules", "_sector_index_of.jl"))
   using(joinpath(PATH, "modules", "make_sector_mrio_from_T.jl"))
   using(joinpath(PATH, "modules", "make_emrio_twofold.jl"))
````

These modules define:

* `_default_firm_shares()` : default firm ratios per (country, sector)
* `_sector_index_of()`     : utility for index lookup
* `make_sector_mrio_from_T()` : builds base MRIO (6×6)
* `make_emrio_twofold()`      : expands it into a 12×12 EMRIO

2. **Define core constants**

   ```julia
   const COUNTRIES = ["A", "B"]
   const SECTORS   = ["Primary", "Secondary", "Tertiary"]
   const Nc = length(COUNTRIES)
   const Ns = length(SECTORS)
   const N  = Nc * Ns
   ```

   These control the model dimensionality (two countries, three sectors).

3. **Construct MRIO and EMRIO**

   ```julia
   sector = make_sector_mrio_from_T()
   em     = make_emrio_twofold(sector)
   ```

   * `sector` is the 6×6 base MRIO with domestic/foreign trade and
     destination-specific final demand (`y_s`).
   * `em` is the expanded 12×12 twofold EMRIO (Firm/Other decomposition).

### Output objects

| Variable               | Description                                                |
| ---------------------- | ---------------------------------------------------------- |
| `sector`               | Sector-level MRIO (NamedTuple with T, y, va, x, A, v, y_s) |
| `em`                   | Twofold EMRIO object (NamedTuple with T, A, v, R, C, etc.) |
| `COUNTRIES`, `SECTORS` | Model dimension definitions                                |
| `N`, `Nc`, `Ns`        | Dimensions: sectors, countries, total size                 |

### Notes

* This synthetic configuration is the minimal reproducible example for
  uncertainty propagation and GVC indicator computation.
* Adjusting `COUNTRIES` or `SECTORS` will automatically scale the model.
* All numbers are illustrative (not calibrated to real IO tables).

### Example (after execution)

```julia
size(sector.T)  # (6, 6)
size(em.T)      # (12, 12)
first(em.sub_labels)
# → "A:Primary:Firm"
```

"""
PATH = pwd()
using(joinpath(PATH, "modules", "using_package.jl"))
using(joinpath(PATH, "modules", "_default_firm_shares.jl"))
using(joinpath(PATH, "modules", "_sector_index_of.jl"))
using(joinpath(PATH, "modules", "make_sector_mrio_from_T.jl"))
using(joinpath(PATH, "modules", "make_emrio_twofold.jl"))

# -------------------------
# 0) Basic labels
# -------------------------
const COUNTRIES = ["A","B"]
const SECTORS   = ["Primary","Secondary","Tertiary"]
const Nc = length(COUNTRIES)
const Ns = length(SECTORS)
const N  = Nc * Ns

# ============================================
# Sector-level MRIO definition from T (6x6)
# ============================================
const COUNTRIES = ["A","B"]
const SECTORS   = ["Primary","Secondary","Tertiary"]
const Ns = length(SECTORS)
const N  = 2 * Ns

sector = make_sector_mrio_from_T()
em     = make_emrio_twofold(sector)
