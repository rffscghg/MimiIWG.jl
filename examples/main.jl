# Runs Monte Carlo simulations for calculating the SC-CO2 using each of the three models across all 5 socioeconomic scenarios,
# and for the default set of discount rates (2.5%, 3%, and 5%) and perturbation years (2010, 2020, 2030, 2040, and 2050).
# Sets a random seed before each simulation so that results can be replicated.

using MimiIWG
using Random

N = 10000
seed = 350

Random.seed!(seed)
MimiIWG.run_scc_mcs(DICE, gas=:CO2, trials = N)

Random.seed!(seed)
MimiIWG.run_scc_mcs(FUND, gas=:CO2, trials = N)

Random.seed!(seed)
MimiIWG.run_scc_mcs(PAGE, gas=:CO2, trials = N)
