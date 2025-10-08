"""
_candidate_FF_pairs(em; cross_border=true) -> Vector{Tuple{Int,Int}}

Identify all Firm→Firm (FF) transaction pairs from a twofold EMRIO.

### Arguments

* `em` : Twofold EMRIO object returned by `make_emrio_twofold()`.
* `cross_border::Bool=true` :
  If `true`, only cross-border FF pairs (country_i ≠ country_j) are included.
  If `false`, both domestic and cross-border FF pairs are returned.

### Returns

* `Vector{Tuple{Int,Int}}` :
  List of index pairs `(i, j)` corresponding to source and destination subsegments
  with tags `:Firm`.

### Example

```julia
pairs = candidate_FF_pairs(em; cross_border=true)
length(pairs)  # → number of eligible Firm→Firm links
```

### Notes

Each pair `(i, j)` refers to rows and columns in `em.T`.
The list is later used by the Monte Carlo routine to randomly remove or
reallocate FF transactions.
"""
function _candidate_FF_pairs(em; cross_border::Bool=true)
    parsed = [_parse_sub_label(lbl) for lbl in em.sub_labels]
    K = length(parsed)
    pairs = Tuple{Int,Int}[]
    for i in 1:K, j in 1:K
        if parsed[i].tag === :Firm && parsed[j].tag === :Firm
            if !cross_border || (parsed[i].country != parsed[j].country)
                push!(pairs, (i, j))
            end
        end
    end
    return pairs
end