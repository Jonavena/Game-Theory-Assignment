# ============================================================
#  examples/battle_of_sexes.jl
#
#  Battle of the Sexes — 2 pure NE and 1 strictly-mixed NE.
#
#  Two players coordinate on an evening event.
#  Player 1 prefers Opera; Player 2 prefers Football.
#  Both prefer being together to being apart.
#
#  Payoff matrix:
#             Opera   Football
#  Opera    [ (2,1)    (0,0)  ]
#  Football [ (0,0)    (1,2)  ]
#

# ============================================================

include(joinpath(@__DIR__, "..", "src", "GameTheory.jl"))
using .GameTheory

println("=" ^ 58)
println("  BATTLE OF THE SEXES")
println("=" ^ 58)

P1 = Float64[2 0;
              0 1]

P2 = Float64[1 0;
              0 2]

game = NormalFormGame(
    Array{Float64}[P1, P2];
    player_names   = ["Alice (Opera ♥)", "Bob (Football ♥)"],
    strategy_names = [["Opera", "Football"],
                      ["Opera", "Football"]])

println(game)

println("\nPayoff matrix (Alice, Bob):")
println("              Opera     Football")
for (i, s1) in enumerate(["Opera", "Football"])
    row = "  $(rpad(s1,10))"
    for j in 1:2
        p1v = Int(game.payoffs[1][i,j])
        p2v = Int(game.payoffs[2][i,j])
        row *= "  ($p1v,$p2v)     "
    end
    println(row)
end

pure  = pure_nash_equilibria(game)
mixed = mixed_nash_equilibria_2player(game)

print_pure_ne(game, pure)
print_mixed_ne(game, mixed)

println()
println("Analysis:")
println("  2 pure-strategy NE: both go to Opera, or both go to Football.")
println("  1 mixed-strategy NE: Alice randomises 2/3 Opera, Bob randomises 1/3 Opera.")
println("  The mixed NE has a lower expected payoff than either pure NE — a coordination trap.")
