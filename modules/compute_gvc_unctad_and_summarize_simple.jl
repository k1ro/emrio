"""
compute_gvc_unctad_and_summarize_simple(em, Ts, countries; probs=(0.025,0.5,0.975))

Batch-evaluate UNCTAD-style GVC indicators (Casella et al, 2019) for multiple Monte Carlo
transaction-matrix scenarios and summarize results with uncertainty
statistics.

### Arguments

* `em` : Twofold EMRIO structure.
* `Ts::Vector{Matrix}` : List of transaction matrices (e.g., from `generate_T_scenarios_FF_reallocation()`).
* `countries::Vector{String}` : List of country codes.
* `probs::Tuple{Float64,Float64,Float64}` :
  Quantile probabilities for confidence intervals (default: 2.5%, 50%, 97.5%).

### Returns

* `df_each::Vector{DataFrame}` :
  GVC indicator tables for each scenario.
* `df_sum::DataFrame` :
  Summary table per country with median, confidence interval, and uncertainty metrics.

### Summary metrics

For each indicator (DVA, FVA, DVX, Exports, GVCPR):

* Median value
* 2.5% and 97.5% quantiles
* ±U% = half-width of 95% CI relative to median (×100)
* ε = ±U% per 10% reallocation (for normalization)

### Example

```julia
df_each, df_sum = compute_gvc_unctad_and_summarize_simple(em, Ts, ["A","B"])
first(df_each[1])
first(df_sum)
```

### Reference
Casella, B., Bolwijn, R., Moran, D. & Kanemoto, K. UNCTAD insights: Improving the analysis of global value chains: the UNCTAD-Eora Database. Transnational corporations 26, 115–142 (2019).

"""
function compute_gvc_unctad_and_summarize_simple(em, Ts::Vector, countries::Vector{String};
                                                 probs=(0.025, 0.5, 0.975))
    R = length(Ts)
    df_each = Vector{DataFrame}(undef, R)

    # Accumulators per metric per country
    buf = Dict{String, Dict{Symbol, Vector{Float64}}}()
    for c in countries
        buf[c] = Dict(
            :DVA => Float64[], :FVA => Float64[], :DVX => Float64[],
            :Exports => Float64[], :GVCPR => Float64[]
        )
    end

    # Compute per scenario
    for (k, T) in enumerate(Ts)
        d = compute_gvc_unctad_for_T_simple(em, T, countries)
        df_each[k] = d
        for row in eachrow(d)
            push!(buf[row.ISO_COUNTRY][:DVA],     row.DVA)
            push!(buf[row.ISO_COUNTRY][:FVA],     row.FVA)
            push!(buf[row.ISO_COUNTRY][:DVX],     row.DVX)
            push!(buf[row.ISO_COUNTRY][:Exports], row.Exports)
            push!(buf[row.ISO_COUNTRY][:GVCPR],   row.GVCPR)
        end
    end

    # Quantiles and uncertainty
    _q(v::Vector{Float64}, p) = quantile(v, p)
    function _summ(v::Vector{Float64})
        med = _q(v, probs[2]); lo = _q(v, probs[1]); hi = _q(v, probs[3])
        U   = (med ≈ 0) ? 0.0 : ((hi - lo) / (2 * med)) * 100.0
        eps = U / 10.0
        return med, lo, hi, U, eps
    end

    df_sum = DataFrame(
        ISO_COUNTRY = String[],
        DVA_Median = Float64[], DVA_P2_5 = Float64[], DVA_P97_5 = Float64[], DVA_U_pm_pct = Float64[], DVA_epsilon = Float64[],
        FVA_Median = Float64[], FVA_P2_5 = Float64[], FVA_P97_5 = Float64[], FVA_U_pm_pct = Float64[], FVA_epsilon = Float64[],
        DVX_Median = Float64[], DVX_P2_5 = Float64[], DVX_P97_5 = Float64[], DVX_U_pm_pct = Float64[], DVX_epsilon = Float64[],
        EX_Median  = Float64[], EX_P2_5  = Float64[], EX_P97_5  = Float64[], EX_U_pm_pct  = Float64[], EX_epsilon  = Float64[],
        GVCPR_Median = Float64[], GVCPR_P2_5 = Float64[], GVCPR_P97_5 = Float64[], GVCPR_U_pm_pct = Float64[], GVCPR_epsilon = Float64[]
    )

    for c in countries
        DVA_med, DVA_lo, DVA_hi, DVA_U, DVA_eps = _summ(buf[c][:DVA])
        FVA_med, FVA_lo, FVA_hi, FVA_U, FVA_eps = _summ(buf[c][:FVA])
        DVX_med, DVX_lo, DVX_hi, DVX_U, DVX_eps = _summ(buf[c][:DVX])
        EX_med,  EX_lo,  EX_hi,  EX_U,  EX_eps  = _summ(buf[c][:Exports])
        PR_med,  PR_lo,  PR_hi,  PR_U,  PR_eps  = _summ(buf[c][:GVCPR])

        push!(df_sum, (c,
            DVA_med, DVA_lo, DVA_hi, DVA_U, DVA_eps,
            FVA_med, FVA_lo, FVA_hi, FVA_U, FVA_eps,
            DVX_med, DVX_lo, DVX_hi, DVX_U, DVX_eps,
            EX_med,  EX_lo,  EX_hi,  EX_U,  EX_eps,
            PR_med,  PR_lo,  PR_hi,  PR_U,  PR_eps
        ))
    end

    return df_each, df_sum
end