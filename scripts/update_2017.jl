include("../src/MimiIWG.jl")
using .MimiIWG

N = 10000
updated_rates = [0.03, 0.07]

run_scc_mcs(DICE, trials=N, domestic=true, discount_rates=updated_rates)
run_scc_mcs(FUND, trials=N, domestic=true, discount_rates=updated_rates)
run_scc_mcs(PAGE, trials=N, domestic=true, discount_rates=updated_rates)
