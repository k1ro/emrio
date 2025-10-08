"""
row_share(em, i_base::Int) -> Float64
col_share(em, j_base::Int) -> Float64
base_index(em, k::Int) -> Int

Convenience accessors for the twofold EMRIO object.

### Functions

* `row_share(em, i_base)` :
  Return the firm share on the **supply side** (`r_i`) for base sector `i_base`.
  Equivalent to `em.R[2*i_base-1, i_base]`.

* `col_share(em, j_base)` :
  Return the firm share on the **use side** (`c_j`) for base sector `j_base`.
  Equivalent to `em.C[2*j_base-1, j_base]`.

* `base_index(em, k)` :
  Map a subsegment index `k` (1..2N) back to its parent base-sector index
  according to `em.map[k]`.

### Notes

These are lightweight helper functions to simplify 2×2 block access in
subsequent routines (e.g., firm-to-firm reallocation).
"""
row_share(em, i_base) = em.R[2*i_base-1, i_base]  # r_i
col_share(em, j_base) = em.C[2*j_base-1, j_base]  # c_j
base_index(em, k::Int) = em.map[k]                # sub → base index