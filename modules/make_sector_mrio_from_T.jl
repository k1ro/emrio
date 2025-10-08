# Helpers to get country/sector label by index
country_of(i) = i <= Ns ? "A" : "B"
sector_of(i)  = SECTORS[mod1(i, Ns)]
"""
    make_sector_mrio_from_T()

Constructs a synthetic sector-level MRIO (multi-regional input–output) system
for two countries (A, B) and three sectors (Primary, Secondary, Tertiary).

This function generates a consistent set of IO tables including:
- Intermediate transaction matrix `T` (N×N)
- Final demand vector `y` (N×1)
- Value added `va` (N×1)
- Total output `x` (N×1)
- Technical coefficients `A` (N×N)
- Value-added coefficients `v` (N×1)
- Country–sector labels and a destination-specific final demand matrix `y_s` (N×Nc)

### Steps
1. **Total output (`x`)**
   Defines arbitrary output levels for 3 sectors in each country (A, B).

2. **Final demand (`y`)**
   Computes final demand for each industry as a share of total output
   using `f_share[sector]`.
   Example: Primary=0.55, Secondary=0.40, Tertiary=0.65.

3. **Destination-specific final demand (`y_s`)**
   Splits each industry's final demand `y[i]` into domestic and foreign destinations.
   The domestic share `α_fd` is taken from `fd_dom_share[sector]`, and the remainder
   is evenly distributed across all other countries.
   `y_s[i, d]` gives exports from origin industry *i* to destination country *d*.

4. **Intermediate transactions (`T`)**
   Calculates intermediate supplies = `x - y` for each industry and allocates
   them between domestic and foreign users using:
   - `dom_share[sector]` = domestic ratio of intermediate trade
   - `w_dom`, `w_for`    = within-country allocation weights by sector
   Rows of `T` correspond to producers, columns to users.

5. **Value added and coefficients**
   Enforces column-wise accounting identity
   `sum(T[:, j]) + va[j] = x[j]` for each column.
   Computes `A = T ./ x'` and `v = va ./ x`.
   Ensures `sum(A[:, j]) + v[j] = 1` holds (assertion check).

### Returns
A `NamedTuple` with the following fields:
```

(
T::Matrix{Float64},      # N×N intermediate transactions
y::Vector{Float64},      # N×1 total final demand
va::Vector{Float64},     # N×1 value added
x::Vector{Float64},      # N×1 total output
A::Matrix{Float64},      # N×N technical coefficients
v::Vector{Float64},      # N×1 value-added coefficients
countries::Vector{String}, sectors::Vector{String},
idx_country::Vector{String}, idx_sector::Vector{String},
y_s::Matrix{Float64}     # N×Nc destination-specific final demand
)

````

### Notes
- The column identity `Σ_i a_ij + v_j = 1` must hold exactly.
- The generated numbers are illustrative and not calibrated to real data.
- `COUNTRIES` and `SECTORS` are defined globally. Increasing `COUNTRIES`
  automatically expands the columns of `y_s`.
- To maintain positive value added, ratios in `f_share` and `dom_share`
  should be chosen such that `va > 0`.

### Example
```julia
sector = make_sector_mrio_from_T()
size(sector.T)    # (6,6)
size(sector.y_s)  # (6,2)
maximum(abs.(sum(sector.A; dims=1)[:] .+ sector.v .- 1.0))  # ≈ 0
````

"""
function make_sector_mrio_from_T()
    # 1) Total output
    x = vcat([100.0, 160.0, 220.0],   # A: Primary–Tertiary
             [ 95.0, 150.0, 210.0])   # B: Primary–Tertiary
    N  = length(x)
    Nc = length(COUNTRIES)

    # 2) Final demand share per industry (scalar share of x)
    f_share = Dict("Primary"=>0.55, "Secondary"=>0.40, "Tertiary"=>0.65)
    sector_of(i)  = SECTORS[mod1(i, length(SECTORS))]
    country_of(i) = i <= length(SECTORS) ? "A" : "B"
    y = [f_share[sector_of(i)] * x[i] for i in 1:N]  # vector length N

    # destination split for final demand (build N×Nc matrix y_s)
    # fd_dom_share: share of final demand absorbed domestically by origin country
    # (You can tune these independently from intermediate dom_share)
    fd_dom_share = Dict("Primary"=>0.80, "Secondary"=>0.70, "Tertiary"=>0.85)

    # Initialize y_s with zeros: rows = origin industries, cols = destination countries
    y_s = zeros(Float64, N, Nc)

    # Helper: map country code to column index
    c2idx = Dict{String,Int}(COUNTRIES[i] => i for i in 1:Nc)

    for i in 1:N
        c_origin = country_of(i)
        s_name   = sector_of(i)
        y_i      = y[i]
        αfd      = fd_dom_share[s_name]           # domestic absorption share
        # Put domestic part into destination column of origin country
        y_s[i, c2idx[c_origin]] += αfd * y_i

        # Distribute foreign part across all non-origin countries (equal split)
        foreign_cols = [j for j in 1:Nc if COUNTRIES[j] != c_origin]
        if !isempty(foreign_cols)
            per = (1.0 - αfd) * y_i / length(foreign_cols)
            for j in foreign_cols
                y_s[i, j] += per
            end
        end
    end

    # 3) Intermediate transactions T (unchanged)
    dom_share = Dict("Primary"=>0.85, "Secondary"=>0.75, "Tertiary"=>0.80)
    w_dom = [0.50, 0.30, 0.20]
    w_for = [0.20, 0.50, 0.30]
    T = zeros(Float64, N, N)
    for i in 1:N
        s_row = x[i] - y[i]
        α = dom_share[sector_of(i)]
        if country_of(i) == "A"
            T[i, 1:3] .= s_row * α       .* w_dom
            T[i, 4:6] .= s_row * (1-α)   .* w_for
        else
            T[i, 4:6] .= s_row * α       .* w_dom
            T[i, 1:3] .= s_row * (1-α)   .* w_for
        end
    end

    # 4) Value added from column identity
    colsum_T = vec(sum(T; dims=1))
    va = x .- colsum_T
    @assert all(va .> 0) "Negative value added detected — adjust ratios."

    # 5) Coefficients
    A = T ./ reshape(x, 1, :)
    v = va ./ x
    @assert maximum(abs.(sum(A; dims=1)[:] .+ v .- 1.0)) < 1e-10

    return (
        T = T, y = y, va = va, x = x, A = A, v = v,
        countries = COUNTRIES, sectors = SECTORS,
        idx_country = [country_of(i) for i in 1:N],
        idx_sector  = [sector_of(i)  for i in 1:N],
        y_s = y_s                # (N × Nc)
    )
end