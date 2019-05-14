
"""
    Returns a MonteCarloSimulation object with one random variable for climate sensitivity over the Roe Baker distrtibution used by the IWG for DICE.
"""
function get_dice_mcs()
    mcs = @defsim begin
        t2xco2 = EmpiricalDistribution(RB_cs_values, RB_cs_probs)   # Use the Roe and Baker distribution defined in a file, read in in src/core/constatns.jl

        # save(climatedynamics.t2xco2)
    end 
    return mcs 
end

# function dice_scenario_func(mcs::Simulation, tup::Tuple)
#     (scenario_choice, rate) = tup
#     global scenario_num = Int(scenario_choice)
#     global rate_num = findfirst(isequal(rate), discount_rates)

#     base = get_dice_model(scenario_choice)
#     marginal = Model(base)
#     add_dice_marginal_emissions!(marginal)

#     Mimi.build(base)
#     Mimi.build(marginal)

#     set_models!(mcs, [base, marginal]) 
# end

# function dice_post_trial_func(mcs::Simulation, trial::Int, ntimesteps::Int, tup::Tuple)
#     (name, rate) = tup
#     (base, marginal) = mcs.models

#     base_consump = base[:neteconomy, :C]    # interpolate to annual timesteps for SCC calculation
#     DF = discount_factors[rate]             # access the pre-computed discount factor for this rate

#     for (idx, pyear) in enumerate(perturbation_years)

#         # Call the marginal model with perturbations in each year
#         perturb_dice_marginal_emissions!(marginal, pyear)
#         run(marginal)

#         marg_consump = marginal[:neteconomy, :C]
#         md = (base_consump .- marg_consump)  * 10^3 * 12/44     # get marginal damages
#         annual_md = _interpolate(md, dice_years, annual_years)  # get annual marginal damages

#         first_idx = pyear - 2005 + 1
#         scc = sum(annual_md[first_idx:last_idx] ./ DF[1:horizon - pyear + 1])

#         SCC_values[trial, idx, scenario_num, rate_num] = scc 
#     end

# end
