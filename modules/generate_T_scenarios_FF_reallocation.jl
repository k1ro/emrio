"""
generate_T_scenarios_FF_reallocation(em; R=30, rate=0.10, cross_border=true, seed=20251005)

Monte Carlo generator producing `R` transaction matrices (`T`) after
applying random Firm→Firm (FF) link removals and local reallocation
(FF→FO,OF,OO) within 2×2 base-sector blocks.

### Process per iteration

1. Randomly select a fraction `rate` of all FF pairs without replacement
   (restricted to cross-border if `cross_border=true`).
2. For each selected pair, reallocate its FF value using
   [`realloc_FF_to_FO_OF!`](@ref) while preserving 2×2 block balance.
3. Append the resulting transaction matrix to the output list.

### Arguments

* `em` : Twofold EMRIO object (from `make_emrio_twofold()`).
* `R::Int=30` :
  Number of Monte Carlo iterations (scenarios) to generate.
* `rate::Float64=0.10` :
  Fraction of FF links to reallocate per iteration.
* `cross_border::Bool=true` :
  Restrict reallocation to cross-border FF links only.
* `seed::Int=20251005` :
  Random seed for reproducibility.

### Returns

* `Ts::Vector{Matrix{Float64}}` :
  List of `R` transaction matrices (copies of `em.T` after reallocation).
* `meta::NamedTuple` :
  Metadata including:

  ```
  (Ncand, kdrop, rate, cross_border, seed, max_excess)
  ```

  where `max_excess = max(r_i + c_j − 1)` across all base-sector pairs.

### Notes

* A light sanity check warns if any `(r_i + c_j) > 1`, which may cause
  negative OO values during reallocation.
* Compatible with Julia 1.5: sampling uses shuffling for no-replacement.
* No Leontief or GDP computations are performed; the output matrices are
  ready for subsequent GVC indicator analysis (DVA, FVA, GVCPR).
"""
function generate_T_scenarios_FF_reallocation(em; R::Int=30, rate::Float64=0.10,
                                              cross_border::Bool=true, seed::Int=20251005)
    @assert 0.0 ≤ rate ≤ 1.0 "rate must be in [0,1]."

    # Optional sanity check: ensure r_i + c_j ≤ 1 approximately
    N = length(em.xcol) ÷ 2
    max_excess = 0.0
    for i in 1:N, j in 1:N
        r = row_share(em, i)
        c = col_share(em, j)
        max_excess = max(max_excess, r + c - 1)
    end
    if max_excess > 1e-10
        @warn "Some (r_i + c_j) slightly exceed 1; Max excess=$(round(max_excess, digits=4))"
    end

    # Candidate FF links
    cand = _candidate_FF_pairs(em; cross_border=cross_border)
    @assert !isempty(cand) "No FF candidates found (check cross_border flag)."
    Ncand = length(cand)
    kdrop = round(Int, rate * Ncand)

    rng = Random.MersenneTwister(seed)
    Ts = Vector{typeof(em.T)}(undef, R)

    for rrun in 1:R
        # No-replacement sampling for Julia 1.5: shuffle then take first kdrop
        pick_indices = Int[]
        if kdrop > 0
            pool = collect(1:Ncand)
            Random.shuffle!(rng, pool)
            pick_indices = view(pool, 1:kdrop)
        end

        Tnew = copy(em.T)

        # Apply FF→(FO,OF) reallocation within the 2×2 base-sector block
        for s in pick_indices
            (i, j) = cand[s]
            ibase = base_index(em, i)
            jbase = base_index(em, j)
            _realloc_FF_to_FO_OF!(Tnew, em, ibase, jbase)
        end

        Ts[rrun] = Tnew
    end

    meta = (Ncand=Ncand, kdrop=kdrop, rate=rate,
            cross_border=cross_border, seed=seed, max_excess=max_excess)
    return Ts, meta
end