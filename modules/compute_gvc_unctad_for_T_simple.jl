"""
compute_gvc_unctad_for_T_simple(em, T, countries)

Compute UNCTAD-style Global Value Chain (GVC) indicators (Casella et al., 2019) for a single
transaction matrix `T`.

### Computation

1. Recompute `(A, v, va, L)` using [`_solve_after_T`](@ref).
2. Build export diagonal matrix `ê` with [`_build_ehat_from_T_and_y`](@ref).
3. Compute flow matrix `F = v̂ * L * ê`.
4. Aggregate for each country `c`:

   ```
   DVA_c = Σ_{r∈c} Σ_{s∈c} F[r,s]
   FVA_c = Σ_{r∉c} Σ_{s∈c} F[r,s]
   DVX_c = Σ_{r∈c} Σ_{s∉c} F[r,s]
   GVCPR_c = (FVA_c + DVX_c) / Exports_c
   ```

### Arguments

* `em` : Twofold EMRIO object.
* `T` : Scenario transaction matrix (e.g., from Monte Carlo reallocation).
* `countries::Vector{String}` : List of country codes.

### Returns

A `DataFrame` with columns:
| ISO_COUNTRY | DVA | FVA | DVX | Exports | GVCPR |

### Notes

* Only intermediate and final exports are included in `ê`.
* GVCPR corresponds to the global value chain participation rate.

### Reference
Casella, B., Bolwijn, R., Moran, D. & Kanemoto, K. UNCTAD insights: Improving the analysis of global value chains: the UNCTAD-Eora Database. Transnational corporations 26, 115–142 (2019).

"""
function compute_gvc_unctad_for_T_simple(em, T, countries::Vector{String})
    # 1) Recompute A, v, L for this scenario
    sol  = _solve_after_T(em, T)
    vhat = spdiagm(0 => sol.v)
    L    = sol.L

    # 2) Build export diagonal including BOTH intermediate and final exports
    #    NOTE: this returns (ehat, exports_by_country) ONLY
    ehat, exports_by_country = _build_ehat_from_T_and_y(em, T, countries)

    # 3) Row index sets per country (needed for DVA/FVA/DVX partitions)
    rows_by_cty, _, _ = _country_index_sets(em, countries)

    # 4) F = v̂ * L * ê
    F = vhat * (L * ehat)

    # 5) Aggregate by country
    K = size(F, 1)
    all_rows = collect(1:K)

    df = DataFrame(ISO_COUNTRY=String[], DVA=Float64[], FVA=Float64[],
                   DVX=Float64[], Exports=Float64[], GVCPR=Float64[])

    for c in countries
        r_rows    = rows_by_cty[c]
        not_r_set = setdiff(all_rows, r_rows)

        DVA_c = sum(@view F[r_rows, r_rows])
        FVA_c = sum(@view F[not_r_set, r_rows])
        DVX_c = sum(@view F[r_rows, not_r_set])
        Ex_c  = exports_by_country[c]
        gpr   = Ex_c > 0 ? (FVA_c + DVX_c) / Ex_c : NaN

        push!(df, (c, DVA_c, FVA_c, DVX_c, Ex_c, gpr))
    end
    return df
end