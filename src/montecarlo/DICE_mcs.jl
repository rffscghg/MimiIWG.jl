
"""
    Returns a Monte Carlo Simulation object with one random variable for climate sensitivity over the Roe Baker distrtibution used by the IWG for DICE.
"""
function get_dice_mcs()
    mcs = @defsim begin
        t2xco2 = EmpiricalDistribution(RB_cs_values, RB_cs_probs)   # Use the Roe and Baker distribution defined in a file, read in in src/core/constatns.jl

        # save(climatedynamics.t2xco2)
    end 
    return mcs 
end

function dice_scenario_func(mcs::Simulation, tup::Tuple)
    (scenario_choice, rate) = tup
    global scenario_num = Int(scenario_choice)
    global rate_num = findfirst(isequal(rate), Mimi.payload(mcs)[1])

    base, marginal = mcs.models
    set_param!(base, :IWGScenarioChoice, :scenario_num, scenario_num)
    set_param!(marginal, :IWGScenarioChoice, :scenario_num, scenario_num)

    Mimi.build(base)
    Mimi.build(marginal)
end

function dice_post_trial_func(mcs::Simulation, trial::Int, ntimesteps::Int, tup::Tuple)
    (name, rate) = tup
    (base, marginal) = mcs.models

    rates, discount_factors, ramsey, model_years, horizon, perturbation_years, SCC_values, SCC_values_domestic = Mimi.payload(mcs)

    last_idx = horizon - 2005 + 1
    annual_years = dice_years[1]:horizon

    base_consump = base[:neteconomy, :C]    # interpolate to annual timesteps for SCC calculation

    if ramsey
        glob_ypc = base[:neteconomy, :YGROSS] ./ base[:neteconomy, :l]
        annual_glob_ypc = _interpolate(glob_ypc[1:30], model_years[1:30], annual_years)
        g = [annual_glob_ypc[t]/annual_glob_ypc[t-1] - 1 for t in 2:length(annual_glob_ypc)]
    else
        DF = discount_factors[rate]             # access the pre-computed discount factor for this rate
    end

    for (idx, pyear) in enumerate(perturbation_years)

        # Call the marginal model with perturbations in each year
        perturb_dice_marginal_emissions!(marginal, pyear)
        run(marginal)

        marg_consump = marginal[:neteconomy, :C]
        md = (base_consump .- marg_consump)  * 10^3 * 12/44     # get marginal damages
        annual_md = _interpolate(md, dice_years, annual_years)  # get annual marginal damages

        first_idx = pyear - 2005 + 1

        if ramsey 
            scc = scc_ramsey(annual_md[first_idx:end], rate, eta, g[first_idx-1:end])
        else
            scc = sum(annual_md[first_idx:last_idx] ./ DF[1:horizon - pyear + 1])
        end

        SCC_values[trial, idx, scenario_num, rate_num] = scc 
    end
end
