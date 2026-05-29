# ============================================================
#  extensive_form.jl  –  Problem 2 (Part A)
#  Multi-player game in extensive (sequential) form.
#  Supports imperfect information via information sets.
# ============================================================

# ─── Node types ───────────────────────────────────────────────────────────

"""Possible roles for a game node."""
@enum NodeType DECISION TERMINAL CHANCE

# ─── Core structs ─────────────────────────────────────────────────────────

"""
    GameNode

A single node in the extensive-form game tree.

Fields
------
- `id`           : unique integer identifier
- `type`         : DECISION | TERMINAL | CHANCE
- `player`       : 1-indexed mover (0 for TERMINAL / CHANCE)
- `info_set_id`  : information set this node belongs to (-1 if N/A)
- `payoffs`      : payoff vector (only for TERMINAL; else empty)
- `actions`      : ordered list of action labels at this node
- `children`     : action → child node id
- `action_probs` : action → probability (CHANCE nodes only)
- `parent_id`    : id of parent node (-1 for root)
- `parent_action`: action label taken from parent to reach this node
"""
mutable struct GameNode
    id           :: Int
    type         :: NodeType
    player       :: Int
    info_set_id  :: Int
    payoffs      :: Vector{Float64}
    actions      :: Vector{String}
    children     :: Dict{String, Int}
    action_probs :: Dict{String, Float64}
    parent_id    :: Int
    parent_action:: String
end

"""
    InformationSet

A set of decision nodes belonging to the same player, between which that
player cannot distinguish (same actions must be available at every node).
"""
struct InformationSet
    id       :: Int
    player   :: Int
    node_ids :: Vector{Int}
    actions  :: Vector{String}   # identical for every node in the set
end

"""
    ExtensiveFormGame

An n-player extensive-form game, possibly with imperfect information.

Fields
------
- `n_players`   : number of strategic players
- `player_names`
- `nodes`       : id → GameNode
- `root_id`     : id of the root node
- `info_sets`   : id → InformationSet
"""
mutable struct ExtensiveFormGame
    n_players    :: Int
    player_names :: Vector{String}
    nodes        :: Dict{Int, GameNode}
    root_id      :: Int
    info_sets    :: Dict{Int, InformationSet}
    _next_nid    :: Int   # internal counter
    _next_isid   :: Int   # internal counter
end

"""Create a new, empty extensive-form game."""
function ExtensiveFormGame(
        n_players   :: Int;
        player_names :: Vector{String} = ["Player $i" for i in 1:n_players])

    ExtensiveFormGame(
        n_players, player_names,
        Dict{Int, GameNode}(), -1,
        Dict{Int, InformationSet}(), 1, 1)
end

# ─── Node constructors ────────────────────────────────────────────────────

"""
    add_decision_node!(game, player, actions; parent_id, parent_action) -> node_id

Add a decision node.  The node is placed at the root if `parent_id == -1`.
`info_set_id` must be set separately via `add_information_set!`.
"""
function add_decision_node!(
        game         :: ExtensiveFormGame,
        player       :: Int,
        actions      :: Vector{String};
        parent_id    :: Int    = -1,
        parent_action:: String = "")

    id   = game._next_nid;  game._next_nid += 1
    node = GameNode(id, DECISION, player, -1, Float64[],
                    actions, Dict{String,Int}(), Dict{String,Float64}(),
                    parent_id, parent_action)
    game.nodes[id] = node
    parent_id == -1 && (game.root_id = id)
    return id
end

"""
    add_terminal_node!(game, payoffs; parent_id, parent_action) -> node_id

Add a terminal node with the given payoff vector (length = n_players).
"""
function add_terminal_node!(
        game         :: ExtensiveFormGame,
        payoffs      :: Vector{Float64};
        parent_id    :: Int    = -1,
        parent_action:: String = "")

    @assert(length(payoffs) == game.n_players,
        "payoffs length $(length(payoffs)) ≠ n_players $(game.n_players)")
    id   = game._next_nid;  game._next_nid += 1
    node = GameNode(id, TERMINAL, 0, -1, copy(payoffs),
                    String[], Dict{String,Int}(), Dict{String,Float64}(),
                    parent_id, parent_action)
    game.nodes[id] = node
    return id
end

"""
    add_chance_node!(game, actions, probs; parent_id, parent_action) -> node_id

Add a chance (Nature) node.  `probs` must sum to 1.
"""
function add_chance_node!(
        game         :: ExtensiveFormGame,
        actions      :: Vector{String},
        probs        :: Vector{Float64};
        parent_id    :: Int    = -1,
        parent_action:: String = "")

    @assert length(actions) == length(probs) "actions/probs length mismatch"
    @assert abs(sum(probs) - 1.0) < 1e-10   "probabilities must sum to 1"

    id   = game._next_nid;  game._next_nid += 1
    ap   = Dict(a => p for (a, p) in zip(actions, probs))
    node = GameNode(id, CHANCE, 0, -1, Float64[],
                    actions, Dict{String,Int}(), ap,
                    parent_id, parent_action)
    game.nodes[id] = node
    parent_id == -1 && (game.root_id = id)
    return id
