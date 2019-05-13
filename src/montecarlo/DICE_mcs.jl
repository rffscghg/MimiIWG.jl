
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

"""
    Run a Monte Carlo Simulation over the IWG version of DICE 2010. 
"""
function run_dice_scc_mcs(mcs::Simulation = get_dice_mcs(); 
        trials = 10,
        perturbation_years = _default_dice_perturbation_years,
        discount_rates = _default_discount_rates,
        domestic = false, 
        output_dir = nothing, 
        save_trials = false,
        tables = true)
 
    output_dir == nothing ? error("Must provide an output_dir to run_dice_scc_mcs.") : nothing
    mkpath(output_dir)

    # Specify directory to save SCC values in
    scc_dir = joinpath(output_dir, "SCC/")
    mkpath(scc_dir)

    # Allocate matrix to store each trial's SCC values
    SCC_values = Array{Float64, 4}(undef, trials, length(perturbation_years), length(scenarios), length(discount_rates))

    # Specify scenario arguments
    scenario_args = [
        :scenario => scenarios, 
        :rate => discount_rates
        ]

    # precompute discount factors for the defined rates
    last_idx = H - 2005 + 1
    discount_factors = Dict([rate => [(1 + rate) ^ y for y in 0:last_idx-1] for rate in discount_rates])

    nyears = length(dice_years)
    annual_years = dice_years[1]:H

    # MCS "scenario_func" called outside the MCS loop
    function scenario_setup(mcs::Simulation, tup::Tuple)
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

    # Called after each trial; marginal model is run for each perturbation year
    function post_trial(mcs::Simulation, trial::Int, ntimesteps::Int, tup::Tuple)
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
            scc = sum(annual_md[first_idx:last_idx] ./ DF[1:H-pyear+1])

            SCC_values[trial, idx, scenario_num, rate_num] = scc 
        end

    end

    # Generate trials
    fn = save_trials ? joinpath(output_dir, "trials.csv") : nothing 
    generate_trials!(mcs, trials; filename = fn)

    # Run the simulation
    run_sim(mcs; 
        trials = trials, 
        models_to_run = 1,      # Run only the base model automatically in the MCS; we run the marginal model "manually" in a loop over all perturbation years in the post_trial function.
        ntimesteps = nyears,    # Run the full length to 2405, but nothing past 2300 gets used for the SCC
        scenario_func = scenario_setup, 
        scenario_args = scenario_args,
        post_trial_func = post_trial,
        output_dir = joinpath(output_dir, "saved_variables"))

    # Save the SCC values
    for scenario in scenarios, (j, rate) in enumerate(discount_rates)
        i, scenario_name = Int(scenario), string(scenario)
        # File for all SCC years
        scc_file = joinpath(scc_dir, "$(scenario_name) $rate.csv")
        open(scc_file, "w") do f
            write(f, join(perturbation_years, ","), "\n")
            writedlm(f, SCC_values[:, :, i, j], ',')
        end
        if all(x -> x in perturbation_years, 2005:10:2055)
            # Summary file for 2010:5:2050, can only make it if SCC values for 2005:10:2055 were calculated
            summ_file = joinpath(scc_dir, "$(scenario_name) $(rate) 2010-2050.csv") 
            _interpolate_2010_2050_results(summ_file, SCC_values[:, 1:6, i, j])
        end
    end
    
    # Write summary tables to output directory
    if tables
        if all(x -> x in perturbation_years, 2005:10:2055)
            # Make EPA Tables A2, A3, and A4 (use SCC for year 2020, so we need to have the 2010-2050 interpolated summary file)
            _make_percentile_tables(scc_dir, joinpath(output_dir, "Tables"), [string(s) for s in scenarios], discount_rates)
        end

        # Make standard error tables
        _make_stderror_tables(output_dir, discount_rates, perturbation_years)
    end

    return nothing
end 

# """
# Make a CSV file of SCC values for years 2010:5:2050.
# Years 2015, 2025, 2035, and 2045 were already calculated directly, 
# but values for 2010, 2020, 2030, 2040 and 2050 must be interpolated here.
# Input data are from years 2005:10:2055
# """
function _interpolate_2010_2050_results(fn, data)
    old_years = [2005,2015,2025,2035,2045,2055]
    new_years = 2010:5:2050
    num_trials = size(data, 1)

    itp_data = Array{Float64,2}(undef, num_trials + 1, length(new_years))
    itp_data[1, :] = new_years  # First row of file is header with new year labels

    for i in 2:num_trials+1
        itp = interpolate((old_years,), Array{Float64,1}(data[i-1, :]), Gridded(Linear()))
        itp_data[i, :] = [itp(y...) for y in new_years] 
    end

    writedlm(fn, itp_data, ',')
end

# """
# Tables of percentile values of 2020 SCC values (assumes all three discount_rates?)
# """
function _make_percentile_tables(datadir, tabledir, scenario_names, discount_rates)
    mkpath(tabledir)

    pcts = [.01, .05, .1, .25, .5, :mean, .75, .90, .95, .99]
    table_names = ["Table A2", "Table A3", "Table A4"]

    for (rate, table_name) in zip(discount_rates, table_names)
        fname = joinpath(tabledir, "$(table_name).csv")

        open(fname, "w") do f
            write(f, "Scenario,1st,5th,10th,25th,50th,Avg,75th,90th,95th,99th\n")

            for scenario in scenario_names
                # generate statistics for the values for 2020 (the third year)
                d = readdlm(joinpath(datadir, "$(scenario) $(rate) 2010-2050.csv"), ',')[2:end, 3] # drop header; column 3 is 2020
                values = [pct == :mean ? Int(round(mean(d))) : Int(round(quantile(d, pct))) for pct in pcts]
                write(f, "$scenario,", join(values, ","), "\n")
            end
        end
    end 
end

function _make_stderror_tables(output_dir, discount_rates, perturbation_years)

    scc_dir = "$output_dir/SCC"
    tables = "$output_dir/tables"
    mkpath(tables)

    results = readdir(scc_dir)
    # y = findfirst(isequal(2015), perturbation_years)

    for dr in discount_rates
        table = joinpath(tables, "Std Errors - $dr.csv")
        f = open(table, "w")
        write(f, "Scenario,SE,Mean\n")
        for fn in filter(x -> endswith(x, "$dr 2010-2050.csv"), results)  # Get the results files for this discount rate
            scenario = split(fn)[1] # get the scenario name
            write(f, scenario)
            d = readdlm(joinpath(scc_dir, fn), ',')[2:end, 3] # just keep 2020 values
            write(f, ",$(round(sem(d); digits = 2))")
            write(f,",$(round(mean(d); digits = 2))\n")
        end 
        close(f)
    end  
    nothing
end

nothing