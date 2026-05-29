# ============================================================
#  examples/prisoners_dilemma.jl
#
#  Classic 2-player Prisoner's Dilemma.
#
#  Payoff matrix (row = Player 1, col = Player 2):
#
#              Cooperate   Defect
#  Cooperate  [ (3,3)      (0,5) ]
#  Defect     [ (5,0)      (1,1) ]
#
# ============================================================

include(joinpath(@__DIR__, "..", "src", "GameTheory.jl"))
using .GameTheory

println("=" ^ 58)
println("  PRISONER'S DILEMMA")
println("=" ^ 58)

# ── Build payoff arrays ───────────────────────────────────────
# Dimensions: [P1_strategy, P2_strategy]
P1 = Float64[3 0;
              5 1]

P2 = Float64[3 5;
              0 1]

game = NormalFormGame(
    Array{Float64}[P1, P2];
    player_names   = ["Player 1", "Player 2"],
    strategy_names = [["Cooperate", "Defect"],
                      ["Cooperate", "Defect"]])

println(game)

# ── Print payoff matrix ───────────────────────────────────────
println("\nPayoff matrix (P1 payoff, P2 payoff):")
println("            Cooperate   Defect")
for (i, s1) in enumerate(["Cooperate", "Defect"])
    row = ["  $s1"]
    for j in 1:2
        p1v = Int(game.payoffs[1][i, j])
        p2v = Int(game.payoffs[2][i, j])
        push!(row, "($p1v,$p2v)    ")
    end
    println(join(row, "     "))
end

# ── Pure NE ──────────────────────────────────────────────────
pure = pure_nash_equilibria(game)
print_pure_ne(game, pure)

# ── Mixed NE ─────────────────────────────────────────────────
mixed = mixed_nash_equilibria_2player(game)
print_mixed_ne(game, mixed)
