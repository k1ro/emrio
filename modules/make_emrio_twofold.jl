"""
    make_emrio_twofold(sector; row_shares=_default_firm_shares(), col_shares=row_shares)

Twofold-disaggregate a sector-level MRIO into subsegments `{Firm, Other}` on both
the supply side (rows) and the use side (columns). This constructs an expanded
(2N × 2N) EMRIO where each base sector is split into two subsegments and all
column-oriented vectors (e.g., `x`, `y`, `va`) are consistently mapped to the
expanded space while preserving column-wise accounting identities.

# Arguments
- `sector::NamedTuple` :
  Output of `make_sector_mrio_from_T()` containing
  `T, y, va, x, A, v, idx_country, idx_sector, y_s` (N×Nc).
- `row_shares::Dict{Tuple{String,String}, Float64}` :
  Supply-side firm shares `r_i ∈ [0,1]` for each `(country, sector)`.
  Controls the row expansion matrix `R` (2N×N).
- `col_shares::Dict{Tuple{String,String}, Float64}` :
  Use-side firm shares `c_j ∈ [0,1]` for each `(country, sector)`.
  Controls the column expansion matrix `C` (2N×N).
  Defaults to `row_shares` if not provided.

# Construction steps
1. **Base labels & shares**
   Build the `(country, sector)` list for base sectors (length `N`) and
   collect two share vectors:
   - `r[j]` for rows (supply-side firm ratio),
   - `c[j]` for columns (use-side firm ratio).
   Validates that both are within `[0,1]` and records `base_labels = "$country:$sector"`.

2. **Subsegment nodes**
   For each base sector `j`, create two subsegments with fixed order:
   - index `2j-1` → `Firm`
   - index `2j`   → `Other`
   Produce:
   - `nodes::Vector{NamedTuple}` with `(idx, country, sector, subsegment)`,
   - `map[k]::Int` mapping subsegment `k` back to base index `j`,
   - `tags[k]::Symbol ∈ {:Firm, :Other}`,
   - `sub_labels[k] = "$country:$sector:$tag"`.

3. **Expansion matrices `R`, `C`**
   Construct `R (2N×N)` and `C (2N×N)` such that each base sector is split as:
```

R[2i-1, i] = r[i];       R[2i, i] = 1 - r[i]
C[2i-1, i] = c[i];       C[2i, i] = 1 - c[i]

```
Sanity checks ensure each column of `R` and `C` sums to 1 (perfect partition).

4. **Expand transactions & column-oriented vectors**
Apply outer-product style splitting:
- `T_E  = R * sector.T * C'` (2N×2N)
- `x_Ec = C * sector.x`      (2N)   — column totals for coefficient scaling
- `y_E  = C * sector.y`      (2N)
- `va_E = C * sector.va`     (2N)
Additionally, expand destination-specific final demand:
- `y_s_q = C * sector.y_s`   (2N×Nc), where columns follow `COUNTRIES`.

5. **Coefficients on expanded system**
For each expanded column `j` with `x_Ec[j] > 0`:
```

A_E[:, j] = T_E[:, j] ./ x_Ec[j]
v_E[j]    = va_E[j]  ./ x_Ec[j]

````
Enforce (assert) the column-wise accounting identity:
`sum(A_E[:, j]) + v_E[j] = 1` up to numerical tolerance.

# Returns
A `NamedTuple` with:
- `nodes::Vector{NamedTuple}` :
Subsegment descriptors `(idx, country, sector, subsegment)`.
- `map::Vector{Int}` :
Length `2N`; `map[k]` gives the base-sector index for subsegment `k`.
- `tags::Vector{Symbol}` :
`:Firm` or `:Other` for each subsegment.
- `R::Matrix{Float64}, C::Matrix{Float64}` :
Row/column expansion matrices (2N×N).
- `T::Matrix{Float64}` :
Expanded transaction matrix (2N×2N).
- `y::Vector{Float64}, va::Vector{Float64}` :
Expanded final demand and value added (length 2N).
- `xcol::Vector{Float64}` :
Expanded column totals `x_Ec` (length 2N).
- `A::Matrix{Float64}, v::Vector{Float64}` :
Expanded technical and value-added coefficients (column identity preserved).
- `y_s_q::Matrix{Float64}` :
Expanded destination-specific final demand (2N×Nc).
- `base_labels::Vector{String}, sub_labels::Vector{String}` :
Labels for base sectors (`"A:Primary"`) and subsegments (`"A:Primary:Firm"`).

# Invariants & notes
- **Local accounting safety:** choose `max(r) + max(c) ≤ 1` (e.g., ≤ 0.90) to avoid
negative `OO` entries when performing within-block reallocations in later
uncertainty experiments (FF→FO/OF/OO adjustments).
- **Order matters:** the fixed ordering `(Firm, Other)` per base sector is assumed
by downstream routines (e.g., 2×2 block operations).
- **Destination dimension:** `y_s_q` columns follow the global `COUNTRIES` order.
This enables UNCTAD-style GVC calculations with both intermediate and final
exports in the expanded space.

# Example
```julia
sector = make_sector_mrio_from_T()
em = make_emrio_twofold(sector)  # default twofold split

size(em.T)      # (12, 12)
size(em.y_s_q)  # (12, 2)
maximum(abs.(sum(em.A; dims=1)[:] .+ em.v .- 1.0))  # ≈ 0
````

"""
function make_emrio_twofold(sector; row_shares=_default_firm_shares(), col_shares=row_shares)
    N = length(sector.x)  # number of base sectors (expected 6 in the synthetic setup)

    # 1) Build base-sector label list and per-sector shares
    base = [(sector.idx_country[j], sector.idx_sector[j]) for j in 1:N]
    r = zeros(Float64, N)  # row split (supply side)
    c = zeros(Float64, N)  # column split (use side)
    base_labels = String[]
    for (j, (cc, ss)) in enumerate(base)
        haskey(row_shares, (cc, ss)) || error("Missing row share for ($(cc), $(ss)).")
        haskey(col_shares, (cc, ss)) || error("Missing col share for ($(cc), $(ss)).")
        r[j] = row_shares[(cc, ss)]
        c[j] = col_shares[(cc, ss)]
        (0.0 <= r[j] <= 1.0) || error("Row share out of [0,1] for ($(cc), $(ss)).")
        (0.0 <= c[j] <= 1.0) || error("Col share out of [0,1] for ($(cc), $(ss)).")
        push!(base_labels, string(cc, ":", ss))
    end

    # 2) Build subsegment list (Firm, Other) per base sector
    #    Order: for each base sector j, sub-index (2j-1)=Firm, (2j)=Other
    K = 2N
    nodes = NamedTuple[]
    map   = Vector{Int}(undef, K)     # map subsegment -> base index
    tags  = Vector{Symbol}(undef, K)  # :Firm or :Other
    sub_labels = Vector{String}(undef, K)
    for j in 1:N
        (cc, ss) = base[j]
        kF, kO = 2j-1, 2j
        map[kF] = j;  tags[kF] = :Firm;  sub_labels[kF] = string(cc, ":", ss, ":Firm")
        map[kO] = j;  tags[kO] = :Other; sub_labels[kO] = string(cc, ":", ss, ":Other")
        push!(nodes, (idx=kF, country=cc, sector=ss, subsegment=:Firm))
        push!(nodes, (idx=kO, country=cc, sector=ss, subsegment=:Other))
    end

    # 3) Build expansion matrices R (2N×N for rows) and C (2N×N for cols)
    #    For base row i: split by r_i into Firm/Other rows
    #    For base col j: split by c_j into Firm/Other columns
    R = zeros(Float64, K, N)
    C = zeros(Float64, K, N)
    for i in 1:N
        R[2i-1, i] = r[i]        # Firm share on supply side
        R[2i,   i] = 1.0 - r[i]  # Other share
        C[2i-1, i] = c[i]        # Firm share on use side
        C[2i,   i] = 1.0 - c[i]  # Other share
    end
    # Sanity: row-split and col-split are partitions
    @assert maximum(abs.(sum(R; dims=1)[:] .- 1.0)) < 1e-12
    @assert maximum(abs.(sum(C; dims=1)[:] .- 1.0)) < 1e-12

    # 4) Expand transactions and column-oriented vectors
    #    T_E(iF/jF etc.) = r_i * c_j * T_ij (outer-product split)
    T_E  = R * sector.T * transpose(C)  # 2N × 2N
    x_Ec = C * sector.x                 # 2N (column totals for coefficients)
    y_E  = C * sector.y                 # 2N
    va_E = C * sector.va                # 2N
    # expand destination-specific final demand to twofold rows ---
    # y_s_q rows follow subsegments; columns are destination countries (Nc)
    @assert hasproperty(sector, :y_s) "sector.y_s not found — define in make_sector_mrio_from_T()."
    y_s_q = C * sector.y_s           # (2N × Nc)

    # 5) Derive A_E and v_E on the expanded system
    A_E = zeros(Float64, K, K)
    v_E = zeros(Float64, K)
    for j in 1:K
        if x_Ec[j] > 0.0
            A_E[:, j] .= T_E[:, j] ./ x_Ec[j]
            v_E[j] = va_E[j] / x_Ec[j]
        else
            A_E[:, j] .= 0.0
            v_E[j] = 0.0
        end
    end
    # Column identity holds exactly if sector-level identity holds
    @assert maximum(abs.(sum(A_E; dims=1)[:] .+ v_E .- 1.0)) < 1e-10

    return (
        nodes = nodes,       # 2N subsegments, per base sector: Firm, Other
        map = map,           # subsegment -> base-sector index
        tags = tags,         # :Firm / :Other
        R = R, C = C,        # expansion matrices
        T = T_E,             # expanded transactions
        y = y_E, va = va_E,  # expanded vectors aligned to columns
        xcol = x_Ec,         # expanded column totals
        A = A_E, v = v_E,    # coefficients (column identity OK)
        y_s_q = y_s_q ,    # expanded final demand by destination (2N × Nc)
        base_labels = base_labels,
        sub_labels = sub_labels
    )
end