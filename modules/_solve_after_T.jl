"""
_solve_after_T(em, Tnew) -> NamedTuple{(:A, :v, :va, :L)}

Recompute the Leontief system after modifying the transaction matrix `T`.

### Steps

1. Rebuild technical coefficient matrix `A` using `A[:, j] = Tnew[:, j] / xcol[j]`.
2. Adjust value added `va` to preserve column identity:
   `va := em.va + (sum(em.T, dims=1) - sum(Tnew, dims=1))`.
3. Update value-added coefficients `v = va ./ xcol`.
4. Compute the Leontief inverse `L = (I - A)^(-1)`.

### Arguments

* `em` : Twofold EMRIO object containing `T`, `A`, `va`, and `xcol`.
* `Tnew` : New transaction matrix (after reallocation or perturbation).

### Returns

`NamedTuple` with updated components `(A, v, va, L)`.

### Notes

* Maintains column-wise accounting identity exactly.
* Used within Monte Carlo GVC evaluations to recalculate system response.
"""
function _solve_after_T(em, Tnew)
    xcol = em.xcol
    A = similar(em.A)
    for j in 1:length(xcol)
        if xcol[j] > 0
            @inbounds A[:, j] .= Tnew[:, j] ./ xcol[j]
        else
            @inbounds A[:, j] .= 0.0
        end
    end
    col_old = vec(sum(em.T; dims=1))
    col_new = vec(sum(Tnew;  dims=1))
    va = em.va .+ (col_old .- col_new)
    v  = va ./ xcol

    n = size(A, 1)
    L = inv(Matrix{Float64}(I, n, n) .- A)
    return (A=A, v=v, va=va, L=L)
end