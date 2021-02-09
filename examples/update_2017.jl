# Run the IWG SCC Monte Carlo simulations using the 2017 updated specifications
# The update included two changes:
#   1. Only include domestic damages in the SCC estimates
#   2. Use discount rates of 3% and 7%

using MimiIWG

N = 10_000
updated_rates = [0.03, 0.07]

MimiIWG.run_scc_mcs(DICE, gas=:CO2, trials=N, domestic=true, discount_rates=updated_rates)
MimiIWG.run_scc_mcs(FUND, gas=:CO2, trials=N, domestic=true, discount_rates=updated_rates)
MimiIWG.run_scc_mcs(PAGE, gas=:CO2, trials=N, domestic=true, discount_rates=updated_rates)