# ============================================================
#  examples/entry_game.jl
#
#  Market Entry Game — Perfect Information Extensive Form
#
#  An Entrant (Player 1) decides to Enter or Stay Out.
#  If the Entrant enters, the Incumbent (Player 2) decides
#  whether to Fight or Accommodate.
#
# ============================================================

include(joinpath(@__DIR__, "..", "src", "GameTheory.jl"))
using .GameTheory

println("=" ^ 58)
println("  MARKET ENTRY GAME  (Perfect Information)")
println("=" ^ 58)

# ── Build the game tree ───────────────────────────────────────
game = ExtensiveFormGame(2;
    player_names = ["Entrant", "Incumbent"])

# Root: Entrant decides
root = add_decision_node!(game, 1, ["Stay Out", "Enter"])

# Terminal: Stay Out
t_out = add_terminal_node!(game, [0.0, 3.0];
            parent_id = root, parent_action = "Stay Out")

# Incumbent's node (reachable after "Enter")
inc = add_decision_node!(game, 2, ["Fight", "Accommodate"];
            parent_id = root, parent_action = "Enter")

# Terminal after Fight
t_fight = add_terminal_node!(game, [-1.0, -1.0];
              parent_id = inc, parent_action = "Fight")

# Terminal after Accommodate
t_acc = add_terminal_node!(game, [2.0, 2.0];
            parent_id = inc, parent_action = "Accommodate")

# Link children
link_nodes!(game, root, "Stay Out", t_out)
link_nodes!(game, root, "Enter",    inc)
link_nodes!(game, inc,  "Fight",       t_fight)
link_nodes!(game, inc,  "Accommodate", t_acc)

# Information sets (singleton = perfect information)
add_information_set!(game, 1, [root], ["Stay Out", "Enter"])
add_information_set!(game, 2, [inc],  ["Fight", "Accommodate"])

# ── Display ───────────────────────────────────────────────────
println(game)
println("\nGame tree:")
print_game_tree(game)

# ── Subgames ──────────────────────────────────────────────────
sg_roots = find_subgames(game)
print_subgames(game, sg_roots)

# ── SPNE ──────────────────────────────────────────────────────
result = find_spne(game)
print_spne(game, result)




