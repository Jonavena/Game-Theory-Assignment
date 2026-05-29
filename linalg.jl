# ============================================================
#  linalg.jl  –  Linear algebra helpers (no external libraries)
# ============================================================

"""
    solve_linear_system(A, b) -> Vector{Float64} | nothing

Solve the square linear system  Ax = b  via Gaussian elimination
with partial (column) pivoting.  Returns `nothing` when the matrix
is singular (pivot < 1e-12).
"""
function solve_linear_system(A::Matrix{Float64}, b::Vector{Float64})
    n = size(A, 1)
    @assert size(A, 2) == n  "A must be square (got $(size(A)))"
    @assert length(b) == n   "b must have length $n (got $(length(b)))"

    # Augmented matrix [A | b]
    M = hcat(copy(A), copy(b))

    for col in 1:n
        # ── Partial pivot: row with largest absolute value in this column ──
        best_abs = 0.0
        pivot    = -1
        for row in col:n
            if abs(M[row, col]) > best_abs
                best_abs = abs(M[row, col])
                pivot    = row
            end
        end
        best_abs < 1e-12 && return nothing   # singular

        # ── Swap pivot row into position ──
        if pivot != col
            M[[col, pivot], :] = M[[pivot, col], :]
        end

        # ── Normalise pivot row ──
        M[col, :] ./= M[col, col]

        # ── Eliminate column from all other rows ──
        for row in 1:n
            row == col && continue
            M[row, :] .-= M[row, col] .* M[col, :]
        end
    end

    return M[:, n + 1]
end

"""
    vec_max_diff(a, b) -> Float64

Maximum absolute difference between two equal-length vectors.
"""
function vec_max_diff(a::Vector{Float64}, b::Vector{Float64})
    isempty(a) && return 0.0
    return maximum(abs(a[i] - b[i]) for i in eachindex(a))
end
