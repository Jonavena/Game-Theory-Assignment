# ============================================================
#  subgames.jl  –  Problem 2 (Part B)
#  Identify proper subgames in an extensive-form game.
# ============================================================

"""
    is_subgame_root(game, node_id) -> Bool

A node `h` is the root of a **proper subgame** iff:

1. `h` is not a terminal node.
2. If `h` is a decision node its information set is the singleton `{h}`.
3. No information set has nodes both inside **and** outside the subtree
   rooted at `h` (the subgame boundary does not cut any information set).
"""
function is_subgame_root(game::ExtensiveFormGame, node_id::Int)::Bool
    node = game.nodes[node_id]

    # Condition 0: non-terminal
    node.type == TERMINAL && return false

    # Condition 1: decision nodes must have singleton info set
    if node.type == DECISION
        iset = game.info_sets[node.info_set_id]
        length(iset.node_ids) == 1 || return false
    end

    # Condition 2: no information set straddles the boundary
    subtree = get_subtree_nodes(game, node_id)
    for (_, iset) in game.info_sets
        n_inside = count(nid -> nid in subtree, iset.node_ids)
        # Partially inside → boundary violation
        if n_inside > 0 && n_inside < length(iset.node_ids)
            return false
        end
    end

    return true
end

"""
    find_subgames(game) -> Vector{Int}

Return all subgame-root node IDs, sorted **ancestor-first**
(root of the game tree appears before any of its subgame descendants).
"""
function find_subgames(game::ExtensiveFormGame)::Vector{Int}
    roots = [id for id in keys(game.nodes) if is_subgame_root(game, id)]
    # Shallower nodes (fewer ancestors) come first
    sort!(roots; by = id -> length(get_ancestors(game, id)))
    return roots
end

"""
    is_perfect_information(game) -> Bool

`true` iff every information set is a singleton (perfect information game).
"""
function is_perfect_information(game::ExtensiveFormGame)::Bool
    return all(length(iset.node_ids) == 1 for (_, iset) in game.info_sets)
end

"""
    subgame_info_sets(game, subgame_root) -> Dict{Int, InformationSet}

All information sets whose nodes lie entirely within the subtree of `subgame_root`.
"""
function subgame_info_sets(game::ExtensiveFormGame, subgame_root::Int)
    subtree = get_subtree_nodes(game, subgame_root)
    return Dict(id => iset
                for (id, iset) in game.info_sets
                if all(n in subtree for n in iset.node_ids))
end

"""
    player_info_sets_in_subgame(game, subgame_root, player) -> Vector{Int}

Info-set IDs for `player` within the subgame, sorted ascending.
"""
function player_info_sets_in_subgame(
        game         :: ExtensiveFormGame,
        subgame_root :: Int,
        player       :: Int)::Vector{Int}

    isets = subgame_info_sets(game, subgame_root)
    return sort([id for (id, iset) in isets if iset.player == player])
end

"""
    active_info_sets(game, subgame_root, resolved) -> Dict{Int, InformationSet}

Info sets within `subgame_root`'s subtree, **excluding** those inside
any already-resolved sub-subgame (passed via the `resolved` dict).
Used during iterative subgame reduction.
"""
function active_info_sets(
        game         :: ExtensiveFormGame,
        subgame_root :: Int,
        resolved     :: Dict{Int, Vector{Float64}})

    subtree = get_subtree_nodes(game, subgame_root)

    # Nodes that live strictly inside a resolved sub-subgame
    cut_nodes = Set{Int}()
    for (res_root, _) in resolved
        res_root == subgame_root && continue
        res_root in subtree     || continue
        union!(cut_nodes, get_subtree_nodes(game, res_root))
    end

    all_isets = subgame_info_sets(game, subgame_root)

    # Keep only info sets with no nodes in the cut set
    return Dict(id => iset
                for (id, iset) in all_isets
                if !any(n in cut_nodes for n in iset.node_ids))
end

# ─── Display helpers ──────────────────────────────────────────────────────

"""Print a summary of all subgames found in the game."""
function print_subgames(game::ExtensiveFormGame, roots::Vector{Int})
    println("\n── Subgames ────────────────────────────────────────────")
    if isempty(roots)
        println("  (none found)")
        return
    end
    println("  $(length(roots)) subgame(s) found:")
    for r in roots
        depth = length(get_ancestors(game, r))
        sz    = length(get_subtree_nodes(game, r))
        node  = game.nodes[r]
        lbl   = node.type == CHANCE ? "Chance" : game.player_names[node.player]
        println("  • root=$(r)  depth=$(depth)  subtree_size=$(sz)  mover=$(lbl)")
    end
end
