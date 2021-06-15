
_dice_simdef = @defsim begin
    # Use the Roe and Baker distribution defined in a file, read in in src/core/constants.jl
    climatedynamics.t2xco2 = EmpiricalDistribution(RB_cs_values, RB_cs_probs)
    # save(climatedynamics.t2xco2)
end 

"""
    Returns a Monte Carlo Simulation object with one random variable for climate sensitivity over the 
    Roe Baker distrtibution used by the IWG for DICE.
"""
function get_dice_mcs()
    return deepcopy(_dice_simdef) 
end

function dice_scenario_func(mcs::SimulationInstance, tup::Tuple)
    (scenario_choice, rate) = tup
    global scenario_num = Int(scenario_choice)
    global rate_num = findfirst(isequal(rate), Mimi.payload(mcs)[1])

    base, marginal = mcs.models
    update_param!(base, :scenario_num, scenario_num)
    update_param!(marginal, :scenario_num, scenario_num)

    Mimi.build!(base)
    Mimi.build!(marginal)
end

function dice_post_trial_func(mcs::SimulationInstance, trial::Int, ntimesteps::Int, tup::Tuple)
    (name, rate) = tup
    (base, marginal) = mcs.models

    rates, discount_factors, model_years, horizon, gas, perturbation_years, SCC_values, SCC_values_domestic, md_values = Mimi.payload(mcs)

    last_idx = horizon - 2005 + 1
    annual_years = dice_years[1]:horizon

    base_consump = base[:neteconomy, :C] 

    DF = discount_factors[rate]             # access the pre-computed discount factor for this rate

    for (idx, pyear) in enumerate(perturbation_years)

        # Call the marginal model with perturbations in each year
        perturb_dice_marginal_emissions!(marginal, gas, pyear)
        run(marginal)

        marg_consump = marginal[:neteconomy, :C]
        md = (base_consump .- marg_consump)  * _dice_normalization_factor(gas)     # get marginal damages
        annual_md = _interpolate(md, dice_years, annual_years)  # get annual marginal damages

        first_idx = pyear - 2005 + 1

        scc = sum(annual_md[first_idx:last_idx] ./ DF[1:horizon - pyear + 1])

        SCC_values[trial, idx, scenario_num, rate_num] = scc 
        if md_values !== nothing
            md_values[idx, scenario_num, :, trial] = md
        end
    end
end
