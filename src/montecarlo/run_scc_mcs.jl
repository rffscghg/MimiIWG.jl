"""
    run_scc_mcs(model::model_choice; 
                gas::Union{Symbol, Nothing} = nothing,
                trials::Int = 10000,
                perturbation_years::Vector{Int} = _default_perturbation_years,
                discount_rates::Union{Vector{Float64}, Nothing} = nothing, 
                prtp_rates::Union{Vector{Float64}, Nothing} = nothing, 
                eta_levels::Union{Vector{Float64}, Nothing} = nothing, 
                domestic::Bool = false,
                equity_weighting::Bool = false,
                normalization_region::Union{Int, Nothing} = nothing,
                output_dir::Union{String, Nothing} = nothing, 
                save_trials::Bool = false,
                tables::Bool = true,
                drop_discontinuities::Bool = false,
                save_md::Bool = false)

Run the Monte Carlo simulation used by the IWG for calculating a distribution of SCC values for the 
Mimi model `model_choice` and the specified number of trials `trials`. The SCC is calculated for all 
5 socioeconomic scenarios, and for all specified `perturbation_years` and discount_rates specified by
all permutations of `prtp_rates` and `eta_levels`. 

- `gas` may be one of :CO2, :CH4, or :N2O. If none is specified, it will default to :CO2.
- `model` must be one of the following enums: DICE, FUND, or PAGE.

Output files will be saved in the `output_dir`. If none is provided, it will default to "./output/". 
A new sub directory will be created each time this function is called, with the following name: "yyyy-mm-dd HH-MM-SS MODEL SC-\$gas MC\$trials".

Several keyword arguments allow for the following:

- If `domestic` equals `true`, then SCC values will also be calculated using only domestic damages. 
- If `equity_weighting` is true, equity weighting is used discounting, and if 
`normalization_region` is not nothing, that region is used for the equity weighting 
normalization region.
- If `tables` equals `true`, then a set of summary statistics tables will also be saved in the output folder.
- If `save_trials` equals `true`, then a file with all of the sampled input trial data will also be saved in the output folder. 
- If `drop_discontinuities` equals `true`, then outliers from the PAGE model (runs where discontinuity damages are triggered
in different timesteps in the base and perturbed models) will not contribute to summary statistics. An additional folder
"discontinuity_mismatch" contains files identifying in which runs the discrepencies occured.
- If `save_md` equals `true`, then global undiscounted marginal damages from each run of 
the simulation will be saved in a subdirectory "output/marginal_damages".
"""
function run_scc_mcs(model::model_choice; 
    gas::Union{Symbol, Nothing} = nothing,
    trials::Int = 10000,
    perturbation_years::Vector{Int} = _default_perturbation_years,
    discount_rates::Union{Vector{Float64}, Nothing} = nothing, 
    prtp_rates::Union{Vector{Float64}, Nothing} = nothing, 
    eta_levels::Union{Vector{Float64}, Nothing} = nothing, 
    domestic::Bool = false,
    equity_weighting::Bool = false,
    normalization_region::Union{Int, Nothing} = nothing,
    output_dir::Union{String, Nothing} = nothing, 
    save_trials::Bool = false,
    tables::Bool = true,
    drop_discontinuities::Bool = false,
    save_md::Bool = false)

    # check equity weighting cases, the only options are (1) only domestic (2) only 
    # equity weighting (3) equity weighting with a normalizationr egion
    if equity_weighting && domestic
        error("Cannot set both domestic and equity weighting to true at the same time for SCC computation")
    elseif !(equity_weighting) && !isnothing(normalization_region)
        error("Cannot set a normalization region if equity weighting is false for SCC computation.")
    end

    # check discounting parameters
    if !isnothing(discount_rates)
        @warn "The `discount_rates` keyword is deprecated. Use `prtp_rates` keyword 
        for constant discounting instead. Now returning the results of calling 
        `run_scc_cs` with `prtp_rates = $discount_rates`, and `eta_levels = [0.]` 
        by default."
        prtp_rates = discount_rates
    end
    if isnothing(prtp_rates)
        @warn("No `prtp_rates` provided. Will run with the following rates: $_default_discount_rates.")
        prtp_rates = _default_discount_rates
    end
    if isnothing(eta_levels)
        @warn("No values provided for `eta_levels`. Will run with eta = 0.")
        eta_levels = [0.]
    end

    # Check the gas
    if gas === nothing
        @warn("No `gas` specified in `run_scc_mcs`; will return the SC-CO2.")
        gas = :CO2
    elseif ! (gas in [:CO2, :CH4, :N2O])
        error("Unknown gas :$gas. Available gases are :CO2, :CH4, and :N2O.")
    end

    # Set up output directory for trials and saved values
    root_dir = (output_dir === nothing ? "output/" : output_dir)
    output_dir = joinpath(root_dir, "$(Dates.format(now(), "yyyy-mm-dd HH-MM-SS")) $(string(model)) SC-$gas MC$trials")

    # Get specific simulation arguments for the provided model choice
    if model == DICE 
        mcs = get_dice_mcs()

        nyears = length(dice_years) # Run the full length to 2405, but nothing past 2300 gets used for the SCC
        model_years = dice_years

        payload = Any[prtp_rates, eta_levels, model_years, equity_weighting, normalization_region, _default_horizon]
        
        scenario_func = dice_scenario_func
        post_trial_func = dice_post_trial_func

        base = get_dice_model(USG1) # Need to set a scenario so the model can be built, but the scenarios will change in the simulation
        marginal = get_dice_model(USG1)
        add_dice_marginal_emissions!(marginal, gas)  # adds the marginal emissions component, but with no year specified, no pulse is added yet
        models = [base, marginal]

        domestic ? @warn("DICE is a global model. Domestic SCC values will be calculated as 10% of the global values.") : nothing
        equity_weighting ? @warn("DICE is a global model. Equity weighting will have no effect on SCC values.") : nothing

    elseif model == FUND 

        mcs = get_fund_mcs()
        
        nyears = length(fund_years)
        model_years = fund_years

        payload = Any[prtp_rates, eta_levels, model_years, equity_weighting, normalization_region]

        scenario_func = fund_scenario_func
        post_trial_func = fund_post_trial_func

        # Get base and marginal models
        base = get_fund_model(USG1) # Need to set a scenario so the model can be built, but the scenarios will change in the simulation
        marginal = get_fund_model(USG1)
        add_fund_marginal_emissions!(marginal, gas=gas)   # adds the marginal emissions component, doesn't set the emission pulse till within MCS
        models = [base, marginal]

    elseif model == PAGE 

        mcs = get_page_mcs()

        model_years = page_years
        nyears = length(page_years)

        payload = Any[prtp_rates, eta_levels, model_years, equity_weighting, normalization_region]

        scenario_func = page_scenario_func
        post_trial_func = page_post_trial_func

        # Set the base and marginal models
        base, marginal = get_marginal_page_models(scenario_choice = USG1, gas = gas) # Need to set a scenario so the model can be built, but the scenarios will change in the simulation
        models = [base, marginal]
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

    # For each run, this array will store whether there is a discrepency between the base and marginal models triggering the discontinuity damages in different timesteps
    if model == PAGE
        discontinuity_mismatch = Array{Bool, 3}(undef, trials, length(perturbation_years), length(scenarios))
        push!(payload, discontinuity_mismatch)
    end

    # Make an array to hold all calculated scc values
    SCC_values = Array{Float64, 5}(undef, trials, length(perturbation_years), length(scenarios), length(prtp_rates), length(eta_levels))
    if domestic 
        SCC_values_domestic =  Array{Float64, 5}(undef, trials, length(perturbation_years), length(scenarios), length(prtp_rates), length(eta_levels))
    else
        SCC_values_domestic = nothing 
    end

    # Make an array to hold undiscounted marginal damages, if specified
    if save_md
        md_values = Array{Float64, 4}(undef, length(perturbation_years), length(scenarios), length(model_years), trials)
    else
        md_values = nothing
    end

    # Set the payload object
    push!(payload, [gas, perturbation_years, SCC_values, SCC_values_domestic, md_values]...)

    Mimi.set_payload!(mcs, payload)

    # Generate trials 
    trials_filepath = save_trials ? joinpath(output_dir, "trials.csv") : nothing 

    # Run the simulation
    sim_results = run(mcs, models, trials;
        trials_output_filename = trials_filepath, 
        ntimesteps = nyears,    
        scenario_func = scenario_func, 
        scenario_args = [:scenario => scenarios],
        post_trial_func = post_trial_func
    )

    SCC_values, SCC_values_domestic, md_values = Mimi.payload(sim_results)[end-2:end]

    # Save the marginal damage matrices
    if save_md
        md_dir = joinpath(output_dir, "marginal_damages/")
        mkpath(md_dir)
        for (i, year) in enumerate(perturbation_years)
            for (j, scen) in enumerate(scenarios)
                fn = joinpath(md_dir, "$scen $year.csv")
                writedlm(fn, hcat(model_years, md_values[i, j, :, :]), ',') # add model year labels as the first column in each file
            end
        end
    end

    # generic interpolation if user requested SCC values for years in between model_years
    if _need_to_interpolate
        new_SCC_values = Array{Float64, 5}(undef, trials, length(all_years), length(scenarios), length(prtp_rates), length(eta_levels))
        for i in 1:trials, j in 1:length(scenarios), k in 1:length(prtp_rates), l in 1:length(eta_levels)
            new_SCC_values[i, :, j, k, l] = _interpolate(SCC_values[i, :, j, k, l], perturbation_years, all_years)
        end
        SCC_values = new_SCC_values 

        if domestic 
            new_domestic_values = Array{Float64, 5}(undef, trials, length(all_years), length(scenarios), length(prtp_rates), length(eta_levels))
            for i in 1:trials, j in 1:length(scenarios), k in 1:length(prtp_rates), l in 1:length(eta_levels)
                new_domestic_values[i, :, j, k, l] = _interpolate(SCC_values_domestic[i, :, j, k, l], perturbation_years, all_years)
            end
            SCC_values_domestic = new_domestic_values
        end

        # reset perturbation years to all user requested years, unless model is PAGE, for which this is done below
        if model != PAGE
            perturbation_years = all_years
        end
    end
    
    # Save the information about which runs have a discrepency between base/marginal models of the discontinuity damages
    if model == PAGE
        # access the computed saved values from the simulation instance; it's the sixth item in the payload object for PAGE
        discontinuity_mismatch = Mimi.payload(sim_results)[6] 

        if _need_to_interpolate
            new_discontinuity_mismatch = Array{Bool}(undef, trials, length(all_years), length(scenarios))
            for i in 1:trials, j in 1:length(scenarios)
                new_discontinuity_mismatch[i, :, j] = convert(Array{Bool}, _interpolate(discontinuity_mismatch[i, :, j], perturbation_years, all_years) .> 0)
            end
            discontinuity_mismatch = new_discontinuity_mismatch
            perturbation_years = all_years 
        end

        disc_dir = joinpath(output_dir, "discontinuity_mismatch/")
        mkpath(disc_dir)

        # write full table
        for scenario in scenarios
            i, scenario_name = Int(scenario), string(scenario)
            filename = "$scenario_name.csv"
            filepath = joinpath(disc_dir, filename)
            open(filepath, "w") do f
                write(f, join(perturbation_years, ","), "\n")   # each column is a different SCC year, each row is a different trial result
                writedlm(f, discontinuity_mismatch[:, :, i], ',')
            end
        end

        # summary table of how many occured (rows are perturbation years, columns are discount rates)
        disc_sum = dropdims(sum(discontinuity_mismatch, dims=(1,3)), dims=(1,3))
        writedlm(joinpath(disc_dir, "discontinuity_summary.csv"), disc_sum, ',') 
    end

    # Save the SCC values
    scc_dir = joinpath(output_dir, "SC-$gas/")
    write_scc_values(SCC_values, scc_dir, perturbation_years, prtp_rates, eta_levels)
    if domestic 
        model == DICE ? SCC_values_domestic = SCC_values .* 0.1 : nothing   # domestic values for DICE calculated as 10% of global values
        write_scc_values(SCC_values_domestic, scc_dir, perturbation_years, prtp_rates, eta_levels, domestic=true)
    end

    drop_infs = model == FUND # explicitly drop the missing values in the saved SCCs which ocurr when consumption -> 0 and SCC -> Inf

    # Build the stats tables
    if tables
        make_percentile_tables(output_dir, gas, prtp_rates, eta_levels, perturbation_years; drop_discontinuities = drop_discontinuities, drop_infs = drop_infs)
        make_stderror_tables(output_dir, gas, prtp_rates, eta_levels, perturbation_years; drop_discontinuities = drop_discontinuities, drop_infs = drop_infs)
        make_summary_table(output_dir, gas, prtp_rates, eta_levels, perturbation_years; drop_discontinuities = drop_discontinuities, drop_infs = drop_infs)
    end

    nothing
end