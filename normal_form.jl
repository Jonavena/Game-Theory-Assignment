# ============================================================
#  normal_form.jl  –  Problem 1
#  Multi-player game in normal (strategic) form.
#  Solution concepts: pure strategy NE, mixed strategy NE (2-player).
# ============================================================

# ─── Data structures ──────────────────────────────────────────────────────

"""
    NormalFormGame

An n-player game in normal form.

`payoffs[p]` is an `Array{Float64}` with dimensions
`n_strategies[1] × n_strategies[2] × … × n_strategies[n_players]`.
Element `payoffs[p][s1, s2, …, sn]` is player `p`'s payoff when the
strategy profile is `(s1, s2, …, sn)` (all 1-indexed).
"""
struct NormalFormGame
    n_players      :: Int
    n_strategies   :: Vector{Int}
    payoffs        :: Vector{Array{Float64}}  # one array per player
    strategy_names :: Vector{Vector{String}}
    player_names   :: Vector{String}
end

"""
    NormalFormGame(payoffs; strategy_names, player_names)

Construct from a vector of payoff arrays (one per player).
Each array must share the same dimensions.
"""
function NormalFormGame(
        payoffs        :: Vector{Array{Float64}};
        strategy_names :: Union{Vector{Vector{String}}, Nothing} = nothing,
        player_names   :: Union{Vector{String},         Nothing} = nothing)

    n  = length(payoffs)
    @assert n >= 1 "At least one player required"

    dims = size(payoffs[1])
    @assert length(dims) == n "Payoff arrays must have $n dimension(s); got $(length(dims))"
    for (i, p) in enumerate(payoffs)
        @assert size(p) == dims "Player $i payoff has size $(size(p)), expected $dims"
    end

    n_strats = collect(Int, dims)

    snames = strategy_names === nothing ?
        [["S$(i)_$(s)" for s in 1:n_strats[i]] for i in 1:n] :
        strategy_names
    pnames = player_names === nothing ?
        ["Player $i" for i in 1:n] :
        player_names

    NormalFormGame(n, n_strats, payoffs, snames, pnames)
end

# ─── Basic accessors ──────────────────────────────────────────────────────

"""Return player `p`'s payoff at strategy profile `profile` (1-indexed vector)."""
get_payoff(g::NormalFormGame, p::Int, profile) = g.payoffs[p][profile...]

"""All strategy profiles as a `Vector{Vector{Int}}`."""
function all_profiles(g::NormalFormGame)
    cartesian_product([collect(1:s) for s in g.n_strategies])
end

# ─── Expected payoff ──────────────────────────────────────────────────────

"""
    expected_payoff(g, player, strategies) -> Float64

Expected payoff for `player` under the given mixed strategy profile.
`strategies[i]` is a probability vector over player `i`'s pure strategies.
"""
function expected_payoff(g::NormalFormGame, player::Int, strategies::Vector{Vector{Float64}})
    val = 0.0
    for profile in all_profiles(g)
        prob = prod(strategies[i][profile[i]] for i in 1:g.n_players)
        val += prob * get_payoff(g, player, profile)
    end
    return val
end

"""
    eu_pure_vs_mixed(g, player, s, strategies) -> Float64

Expected payoff when `player` deviates to pure strategy `s`,
all others play according to `strategies`.
"""
function eu_pure_vs_mixed(
        g        :: NormalFormGame,
        player   :: Int,
        s        :: Int,
        strategies :: Vector{Vector{Float64}})

    others  = [i for i in 1:g.n_players if i != player]
    isempty(others) && return get_payoff(g, player, [s])

    other_profiles = cartesian_product([collect(1:g.n_strategies[i]) for i in others])
    val = 0.0
    for op in other_profiles
        full = Vector{Int}(undef, g.n_players)
        full[player] = s
        for (k, pid) in enumerate(others)
            full[pid] = op[k]
        end
        prob = prod(strategies[i][full[i]] for i in others)
        val += prob * get_payoff(g, player, full)
    end
    return val
