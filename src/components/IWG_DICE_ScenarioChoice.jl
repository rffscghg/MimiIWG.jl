# This component holds data for all IWG scenarios for DICE in its parameters, and the `scenario_num` parameter specifies which scenario to use.
# During the first timestep, values for the specified scenario are copied into the variables.
# Functions for loading in the necessaring parameters are defined in src/core/DICE_helper.jl
@defcomp IWG_DICE_ScenarioChoice begin

    scenarios = Index()

    # Variables (each one has its value set for the chosen scenario in the first timestep)
    l       = Variable(index = [time])  # Population
    E       = Variable(index = [time])  # Total CO2 emissions
    forcoth = Variable(index = [time])  # other forcing
    al      = Variable(index = [time])  # total factor productivity
    k0      = Variable()                # initial capital stock

    # The number for which scenario to use 
    scenario_num::Integer = Parameter(default = 0)

    # Parameters (each one holds all five scenarios)
    l_all       = Parameter(index = [time, scenarios])
    E_all       = Parameter(index = [time, scenarios])
    forcoth_all = Parameter(index = [time, scenarios])
    al_all      = Parameter(index = [time, scenarios])
    k0_all      = Parameter(index = [scenarios])

    function run_timestep(p, v, d, t)
        if is_first(t)
            # Get the specified scenario
            scenario_num = p.scenario_num
            if scenario_num == 0
                # @warn("scenario_num was not set in the IWG_DICE_ScenarioChoice component. Will use average values of all five scenarios.")
                v.l[:]          = dropdims(mean(p.l_all[:, :], dims=2), dims=2)
                v.E[:]          = dropdims(mean(p.E_all[:, :], dims=2), dims=2)
                v.forcoth[:]    = dropdims(mean(p.forcoth_all[:, :], dims=2), dims=2)
                v.al[:]         = dropdims(mean(p.al_all[:, :], dims=2), dims=2)
                v.k0            = mean(p.k0_all[:])
            else
                # Copy over all of the values for that scenario
                v.l[:]          = p.l_all[:, scenario_num]
                v.E[:]          = p.E_all[:, scenario_num]
                v.forcoth[:]    = p.forcoth_all[:, scenario_num]
                v.al[:]         = p.al_all[:, scenario_num]
                v.k0            = p.k0_all[scenario_num]
            end
        end
    end
end
