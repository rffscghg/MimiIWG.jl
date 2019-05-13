include("../src/MimiIWG2016.jl")

N = 10000

run_scc_mcs(DICE, trials=N)
run_scc_mcs(FUND, trials=N)
run_scc_mcs(PAGE, trials=N)