end

# ─── Pure strategy Nash equilibria ───────────────────────────────────────

"""
    pure_nash_equilibria(g) -> Vector{Vector{Int}}

Find all pure strategy Nash equilibria by iterated best-response checking.
Returns a list of strategy profiles (1-indexed).
"""
function pure_nash_equilibria(g::NormalFormGame)::Vector{Vector{Int}}
    equilibria = Vector{Vector{Int}}()

    for profile in all_profiles(g)
        is_ne = true

        for player in 1:g.n_players
            current = get_payoff(g, player, profile)

            for alt in 1:g.n_strategies[player]
                alt == profile[player] && continue
                dev = copy(profile)
                dev[player] = alt
                if get_payoff(g, player, dev) > current + 1e-10
                    is_ne = false
                    break
                end
            end
            is_ne || break
        end

        is_ne && push!(equilibria, copy(profile))
    end

    return equilibria
end

# ─── Mixed strategy Nash equilibria (2-player, exact) ────────────────────

"""
    MixedStrategy

A mixed strategy: a probability distribution over pure strategies.
"""
struct MixedStrategy
    probs :: Vector{Float64}
end

"""
    MixedNashEquilibrium

A mixed strategy Nash equilibrium profile (one per player).
"""
struct MixedNashEquilibrium
    strategies :: Vector{MixedStrategy}
end

"""
    mixed_nash_equilibria_2player(g) -> Vector{MixedNashEquilibrium}

Find **all** mixed strategy Nash equilibria of a 2-player game
via support enumeration.

Algorithm
---------
For every pair of equal-size support sets (S₁, S₂) with |S₁|=|S₂|=k:
1. Solve the linear indifference system for player 2's mixing q over S₂
   (makes player 1 indifferent over S₁).
2. Solve the linear indifference system for player 1's mixing p over S₁
   (makes player 2 indifferent over S₂).
3. Verify all probabilities are non-negative.
4. Check no profitable deviation exists outside the supports.

Pure strategy NE are included as degenerate (k=1) cases.
"""
function mixed_nash_equilibria_2player(g::NormalFormGame)::Vector{MixedNashEquilibrium}
    @assert g.n_players == 2 "Only 2-player games are supported here"

    n1, n2 = g.n_strategies[1], g.n_strategies[2]
    R = g.payoffs[1]   # (n1 × n2) payoff matrix for player 1
    C = g.payoffs[2]   # (n1 × n2) payoff matrix for player 2

    equilibria = Vector{MixedNashEquilibrium}()
    seen       = Vector{Tuple{Vector{Float64}, Vector{Float64}}}()

    is_dup(p, q) = any(vec_max_diff(p, pp) < 1e-8 &&
                       vec_max_diff(q, qq) < 1e-8  for (pp, qq) in seen)

    # ── Try one (supp1, supp2) pair ──────────────────────────────────────
    function try_support(supp1::Vector{Int}, supp2::Vector{Int})
        k = length(supp1)
        @assert length(supp2) == k

        # ─ Solve for q (player 2's mixing over supp2) ─
        # Player 1 must be indifferent over supp1 given q:
        #   Σ_j  q_j R[supp1[1], j] = Σ_j  q_j R[i, j]   ∀ i ∈ supp1
        #   ↕
        #   Σ_j  (R[supp1[1], j] − R[i, j]) q_j = 0       for i = supp1[2..k]
        #   Σ_j  q_j = 1
        Aq = zeros(k, k)
        bq = zeros(k)
        Aq[1, :] .= 1.0;  bq[1] = 1.0          # normalisation

        for r in 2:k
            i = supp1[r]
            for (c, j) in enumerate(supp2)
                Aq[r, c] = R[supp1[1], j] - R[i, j]
            end
        end

        q_supp = solve_linear_system(Aq, bq)
        q_supp === nothing             && return nothing
        any(q_supp .< -1e-10)         && return nothing
        q_supp = max.(q_supp, 0.0)

        # ─ Solve for p (player 1's mixing over supp1) ─
        Ap = zeros(k, k)
        bp = zeros(k)
        Ap[1, :] .= 1.0;  bp[1] = 1.0

        for c in 2:k
            j = supp2[c]
            for (r, i) in enumerate(supp1)
                Ap[c, r] = C[i, supp2[1]] - C[i, j]
            end
        end

        p_supp = solve_linear_system(Ap, bp)
        p_supp === nothing             && return nothing
        any(p_supp .< -1e-10)         && return nothing
        p_supp = max.(p_supp, 0.0)

        # Build full probability vectors
        p = zeros(n1);  for (r, i) in enumerate(supp1); p[i] = p_supp[r]; end
        q = zeros(n2);  for (c, j) in enumerate(supp2); q[j] = q_supp[c]; end

        strats = [p, q]

        # ─ Verify: no profitable deviation outside the support ─
        v1 = eu_pure_vs_mixed(g, 1, supp1[1], strats)
        v2 = eu_pure_vs_mixed(g, 2, supp2[1], strats)

        for i in 1:n1
            i in supp1 && continue
            eu_pure_vs_mixed(g, 1, i, strats) > v1 + 1e-10 && return nothing
        end
        for j in 1:n2
            j in supp2 && continue
            eu_pure_vs_mixed(g, 2, j, strats) > v2 + 1e-10 && return nothing
        end

        return (p, q)
    end

    # ── Enumerate all equal-size support pairs ────────────────────────────
    for k in 1:min(n1, n2)
        for supp1 in combinations(collect(1:n1), k)
            for supp2 in combinations(collect(1:n2), k)
                result = try_support(supp1, supp2)
                if result !== nothing
                    (p, q) = result
                    if !is_dup(p, q)
                        push!(seen, (p, q))
                        push!(equilibria, MixedNashEquilibrium([
                            MixedStrategy(p), MixedStrategy(q)]))
                    end
                end
            end
        end
    end

    return equilibria
