
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
    (scenario_choice, ) = tup
    global scenario_num = Int(scenario_choice)

    base, marginal = mcs.models
    update_param!(base, :scenario_num, scenario_num)
    update_param!(marginal, :scenario_num, scenario_num)

    Mimi.build!(base)
    Mimi.build!(marginal)
end

function dice_post_trial_func(mcs::SimulationInstance, trial::Int, ntimesteps::Int, tup::Tuple)
    
    #access the models
    (base, marginal) = mcs.models

    # unpack payload object
    prtp_rates, eta_levels, model_years, equity_weighting, normalization_region, horizon, gas, perturbation_years, SCC_values, SCC_values_domestic, md_values = Mimi.payload(mcs)

    # get needed values to calculate the scc that will not vary with perturbation year
    annual_years = dice_years[1]:horizon
    consumption = base[:neteconomy, :C] # Consumption (trillions 2005 US dollars per year)
    annual_consumption = reduce(vcat, map(x -> fill(x, 10), consumption))
    pop = base[:neteconomy, :l] ./ 1000 # Level of population and labor (originally in millions, convert to billions)
    annual_pop = reduce(vcat, map(x -> fill(x, 10), pop))

    for (i, pyear) in enumerate(perturbation_years)

        # Call the marginal model with perturbations in each year
        perturb_dice_marginal_emissions!(marginal, gas, pyear)
        run(marginal)

        marg_consump = marginal[:neteconomy, :C]
        md = (base_consump .- marg_consump)  * _dice_normalization_factor(gas)     # get marginal damages
        annual_md = _interpolate(md, dice_years, annual_years)  # get annual marginal damages

        # save marginal damages
        if md_values !== nothing
            md_values[i, scenario_num, :, trial] = md
        end

        p_idx = findfirst(isequal(year), annual_years)
        for (j, _prtp) in enumerate(prtp_rates), (k, _eta) in enumerate(eta_levels)
            scc = get_discrete_scc(annual_md[p_idx:end], 
                                _prtp, 
                                _eta, 
                                annual_consumption[p_idx:length(annual_md)], 
                                annual_pop[p_idx:length(annual_md)], 
                                collect(annual_years[p_idx:end]), 
                                equity_weighting = equity_weighting, 
                                normalization_region = normalization_region
                            )
        
            SCC_values[trial, i, scenario_num, j, k] = scc
        end
    end
end
