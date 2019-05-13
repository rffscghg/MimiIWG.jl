include("../src/MimiIWG.jl")
using .MimiIWG

N = 10000

run_scc_mcs(DICE, trials=N)
run_scc_mcs(FUND, trials=N)
run_scc_mcs(PAGE, trials=N)
