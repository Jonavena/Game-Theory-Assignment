# ============================================================
#  GameTheory.jl  –  Top-level module
#  Computational Game Theory  |  COM810S  |  NUST
# ============================================================
#
#  Problem 1 (Normal Form Games)
#  ──────────────────────────────
#  • NormalFormGame, MixedStrategy, MixedNashEquilibrium
#  • pure_nash_equilibria
#  • mixed_nash_equilibria_2player
#
#  Problem 2 (Extensive Form Games)
#  ──────────────────────────────────
#  • NodeType (DECISION | TERMINAL | CHANCE)
#  • GameNode, InformationSet, ExtensiveFormGame
#  • Builder API: add_decision_node!, add_terminal_node!,
#                 add_chance_node!, add_information_set!, link_nodes!
#  • find_subgames, is_perfect_information
#  • backward_induction, find_spne
#  • SPNEResult, PureExtensiveStrategy

module GameTheory

# ── Internal helpers (not exported, but available as GameTheory.xxx) ──────
include("linalg.jl")   # solve_linear_system, vec_max_diff
include("utils.jl")    # combinations, cartesian_product, powerset_nonempty

# ── Problem 1: Normal-form games ──────────────────────────────────────────
include("normal_form.jl")

# ── Problem 2: Extensive-form games ───────────────────────────────────────
include("extensive_form.jl")
include("subgames.jl")
include("solution.jl")

# ─── Exports ──────────────────────────────────────────────────────────────

# Normal form
export NormalFormGame
export MixedStrategy, MixedNashEquilibrium
export pure_nash_equilibria
export mixed_nash_equilibria_2player
export expected_payoff, eu_pure_vs_mixed
export print_pure_ne, print_mixed_ne

# Extensive form – structures
export NodeType, DECISION, TERMINAL, CHANCE
export GameNode, InformationSet, ExtensiveFormGame

# Extensive form – builder
export add_decision_node!, add_terminal_node!, add_chance_node!
export add_information_set!, link_nodes!

# Extensive form – traversal
export get_subtree_nodes, get_ancestors, terminal_nodes, decision_nodes

# Extensive form – subgames
export is_subgame_root, find_subgames, is_perfect_information
export subgame_info_sets, player_info_sets_in_subgame, active_info_sets
export print_subgames, print_game_tree

# Extensive form – solution
export PureExtensiveStrategy, SPNEResult
export backward_induction, find_spne, compute_payoffs
export subgame_to_normal_form, build_strategy_lists
export print_spne

end # module GameTheory
