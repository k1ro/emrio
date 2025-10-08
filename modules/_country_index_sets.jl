
"""
_country_index_sets(em, countries::Vector{String})
-> (rows_by_cty::Dict, cols_by_cty::Dict, parsed::Vector)

Build row and column index sets for each country based on `em.sub_labels`.

### Arguments

* `em` : Twofold EMRIO object containing field `sub_labels`.
* `countries::Vector{String}` : List of country codes, e.g., `["A","B"]`.

### Returns

* `rows_by_cty::Dict{String, Vector{Int}}` : Indices of rows belonging to each country.
* `cols_by_cty::Dict{String, Vector{Int}}` : Indices of columns belonging to each country.
* `parsed::Vector{NamedTuple}` : Parsed components `(country, sector, tag)` for each sub_label.

### Notes

Used in GVC computations to identify domestic vs. foreign cell positions for DVA/FVA/DVX aggregation.
"""
function _country_index_sets(em, countries::Vector{String})
    K = length(em.sub_labels)
    parsed = [_parse(lbl) for lbl in em.sub_labels]
    rows_by_cty = Dict{String, Vector{Int}}()
    cols_by_cty = Dict{String, Vector{Int}}()
    for c in countries
        rows_by_cty[c] = Int[]
        cols_by_cty[c] = Int[]
    end
    for i in 1:K
        c = parsed[i].country
        push!(rows_by_cty[c], i)
        push!(cols_by_cty[c], i)
    end
    return rows_by_cty, cols_by_cty, parsed
end
