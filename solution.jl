# ============================================================
#  solution.jl  –  Problem 2 (Part C)
#  Solution concepts for extensive-form games:
#    • backward_induction   (perfect-information games)
#    • find_spne            (general: subgame reduction + NE fallback)
# ============================================================

# ─── Strategy types ───────────────────────────────────────────────────────

"""
    PureExtensiveStrategy

A pure strategy in an extensive-form game.
Maps `info_set_id → action` for every information set of one player.
"""
const PureExtensiveStrategy = Dict{Int, String}

# ─── Result type ──────────────────────────────────────────────────────────

"""
    SPNEResult

Outcome of a SPNE computation.

Fields
------
- `found_spne`    : `true` iff a subgame-perfect NE was found
- `strategies`    : one `PureExtensiveStrategy` per player
- `root_payoffs`  : expected payoff vector at the root
- `method`        : human-readable tag describing the algorithm used
"""
struct SPNEResult
    found_spne   :: Bool
    strategies   :: Vector{PureExtensiveStrategy}
    root_payoffs :: Vector{Float64}
    method       :: String
end

# ─── Payoff computation ───────────────────────────────────────────────────

"""
    compute_payoffs(game, node_id, strategies, resolved) -> Vector{Float64}

Recursively compute expected payoffs starting at `node_id` under
the pure strategy profile `strategies`.

When `node_id` is a key in `resolved`, the stored payoffs are returned
immediately (used during iterative subgame reduction).
"""
function compute_payoffs(
        game      :: ExtensiveFormGame,
        node_id   :: Int,
        strategies:: Vector{PureExtensiveStrategy},
        resolved  :: Dict{Int, Vector{Float64}} = Dict{Int,Vector{Float64}}())::Vector{Float64}

    # Resolved sub-subgame: use stored payoffs
    haskey(resolved, node_id) && return copy(resolved[node_id])

    node = game.nodes[node_id]

    if node.type == TERMINAL
        return copy(node.payoffs)

    elseif node.type == CHANCE
        payoffs = zeros(game.n_players)
        for a in node.actions
            cid = node.children[a]
            payoffs .+= node.action_probs[a] .*
                        compute_payoffs(game, cid, strategies, resolved)
        end
        return payoffs

    else  # DECISION
        iset_id = node.info_set_id
        player  = node.player
        @assert(haskey(strategies[player], iset_id),
            "No strategy for player $player at info set $iset_id")
        action  = strategies[player][iset_id]
        @assert(haskey(node.children, action),
            "Action '$action' not available at node $node_id")
        return compute_payoffs(game, node.children[action], strategies, resolved)
    end
end

# ─── Backward induction (perfect information) ─────────────────────────────

"""
    backward_induction(game) -> SPNEResult

Find a subgame-perfect Nash equilibrium via backward induction.
**Requires perfect information** (every information set is a singleton).

At each decision node the active player chooses the action that maximises
their own payoff, given optimal play downstream.  Ties are broken in
favour of lower-index actions.
"""
function backward_induction(game::ExtensiveFormGame)::SPNEResult
    strategies = [PureExtensiveStrategy() for _ in 1:game.n_players]

    function solve(nid::Int)::Vector{Float64}
        node = game.nodes[nid]

        node.type == TERMINAL && return copy(node.payoffs)

        if node.type == CHANCE
            pay = zeros(game.n_players)
            for a in node.actions
                pay .+= node.action_probs[a] .* solve(node.children[a])
            end
            return pay
        end

        # DECISION
        player  = node.player
        iset_id = node.info_set_id

        best_pay    = nothing
        best_action = ""

        for a in node.actions
            haskey(node.children, a) || continue
            child_pay = solve(node.children[a])
            if best_pay === nothing || child_pay[player] > best_pay[player]
                best_pay    = child_pay
                best_action = a
            end
        end

        strategies[player][iset_id] = best_action
        return best_pay
    end

    root_pay = solve(game.root_id)
    return SPNEResult(true, strategies, root_pay, "backward_induction")
end

# ─── Normal-form conversion of a subgame ──────────────────────────────────

"""
    build_strategy_lists(game, active_isets) -> (strat_lists, strat_names)

For each player build an ordered list of `PureExtensiveStrategy` objects
covering the info sets in `active_isets`.  The normal-form index of each
strategy corresponds to its position in the list.
"""
function build_strategy_lists(
        game         :: ExtensiveFormGame,
        active_isets :: Dict{Int, InformationSet})

    strat_lists = Vector{Vector{PureExtensiveStrategy}}()
    strat_names = Vector{Vector{String}}()

    for p in 1:game.n_players
        p_iset_ids = sort([id for (id, iset) in active_isets if iset.player == p])

        if isempty(p_iset_ids)
            push!(strat_lists, [PureExtensiveStrategy()])
            push!(strat_names, ["∅"])
            continue
        end

        action_lists = [active_isets[id].actions for id in p_iset_ids]
        combos       = cartesian_product(action_lists)

        strats = PureExtensiveStrategy[]
        names  = String[]
        for combo in combos
            s = PureExtensiveStrategy()
            parts = String[]
            for (k, isid) in enumerate(p_iset_ids)
                s[isid] = combo[k]
                push!(parts, "I$(isid):$(combo[k])")
            end
            push!(strats, s)
            push!(names,  join(parts, ","))
        end
        push!(strat_lists, strats)
        push!(strat_names, names)
    end

    return strat_lists, strat_names
