# Example uses of available functions

using MimiIWG 
using Mimi

# 1. Get a model

# You must specifiy which model and which scenario:
#   choices of model are DICE, FUND, and PAGE
#   choices of scenario are USG1, USG2, USG3, USG4, and USG5

m = MimiIWG.get_model(DICE, USG2)
run(m)
explore(m)  # Opens a graphical user interface for exploring values calculated in the model's components

# 2. Get marginal damages vector from a pulse of emissions
md = MimiIWG.get_marginaldamages(FUND, USG3, gas=:CO2, year = 2020, discount = 0.)

# 3. Calculate a deterministic SCC value
scc = MimiIWG.compute_scc(PAGE, USG1, gas=:CO2, year = 2020, discount = 0.03)