end

# ─── Display helpers ──────────────────────────────────────────────────────

function Base.show(io::IO, g::NormalFormGame)
    println(io, "NormalFormGame  [$(g.n_players) players]")
    for i in 1:g.n_players
        println(io, "  $(g.player_names[i]): $(join(g.strategy_names[i], " | "))")
    end
end

"""Pretty-print pure-strategy Nash equilibria."""
function print_pure_ne(g::NormalFormGame, equilibria::Vector{Vector{Int}})
    println("\n── Pure Strategy Nash Equilibria ──────────────────────")
    if isempty(equilibria)
        println("  (none)")
        return
    end
    println("  $(length(equilibria)) equilibri$(length(equilibria) == 1 ? "um" : "a") found:")
    for (k, eq) in enumerate(equilibria)
        strats  = join(["$(g.player_names[i]):$(g.strategy_names[i][eq[i]])" for i in 1:g.n_players], "  ")
        payoffs = join(["$(round(get_payoff(g, i, eq); digits=4))" for i in 1:g.n_players], ", ")
        println("  [$k]  $strats   →  payoffs = ($payoffs)")
    end
end

"""Pretty-print mixed-strategy Nash equilibria."""
function print_mixed_ne(g::NormalFormGame, equilibria::Vector{MixedNashEquilibrium})
    println("\n── Mixed Strategy Nash Equilibria ─────────────────────")
    if isempty(equilibria)
        println("  (none beyond pure NE)")
        return
    end
    for (k, ne) in enumerate(equilibria)
        strats = [ne.strategies[i].probs for i in 1:g.n_players]
        println("  Equilibrium $k:")
        for i in 1:g.n_players
            ps    = ne.strategies[i].probs
            parts = ["$(round(ps[s]; digits=6))·$(g.strategy_names[i][s])"
                     for s in 1:g.n_strategies[i] if ps[s] > 1e-10]
            eu    = round(expected_payoff(g, i, strats); digits=6)
            println("    $(g.player_names[i]): $(join(parts, " + "))   (EU = $eu)")
        end
    end
end