end

"""
    subgame_to_normal_form(game, subgame_root, resolved) -> (NormalFormGame, strat_lists)

Convert the subgame rooted at `subgame_root` into a `NormalFormGame`,
treating nodes in `resolved` as terminal nodes with fixed payoffs.

Returns both the normal-form game and the strategy-list mapping so
that a NE index can be translated back to extensive-form strategies.
"""
function subgame_to_normal_form(
        game         :: ExtensiveFormGame,
        subgame_root :: Int,
        resolved     :: Dict{Int, Vector{Float64}} = Dict{Int,Vector{Float64}}())

    act_isets   = active_info_sets(game, subgame_root, resolved)
    strat_lists, strat_names = build_strategy_lists(game, act_isets)
    n_strats    = [length(ps) for ps in strat_lists]

    # Build payoff arrays
    payoff_arrs = [zeros(Float64, n_strats...) for _ in 1:game.n_players]

    for combo in cartesian_product([collect(1:n) for n in n_strats])
        combined = [strat_lists[p][combo[p]] for p in 1:game.n_players]
        payoffs  = compute_payoffs(game, subgame_root, combined, resolved)
        for p in 1:game.n_players
            payoff_arrs[p][combo...] = payoffs[p]
        end
    end

    nf = NormalFormGame(payoff_arrs;
                        strategy_names = strat_names,
                        player_names   = game.player_names)
    return nf, strat_lists
end

# ─── SPNE via iterative subgame reduction ─────────────────────────────────

"""
    find_spne(game) -> SPNEResult

Find a subgame-perfect Nash equilibrium.

**Perfect information**: uses backward induction (exact, always succeeds).

**Imperfect information**: iterative subgame reduction.
  1. Find all proper subgame roots, sorted deepest-first.
  2. For each proper subgame: convert to normal form, find a pure-strategy
     NE, record the NE strategies and payoffs.
  3. Continue up to the root.
  4. If **no** proper subgames exist, solve the full game's normal form
     for pure NE.
  5. If no pure NE exists anywhere, reports this and returns the
     strategy profile found so far (best-effort).
"""
function find_spne(game::ExtensiveFormGame)::SPNEResult
    # Case 1: perfect information → backward induction
    is_perfect_information(game) && return backward_induction(game)

    # Case 2: imperfect information → subgame reduction
    all_roots = find_subgames(game)
    # Deepest subgames first (most ancestors = deepest)
    sort!(all_roots; by = id -> -length(get_ancestors(game, id)))

    resolved       = Dict{Int, Vector{Float64}}()
    full_strategies= [PureExtensiveStrategy() for _ in 1:game.n_players]
    found_pure     = true
    used_method    = "subgame_reduction"

    for sgroot in all_roots
        nf, strat_lists = subgame_to_normal_form(game, sgroot, resolved)
        pure_nes        = pure_nash_equilibria(nf)

        if isempty(pure_nes)
            # No pure NE in this subgame
            found_pure  = false
            used_method = "no_pure_ne"
            # Use first available strategy (arbitrary; only payoffs matter here)
            for p in 1:game.n_players
                isempty(strat_lists[p]) || merge!(full_strategies[p], strat_lists[p][1])
            end
            resolved[sgroot] = zeros(game.n_players)   # placeholder
        else
            ne = pure_nes[1]   # choose first NE (could enumerate all)
            ne_strats = [strat_lists[p][ne[p]] for p in 1:game.n_players]
            for p in 1:game.n_players
                merge!(full_strategies[p], ne_strats[p])
            end
            resolved[sgroot] = compute_payoffs(game, sgroot, ne_strats, resolved)
        end
    end

    root_pay = get(resolved, game.root_id, zeros(game.n_players))

    return SPNEResult(found_pure, full_strategies, root_pay, used_method)
end

# ─── Display ──────────────────────────────────────────────────────────────

function print_spne(game::ExtensiveFormGame, r::SPNEResult)
    println("\n── ", r.found_spne ? "Subgame Perfect Nash Equilibrium" :
                                     "Pure Strategy Nash Equilibrium",
            "  [$(r.method)] ──")
    println("  Root payoffs: $(round.(r.root_payoffs; digits=4))")
    println("  Strategies:")
    for (p, strat) in enumerate(r.strategies)
        if isempty(strat)
            println("    $(game.player_names[p]): (no moves in this game)")
            continue
        end
        println("    $(game.player_names[p]):")
        for (isid, action) in sort(collect(strat); by = x -> x[1])
            iset = game.info_sets[isid]
            nodes_str = join(iset.node_ids, ",")
            println("      Info-set $isid {nodes: $nodes_str}  →  '$action'")
        end
    end
    println()
end