using MimiIWG
using Random

N = 10000
seed = 350

Random.seed!(seed)
MimiIWG.run_scc_mcs(DICE, trials = N)

Random.seed!(seed)
MimiIWG.run_scc_mcs(FUND, trials = N)

Random.seed!(seed)
MimiIWG.run_scc_mcs(PAGE, trials = N)