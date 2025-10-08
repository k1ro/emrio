"""
_default_firm_shares()

Return the default firm-share dictionary for the twofold EMRIO split
(`Firm` vs. `Other`) applied to both rows (supply side) and columns (use side).

### Purpose

Provides default proportions of "Firm" entities within each (country, sector)
at the base-sector level. These shares are used for:

* Row expansion matrix `R` (supply-side firm ratio `r_i`)
* Column expansion matrix `C` (use-side firm ratio `c_j`)

### Returns

* `Dict{Tuple{String,String}, Float64}` :
  Mapping `(country, sector)` → firm share ∈ [0,1].

All shares are defined such that `r_max + c_max ≤ 0.90`, ensuring that
each twofold 2×2 block satisfies the local accounting constraint
`r_i + c_j ≤ 1`, preventing negative “Other–Other” (OO) terms during reallocation.

### Default values

| Country | Sector    | Firm Share |
| ------- | --------- | ---------- |
| A       | Primary   | 0.45       |
| A       | Secondary | 0.35       |
| A       | Tertiary  | 0.40       |
| B       | Primary   | 0.45       |
| B       | Secondary | 0.35       |
| B       | Tertiary  | 0.40       |

### Example

```julia
shares = _default_firm_shares()
shares[("A","Primary")]    # → 0.45
shares[("B","Tertiary")]   # → 0.40
```

### Notes

* Custom shares can be passed to `make_emrio_twofold()` via keyword arguments
  (`row_shares`, `col_shares`).
* Values should remain within [0,1] to preserve balance consistency.

"""
function _default_firm_shares()
    # Keys follow labels in sector.idx_country / sector.idx_sector
    # All Firm shares ≤ 0.45, so r_max + c_max ≤ 0.90 < 1.0
    return Dict{Tuple{String,String}, Float64}(
        ("A","Primary")   => 0.45,
        ("A","Secondary") => 0.35,
        ("A","Tertiary")  => 0.40,
        ("B","Primary")   => 0.45,
        ("B","Secondary") => 0.35,
        ("B","Tertiary")  => 0.40
    )
end