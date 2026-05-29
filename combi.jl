# ============================================================
#  combi.jl  –  Combinatorics helpers (no external libraries)
# ============================================================

"""
    combinations(v, k) -> Vector{Vector{T}}

All k-element subsets of `v` in lexicographic order.
"""
function combinations(v::Vector{T}, k::Int) where T
    result = Vector{Vector{T}}()
    n = length(v)
    (k < 0 || k > n) && return result
    if k == 0
        push!(result, T[])
        return result
    end

    # Combinatorial number system: iterate with index array
    idx = collect(1:k)       # current combination indices into v

    while true
        push!(result, [v[i] for i in idx])

        # Find rightmost index that can be incremented
        i = k
        while i >= 1 && idx[i] == n - k + i
            i -= 1
        end
        i == 0 && break

        idx[i] += 1
        for j in (i + 1):k
            idx[j] = idx[j - 1] + 1
        end
    end

    return result
end

"""
    cartesian_product(vecs) -> Vector{Vector{T}}

Cartesian product of a list of vectors.
Returns `[T[]]` when `vecs` is empty (one empty tuple).
"""
function cartesian_product(vecs::Vector{Vector{T}}) where T
    isempty(vecs) && return [T[]]

    result = [[x] for x in vecs[1]]
    for i in 2:length(vecs)
        new_result = Vector{Vector{T}}()
        for existing in result
            for x in vecs[i]
                push!(new_result, vcat(existing, [x]))
            end
        end
        result = new_result
    end
    return result
end

"""
    powerset_nonempty(v) -> Vector{Vector{T}}

All non-empty subsets of `v`.
"""
function powerset_nonempty(v::Vector{T}) where T
    n = length(v)
    result = Vector{Vector{T}}()
    for mask in 1:(2^n - 1)          # skip mask == 0 (empty set)
        subset = T[]
        for bit in 0:(n - 1)
            (mask >> bit) & 1 == 1 && push!(subset, v[bit + 1])
        end
        push!(result, subset)
    end
    return result
end