end

# ─── Information sets ─────────────────────────────────────────────────────

"""
    add_information_set!(game, player, node_ids, actions) -> info_set_id

Create a new information set grouping `node_ids` for `player`.
Automatically updates the `info_set_id` field of all listed nodes.
All nodes must already exist and belong to `player`.
"""
function add_information_set!(
        game     :: ExtensiveFormGame,
        player   :: Int,
        node_ids :: Vector{Int},
        actions  :: Vector{String})

    @assert !isempty(node_ids) "Information set must contain at least one node"
    for nid in node_ids
        @assert haskey(game.nodes, nid)          "Node $nid not found"
        @assert game.nodes[nid].player == player  "Node $nid belongs to player $(game.nodes[nid].player), not $player"
        @assert game.nodes[nid].actions == actions "All nodes in an info set must have identical actions"
    end

    id   = game._next_isid;  game._next_isid += 1
    iset = InformationSet(id, player, copy(node_ids), copy(actions))
    game.info_sets[id] = iset

    for nid in node_ids
        game.nodes[nid].info_set_id = id
    end
    return id
end

# ─── Tree-building helper ─────────────────────────────────────────────────

"""
    link_nodes!(game, parent_id, action, child_id)

Connect `parent_id` →[action]→ `child_id`.
Updates `parent_id` and `parent_action` fields on the child.
"""
function link_nodes!(
        game      :: ExtensiveFormGame,
        parent_id :: Int,
        action    :: String,
        child_id  :: Int)

    parent = game.nodes[parent_id]
    @assert action in parent.actions "Action '$action' not listed at node $parent_id"
    parent.children[action]         = child_id
    game.nodes[child_id].parent_id  = parent_id
    game.nodes[child_id].parent_action = action
end

# ─── Tree traversal ───────────────────────────────────────────────────────

"""
    get_subtree_nodes(game, node_id) -> Set{Int}

All node IDs in the subtree rooted at `node_id` (inclusive).
"""
function get_subtree_nodes(game::ExtensiveFormGame, node_id::Int)::Set{Int}
    visited = Set{Int}()
    stack   = [node_id]
    while !isempty(stack)
        nid = pop!(stack)
        push!(visited, nid)
        for (_, cid) in game.nodes[nid].children
            push!(stack, cid)
        end
    end
    return visited
end

"""
    get_ancestors(game, node_id) -> Vector{Int}

Ancestor node IDs from root (index 1) to parent (last index).
"""
function get_ancestors(game::ExtensiveFormGame, node_id::Int)::Vector{Int}
    ancs    = Int[]
    current = game.nodes[node_id].parent_id
    while current != -1
        push!(ancs, current)
        current = game.nodes[current].parent_id
    end
    return reverse(ancs)
end

"""All terminal node IDs."""
terminal_nodes(game::ExtensiveFormGame) =
    [id for (id, n) in game.nodes if n.type == TERMINAL]

"""All decision node IDs."""
decision_nodes(game::ExtensiveFormGame) =
    [id for (id, n) in game.nodes if n.type == DECISION]

# ─── Display ──────────────────────────────────────────────────────────────

function Base.show(io::IO, game::ExtensiveFormGame)
    nt = count(n -> n.type == TERMINAL, values(game.nodes))
    println(io, "ExtensiveFormGame  [$(game.n_players) players]")
    println(io, "  Players   : $(join(game.player_names, ", "))")
    println(io, "  Nodes     : $(length(game.nodes))  (root = $(game.root_id), terminal = $nt)")
    println(io, "  Info sets : $(length(game.info_sets))")
end

"""
    print_game_tree(game[, node_id, depth])

Recursively print the game tree in a readable indented format.
"""
function print_game_tree(game::ExtensiveFormGame,
                         node_id::Int = game.root_id,
                         depth  ::Int = 0)
    node   = game.nodes[node_id]
    indent = "  " ^ depth

    if node.type == TERMINAL
        pstr = join(round.(node.payoffs; digits=2), ", ")
        println("$(indent)● [payoffs: $pstr]")

    elseif node.type == CHANCE
        println("$(indent)⊕ Chance  (node $(node.id))")
        for a in node.actions
            p   = node.action_probs[a]
            cid = get(node.children, a, -1)
            println("$(indent)  ─[$a, p=$(round(p;digits=3))]→")
            cid != -1 && print_game_tree(game, cid, depth + 2)
        end

    else   # DECISION
        iset    = game.info_sets[node.info_set_id]
        iset_lbl= length(iset.node_ids) > 1 ? " [iset $(node.info_set_id)]" : ""
        println("$(indent)□ $(game.player_names[node.player])$(iset_lbl)  (node $(node.id))")
        for a in node.actions
            cid = get(node.children, a, -1)
            println("$(indent)  ─[$a]→")
            cid != -1 && print_game_tree(game, cid, depth + 2)
        end
    end
end