
"""

"""
function run_scc_mcs(model::model_choice; 
    trials = 10,
    perturbation_years = _default_perturbation_years,
    discount_rates = nothing, 
    ramsey = false,
    rhos = nothing,
    eta = nothing,
    domestic = false,
    horizon = _default_horizon,
    output_dir = nothing, 
    save_trials = false,
    tables = true)

    # Set up output directory for trials and saved values
    if output_dir == nothing
        output_dir = joinpath(dirname(@__FILE__), "../../output/", "$(string(model)) $(Dates.format(now(), "yyyy-mm-dd HH-MM-SS")) SCC $(ramsey ? "ramsey " : "")MC$trials")
    end

    if ramsey && (rhos == nothing || eta == nothing)
        error("Must provided values for rhos and eta for ramsey discounting")
    elseif ramsey && discount_rates != nothing 
        @warn("Ramsey discounting specified as true, will use rhos and eta instead of provided discount_rates.")
    elseif ramsey == false && discount_rates == nothing 
        discount_rates = _default_discount_rates
    end

    rates = ramsey ? rhos : discount_rates

    # Get specific simulation arguments for the provided model choice
    if model == DICE 
        mcs = get_dice_mcs()
        scenario_args = [:scenario => scenarios, :rate => rates]

        function dice_scenario_func(mcs::Simulation, tup::Tuple)
            (scenario_choice, rate) = tup
            global scenario_num = Int(scenario_choice)
            global rate_num = findfirst(isequal(rate), rates)
        
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
        
        scenario_func = dice_scenario_func
        post_trial_func = dice_post_trial_func

        last_idx = horizon - 2005 + 1
        !ramsey ? discount_factors = Dict([rate => [(1 + rate) ^ y for y in 0:last_idx-1] for rate in discount_rates]) : nothing    # precompute discount factors if not ramsey
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

            final = nyears

            if ramsey 
                globalypc = base[:socioeconomic, :globalypc]
                g = [globalypc[t]/globalypc[t-1] - 1 for t in 2:final]
            end
    
            # Loop through perturbation years for scc calculations, and only re-run the marinal model
            for (j, pyear) in enumerate(perturbation_years)
    
                MimiFUND.perturb_marginal_emissions!(marginal, pyear)
                run(marginal; ntimesteps=ntimesteps)
    
                damages2 = marginal[:impactaggregation, :loss] ./ marginal[:socioeconomic, :income] .* base[:socioeconomic, :income]
                marginaldamages = (damages2 .- damages1) / 10000000.
                global_marginaldamages = sum(marginaldamages, dims = 2)    # sum across regions
    
                function _get_scc(pyear, marginaldamages, rates)
                    scc = zeros(length(rates))
                    p_idx = MimiFUND.getindexfromyear(pyear)
                    
                    for (i, rate) in enumerate(rates)
                        if ramsey
                            scc[i] = scc_ramsey(marginaldamages[p_idx:final], rate, eta, g[p_idx-1:final-1])
                        else
                            discount_factor = [(1/(1 + rate)) ^ (t - p_idx) for t in p_idx:final]
                            scc[i] = sum(marginaldamages[p_idx:final] .* discount_factor) * 12.0 / 44.0
                        end
                    end
                    return scc 
                end
    
                scc_global = _get_scc(pyear, global_marginaldamages, rates)
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
        scenario_args = [:scenarios => scenarios, :discount_rates => rates]

        function page_scenario_func(mcs::Simulation, tup::Tuple)
            # Unpack the scenario arguments
            (scenario_choice, rate) = tup 
            global scenario_num = Int(scenario_choice)
            global rate_num = findfirst(isequal(rate), rates)
    
            # Build the page versions for this scenario
            base, marginal = mcs.models
            set_param!(base, :IWGScenarioChoice, :scenario_num, scenario_num)
            set_param!(marginal, :IWGScenarioChoice, :scenario_num, scenario_num)
            update_param!(base, :ptp_timepreference, rate*100)  # update the pure rate of time preference for this scenario's discount rate (`rate` will be the rho value if ramsey discounting)
            update_param!(marginal, :ptp_timepreference, rate*100)  # update the pure rate of time preference for this scenario's discount rate
    
            Mimi.build(base)
            Mimi.build(marginal)
        end 
        function page_post_trial_func(mcs::Simulation, trialnum::Int, ntimesteps::Int, tup::Tuple)
            # Unpack the scenario arguments
            (scenario_name, rate) = tup
    
            # Access the models
            base, marginal = mcs.models 

            # Get base impacts:
            # if ramsey
            #     domestic ? error("domestic SCC for ramsey discounting in PAGE not yet implemented") : nothing
            #     base_impacts = base[:EquityWeighting, :wit_equityweightedimpact]

            #     annual_years = page_years[1]:horizon

            #     glob_ypc = sum(base[:GDP, :gdp], dims=2) ./ sum(base[:GDP, :pop_population], dims=2)
            #     annual_glob_ypc = _interpolate(glob_ypc[:], page_years, annual_years)
            #     g = [annual_glob_ypc[t]/annual_glob_ypc[t-1] - 1 for t in 2:length(annual_glob_ypc)]
            #     base_impacts = base[:EquityWeighting, :widt_equityweightedimpact_discounted]
            # else
                DF = discount_factors[rate_num]
                td_base = base[:EquityWeighting, :td_totaldiscountedimpacts]
                if domestic 
                    td_base_domestic = sum(base[:EquityWeighting, :addt_equityweightedimpact_discountedaggregated][:, 2])  # US is the second region
                end
                EMUC = base[:EquityWeighting, :emuc_utilityconvexity]
                UDFT_base = DF .* (base[:EquityWeighting, :cons_percap_consumption][:, 1] / base[:EquityWeighting, :cons_percap_consumption_0][1]) .^ (-EMUC)    
            # end
    
            for (j, pyear) in enumerate(perturbation_years)
                idx = getpageindexfromyear(pyear)
    
                perturb_marginal_page_emissions!(base, marginal, pyear)
                run(marginal)

                # if ramsey
                #     # marg_impacts = marginal[:EquityWeighting, :widt_equityweightedimpact_discounted]
                #     # scc = sum(base_impacts .- marg_impacts) / 100000 * page_inflator
                #     annual_pidx = findfirst(isequal(pyear), annual_years)
                #     marg_impacts = marginal[:EquityWeighting, :wit_equityweightedimpact]
                #     global_md = dropdims(sum(base_impacts .- marg_impacts, dims=2), dims=2) ./ 100000 .* page_inflator
                #     annual_md = _interpolate(global_md, page_years, annual_years)
                #     scc = scc_ramsey(annual_md[annual_pidx:end], rate, eta, g[annual_pidx-1:end])
                # else
                    td_marginal = marginal[:EquityWeighting, :td_totaldiscountedimpacts] 
                    # UDFT_marginal = DF[idx] * (marginal[:EquityWeighting, :cons_percap_consumption][idx, 1] / base[:EquityWeighting, :cons_percap_consumption_0][idx]) ^ (-EMUC)
                    
                    # scc = ((td_marginal / UDFT_marginal) - (td_base / UDFT_base[idx])) / 100000 * page_inflator
                    scc = ((td_marginal / UDFT_base[idx]) - (td_base / UDFT_base[idx])) / 100000 * page_inflator
        
                    if domestic 
                        td_marginal_domestic = sum(marginal[:EquityWeighting, :addt_equityweightedimpact_discountedaggregated][:, 2])
                        scc_domestic = ((td_marginal_domestic / UDFT_marginal) - (td_base_domestic / UDFT_base[idx])) / 100000 * page_inflator
                        SCC_values_domestic[trialnum, j, scenario_num, rate_num] = scc_domestic
                    end
                # end
                SCC_values[trialnum, j, scenario_num, rate_num] = scc   
            end 
        end 

        scenario_func = page_scenario_func
        post_trial_func = page_post_trial_func

        # Precompute discount factors for each of the discount rates
        # !ramsey ? discount_factors = [[(1 / (1 + r)) ^ (Y - 2000) for Y in page_years] for r in rates] : nothing
        discount_factors = [[(1 / (1 + r)) ^ (Y - 2000) for Y in page_years] for r in rates]
        model_years = page_years
        nyears = length(page_years)

        # Set the base and marginal models
        base, marginal = get_marginal_page_models()
        if ramsey 
            update_param!(base, :emuc_utilityconvexity, eta)
            update_param!(marginal, :emuc_utilityconvexity, eta)
        end
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
    SCC_values = Array{Float64, 4}(undef, trials, length(perturbation_years), length(scenarios), length(rates))
    if domestic 
        model==DICE ? @warn("DICE is a global model. Domestic SCC values will be calculated as 10% of the global values.") : nothing
        SCC_values_domestic = Array{Float64, 4}(undef, trials, length(perturbation_years), length(scenarios), length(rates))
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
        new_SCC_values = Array{Float64, 4}(undef, trials, length(all_years), length(scenarios), length(rates))
        for i in 1:trials, j in 1:length(scenarios), k in 1:length(rates)
            new_SCC_values[i, :, j, k] = _interpolate(SCC_values[i, :, j, k], perturbation_years, all_years)
        end
        SCC_values = new_SCC_values

        if domestic 
            new_domestic_values = Array{Float64, 4}(undef, trials, length(all_years), length(scenarios), length(rates))
            for i in 1:trials, j in 1:length(scenarios), k in 1:length(rates)
                new_domestic_values[i, :, j, k] = _interpolate(SCC_values_domestic[i, :, j, k], perturbation_years, all_years)
            end
            SCC_values_domestic = new_domestic_values
        end

        perturbation_years = all_years
    end
    
    # Save the SCC values
    scc_dir = joinpath(output_dir, "SCC/")
    write_scc_values(SCC_values, scc_dir, perturbation_years, rates)
    if domestic 
        model == DICE ? SCC_values_domestic = SCC_values .* 0.1 : nothing   # domestic values for DICE calculated as 10% of global values
        write_scc_values(SCC_values_domestic, scc_dir, perturbation_years, rates, domestic=true)
    end

    # Build the stats tables
    if tables
        make_percentile_tables(output_dir, rates, perturbation_years)
        make_stderror_tables(output_dir, rates, perturbation_years)
        make_summary_table(output_dir, rates, perturbation_years)
    end

    nothing
end