"""
_build_ehat_from_T_and_y(em, T, countries::Vector{String})
-> (ehat::SparseMatrixCSC, exports_by_country::Dict)

Construct the UNCTAD-style export diagonal matrix `ê` that includes **both**
intermediate exports and final exports by destination.

### Formula

For each producing subsegment `i` with origin country `c_i`:

```
e_i = Σ_{j≠c_i} T[i, j]  +  Σ_{d≠c_i} y_s_q[i, d]
```

Then, `ê = diagm(e)` is the export diagonal matrix.

### Arguments

* `em` : Twofold EMRIO object containing field `y_s_q` (2N×Nc).
* `T` : Transaction matrix to evaluate (2N×2N).
* `countries::Vector{String}` : List of country codes.

### Returns

* `ehat::SparseMatrixCSC{Float64}` : Diagonal export matrix `ê`.
* `exports_by_country::Dict{String, Float64}` : Total exports by origin country.

### Notes

* The function requires `em.y_s_q` to match the number of rows in `T`.
* `exports_by_country[c]` is used as denominator in GVCPR calculation.
"""
function _build_ehat_from_T_and_y(em, T, countries::Vector{String})
    K = size(T, 1)
    Nc = length(countries)
    # rows/cols by country from labels
    parsed = [let p = split(lbl, ":"); (country=p[1], sector=p[2], tag=Symbol(p[3])) end for lbl in em.sub_labels]
    row_country = [parsed[i].country for i in 1:K]
    col_country = [parsed[j].country for j in 1:K]

    # sanity
    @assert size(em.y_s_q, 1) == K "em.y_s_q must have 2N rows aligned with subsegments."
    @assert size(em.y_s_q, 2) == Nc "em.y_s_q must have Nc destination columns."

    # map dest country → column index
    c2idx = Dict{String,Int}(countries[j] => j for j in 1:Nc)

    e = zeros(Float64, K)
    for i in 1:K
        ci = row_country[i]
        # intermediate exports
        for j in 1:K
            if col_country[j] != ci
                e[i] += T[i, j]
            end
        end
        # final exports (destination-specific FD)
        for d in 1:Nc
            if countries[d] != ci
                e[i] += em.y_s_q[i, d]
            end
        end
    end

    ehat = spdiagm(0 => e)
    # country export totals for GVCPR denominator
    exports_by_country = Dict{String, Float64}()
    for c in countries
        rows_c = [idx for idx in 1:K if row_country[idx] == c]
        exports_by_country[c] = sum(@view e[rows_c])
    end
    return ehat, exports_by_country
end