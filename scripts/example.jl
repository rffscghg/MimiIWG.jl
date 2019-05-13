include("../src/MimiIWG.jl")
using .MimiIWG

# Get a model
m = get_model(DICE, USG2)
run(m)
explore(m)

# View a marginal damages vecotr from a pulse of emissions
md = get_marginaldamages(FUND, USG3, year=2020, discount=0.025)

# Calculate a determinisitc SCC value
scc = get_scc(PAGE, USG1, year=2020, discount=0.03)