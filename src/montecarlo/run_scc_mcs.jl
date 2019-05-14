
"""

"""
function run_scc_mcs(model::model_choice; 
    trials = 10,
    perturbation_years = _default_perturbation_years,
    discount_rates = _default_discount_rates, 
    domestic = false,
    horizon = _default_horizon,
    output_dir = nothing, 
    save_trials = false,
    tables = true)

    # Set up output directory for trials and saved values
    if output_dir == nothing
        output_dir = joinpath(dirname(@__FILE__), "../../output/", "$(string(model)) $(Dates.format(now(), "yyyy-mm-dd HH-MM-SS")) SCC MC$trials")
    end

    # Get specific simulation arguments for the provided model choice
    if model == DICE 
        mcs = get_dice_mcs()
        scenario_args = [:scenario => scenarios, :rate => discount_rates]

        function dice_scenario_func(mcs::Simulation, tup::Tuple)
            (scenario_choice, rate) = tup
            global scenario_num = Int(scenario_choice)
            global rate_num = findfirst(isequal(rate), discount_rates)
        
            base = get_dice_model(scenario_choice)
            marginal = Model(base)
            add_dice_marginal_emissions!(marginal)
        
            Mimi.build(base)
            Mimi.build(marginal)
        
            set_models!(mcs, [base, marginal]) 
        end
        function dice_post_trial_func(mcs::Simulation, trial::Int, ntimesteps::Int, tup::Tuple)
            (name, rate) = tup
            (base, marginal) = mcs.models

            base_consump = base[:neteconomy, :C]    # interpolate to annual timesteps for SCC calculation
            DF = discount_factors[rate]             # access the pre-computed discount factor for this rate

            for (idx, pyear) in enumerate(perturbation_years)

                # Call the marginal model with perturbations in each year
                perturb_dice_marginal_emissions!(marginal, pyear)
                run(marginal)

                marg_consump = marginal[:neteconomy, :C]
                md = (base_consump .- marg_consump)  * 10^3 * 12/44     # get marginal damages
                annual_md = _interpolate(md, dice_years, annual_years)  # get annual marginal damages

                first_idx = pyear - 2005 + 1
                scc = sum(annual_md[first_idx:last_idx] ./ DF[1:horizon - pyear + 1])

                SCC_values[trial, idx, scenario_num, rate_num] = scc 
            end
        end
        
        scenario_func = dice_scenario_func
        post_trial_func = dice_post_trial_func

        last_idx = horizon - 2005 + 1
        discount_factors = Dict([rate => [(1 + rate) ^ y for y in 0:last_idx-1] for rate in discount_rates])
        nyears = length(dice_years) # Run the full length to 2405, but nothing past 2300 gets used for the SCC
        annual_years = dice_years[1]:horizon
        model_years = dice_years

    elseif model == FUND 
        horizon != _default_horizon ? error("SCC calculations for horizons other than $_default_horizon not yet implemented for FUND") : nothing

        mcs = get_fund_mcs()
        scenario_args = [:scenarios => scenarios] 

        function fund_scenario_func(mcs::Simulation, tup::Tuple)
            # Access the models
            base, marginal = mcs.models 
    
            # Unpack the scenario tuple
            (scenario_choice,) = tup
            global scenario_num = Int(scenario_choice)
    
            # Apply the scenario data to the base and marginal models
            apply_fund_scenario!(base, scenario_choice)
            apply_fund_scenario!(marginal, scenario_choice)
    
            Mimi.build(base)
            Mimi.build(marginal)
        end
        function fund_post_trial_func(mcs::Simulation, trialnum::Int, ntimesteps::Int, tup::Tuple)
            # Access the models
            base, marginal = mcs.models 
            damages1 = base[:impactaggregation, :loss]
    
            # Loop through perturbation years for scc calculations, and only re-run the marinal model
            for (j, pyear) in enumerate(perturbation_years)
    
                MimiFUND.perturb_marginal_emissions!(marginal, pyear)
                run(marginal; ntimesteps=ntimesteps)
    
                damages2 = marginal[:impactaggregation, :loss] ./ marginal[:socioeconomic, :income] .* base[:socioeconomic, :income]
                marginaldamages = (damages2 .- damages1) / 10000000.
                global_marginaldamages = sum(marginaldamages, dims = 2)    # sum across regions
    
                function _get_scc(pyear, marginaldamages, discount_rates)
                    scc = zeros(length(discount_rates))
                    p_idx = MimiFUND.getindexfromyear(pyear)
                    final = nyears
                    
                    for (i, rate) in enumerate(discount_rates)
                        discount_factor = [(1/(1 + rate)) ^ (t - p_idx) for t in p_idx:final]
                        scc[i] = sum(marginaldamages[p_idx:final] .* discount_factor) * 12.0 / 44.0
                    end
                    return scc 
                end
    
                scc_global = _get_scc(pyear, global_marginaldamages, discount_rates)
                SCC_values[trialnum, j, scenario_num, :] = scc_global * fund_inflator
    
                if domestic
                    domestic_marginaldamages = marginaldamages[:, 1]
                    scc_domestic = _get_scc(pyear, domestic_marginaldamages, discount_rates)
                    SCC_values_domestic[trialnum, j, scenario_num, :] = scc_domestic * fund_inflator
                end
            end
        end

        scenario_func = fund_scenario_func
        post_trial_func = fund_post_trial_func

        # Get base and marginal models
        base = get_fund_model()
        marginal = get_fund_model()
        MimiFUND.add_marginal_emissions!(marginal)   # adds the marginal emissions component, doesn't set the emission pulse till within MCS

        # Set the base and marginal models
        set_models!(mcs, [base, marginal])

        nyears = length(fund_years)
        model_years = fund_years

    elseif model == PAGE 
        horizon != _default_horizon ? error("SCC calculations for horizons other than $_default_horizon not yet implemented for PAGE") : nothing

        mcs = get_page_mcs()
        scenario_args = [:scenarios => scenarios, :discount_rates => discount_rates]

        function page_scenario_func(mcs::Simulation, tup::Tuple)
            # Unpack the scenario arguments
            (scenario_choice, rate) = tup 
            global scenario_num = Int(scenario_choice)
            global rate_num = findfirst(isequal(rate), discount_rates)
    
            # Build the page versions for this scenario
            base, marginal = mcs.models
            set_param!(base, :IWGScenarioChoice, :scenario_num, scenario_num)
            set_param!(marginal, :IWGScenarioChoice, :scenario_num, scenario_num)
            update_param!(base, :ptp_timepreference, rate*100)  # update the pure rate of time preference for this scenario's discount rate
            update_param!(marginal, :ptp_timepreference, rate*100)  # update the pure rate of time preference for this scenario's discount rate
    
            Mimi.build(base)
            Mimi.build(marginal)
        end 
        function page_post_trial_func(mcs::Simulation, trialnum::Int, ntimesteps::Int, tup::Tuple)
            # Unpack the scenario arguments
            (scenario_name, rate) = tup
            DF = discount_factors[rate_num]
    
            # Access the models
            base, marginal = mcs.models 
            
            # Get base impacts:
            td_base = base[:EquityWeighting, :td_totaldiscountedimpacts]
            if domestic 
                td_base_domestic = sum(base[:EquityWeighting, :addt_equityweightedimpact_discountedaggregated][:, 2])  # US is the second region
            end
    
            EMUC = base[:EquityWeighting, :emuc_utilityconvexity]
            UDFT_base = DF .* (base[:EquityWeighting, :cons_percap_consumption][:, 1] / base[:EquityWeighting, :cons_percap_consumption_0][1]) .^ (-EMUC)
    
            for pyear in perturbation_years 
                idx = getpageindexfromyear(pyear)
    
                perturb_marginal_page_emissions!(base, marginal, pyear)
                run(marginal)
                td_marginal = marginal[:EquityWeighting, :td_totaldiscountedimpacts] 
                UDFT_marginal = DF[idx] * (marginal[:EquityWeighting, :cons_percap_consumption][idx, 1] / base[:EquityWeighting, :cons_percap_consumption_0][idx]) ^ (-EMUC)
                
                scc = ((td_marginal / UDFT_marginal) - (td_base / UDFT_base[idx])) / 100000 * page_inflator
                j = findfirst(isequal(pyear), perturbation_years)
                SCC_values[trialnum, j, scenario_num, rate_num] = scc   
    
                if domestic 
                    td_marginal_domestic = sum(marginal[:EquityWeighting, :addt_equityweightedimpact_discountedaggregated][:, 2])
                    scc_domestic = ((td_marginal_domestic / UDFT_marginal) - (td_base_domestic / UDFT_base[idx])) / 100000 * page_inflator
                    SCC_values_domestic[trialnum, j, scenario_num, rate_num] = scc_domestic
                end
            end 
        end 

        scenario_func = page_scenario_func
        post_trial_func = page_post_trial_func

        # Precompute discount factors for each of the discount rates
        discount_factors = [[(1 / (1 + r)) ^ (Y - 2000) for Y in page_years] for r in discount_rates]
        model_years = page_years
        nyears = length(page_years)

        # Set the base and marginal models
        base, marginal = get_marginal_page_models()
        set_models!(mcs, [base, marginal])
    end

    # Check that the perturbation years are valid before running the simulation
    if minimum(perturbation_years) < minimum(model_years) || maximum(perturbation_years) > maximum(model_years)
        error("The specified perturbation years fall outside of the model's time index.")
    end

    # Check if any desired perturbation years need to be interpolated (aren't in the time index)
    _need_to_interpolate = ! all(y -> y in model_years, perturbation_years)
    if _need_to_interpolate
        all_years = copy(perturbation_years)    # preserve a copy of the original desired SCC years
        _first_idx = findlast(y -> y <= minimum(all_years), model_years)
        _last_idx = findfirst(y -> y >= maximum(all_years), model_years)
        perturbation_years = model_years[_first_idx : _last_idx]  # figure out which years of the model's time index we need to use to cover all desired perturbation years
    end

    # Make an array to hold all calculated scc values
    SCC_values = Array{Float64, 4}(undef, trials, length(perturbation_years), length(scenarios), length(discount_rates))
    if domestic 
        model==DICE ? @warn("DICE is a global model. Domestic SCC values will be calculated as 10% of the global values.") : nothing
        SCC_values_domestic = Array{Float64, 4}(undef, trials, length(perturbation_years), length(scenarios), length(discount_rates))
    end

    # Generate trials 
    fn = save_trials ? joinpath(output_dir, "trials.csv") : nothing 
    generate_trials!(mcs, trials; filename = fn)

    # Run the simulation
    run_sim(mcs; 
        trials = trials, 
        models_to_run = 1,      # Run only the base model automatically in the MCS; we run the marginal model "manually" in a loop over all perturbation years in the post_trial function.
        ntimesteps = nyears,    
        scenario_func = scenario_func, 
        scenario_args = scenario_args,
        post_trial_func = post_trial_func,
        output_dir = joinpath(output_dir, "saved_variables")
    )

    # generic interpolation if user requested SCC values for years in between model_years
    if _need_to_interpolate
        new_SCC_values = Array{Float64, 4}(undef, trials, length(all_years), length(scenarios), length(discount_rates))
        for i in 1:trials, j in 1:length(scenarios), k in 1:length(discount_rates)
            new_SCC_values[i, :, j, k] = _interpolate(SCC_values[i, :, j, k], perturbation_years, all_years)
        end
        SCC_values = new_SCC_values

        if domestic 
            new_domestic_values = Array{Float64, 4}(undef, trials, length(all_years), length(scenarios), length(discount_rates))
            for i in 1:trials, j in 1:length(scenarios), k in 1:length(discount_rates)
                new_domestic_values[i, :, j, k] = _interpolate(SCC_values_domestic[i, :, j, k], perturbation_years, all_years)
            end
            SCC_values_domestic = new_domestic_values
        end

        perturbation_years = all_years
    end
    
    # Save the SCC values
    scc_dir = joinpath(output_dir, "SCC/")
    write_scc_values(SCC_values, scc_dir, perturbation_years, discount_rates)
    if domestic 
        model == DICE ? SCC_values_domestic = SCC_values .* 0.1 : nothing   # domestic values for DICE calculated as 10% of global values
        write_scc_values(SCC_values_domestic, scc_dir, perturbation_years, discount_rates, domestic=true)
    end

    # Build the stats tables
    if tables
        make_percentile_tables(output_dir, discount_rates, perturbation_years)
        make_stderror_tables(output_dir, discount_rates, perturbation_years)
        make_summary_table(output_dir, discount_rates, perturbation_years)
    end

    nothing
end