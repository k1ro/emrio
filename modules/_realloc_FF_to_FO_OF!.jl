"""
realloc_FF_to_FO_OF!(T, em, i_base::Int, j_base::Int)

Perform a local 2×2 reallocation within the base-sector pair `(i_base, j_base)`.

This operation redistributes a Firm→Firm (FF) transaction value Δ from
cell `(iF, jF)` to the corresponding Firm→Other (FO) and Other→Firm (OF)
cells, while subtracting Δ from the Other→Other (OO) cell to preserve the
row and column sums of that 2×2 block.

### Arguments

* `T::AbstractMatrix{<:Real}` : Transaction matrix to modify in-place.
* `em` : Twofold EMRIO object defining the Firm/Other mapping.
* `i_base::Int`, `j_base::Int` : Indices of the base-sector pair.

### Transformation

Let `(iF,iO)` and `(jF,jO)` denote the Firm/Other rows and columns of the
base sectors. Then:

```
Δ = T[iF, jF]
if Δ > 0:
    T[iF, jF] = 0
    T[iF, jO] += Δ
    T[iO, jF] += Δ
    T[iO, jO] -= Δ
```

This preserves both total supply and total use within the 2×2 block.

### Notes

* Skips the operation if the current FF value `Δ ≤ 0`.
* Used inside the Monte Carlo simulation to simulate FF link “omissions”
  followed by redistribution to FO and OF.
"""
function _realloc_FF_to_FO_OF!(T::AbstractMatrix{<:Real}, em, i_base::Int, j_base::Int)
    iF, iO = 2*i_base-1, 2*i_base
    jF, jO = 2*j_base-1, 2*j_base
    Δ = T[iF, jF]
    Δ ≤ 0.0 && return
    T[iF, jF] = 0.0
    T[iF, jO] += Δ
    T[iO, jF] += Δ
    T[iO, jO] -= Δ
end