using MimiIWG

# Deterministic SC-CH4 and SC-N2O
MimiIWG.compute_scc(DICE, USG1, gas=:CH4, year=2020, discount=0.025)
MimiIWG.compute_scc(DICE, USG1, gas=:CO2, year=2005, discount=0.025)

# Monte Carlo runs (will run for all 3 IWG discount rates if none are specified)
MimiIWG.run_scc_mcs(DICE, gas=:CH4, trials=10000, perturbation_years=[2020], output_dir = "output")
MimiIWG.run_scc_mcs(DICE, gas=:N2O, trials=10000, perturbation_years=[2020], output_dir = "output")