"""
    Returns the IWG version of the FUND3.8 model without any scenario parameters set yet. 
    Need to call apply_scenario!(m, scenario_name) before this model can be run.
"""
function get_fund_model()

    # Get the default FUND model
    m = getfund()

    # Replace the Impact Sea Level Rise component
    replace_comp!(m, IWG_FUND_impactsealevelrise, :impactsealevelrise)

    # Add Roe Baker Climate Sensitivity parameter and make connection from Climate Dynamics component
    add_comp!(m, IWG_FUND_roebakerclimatesensitivity, :roebakerclimatesensitivity; before = :climatedynamics)
    connect_param!(m, :climatedynamics, :climatesensitivity, :roebakerclimatesensitivity, :climatesensitivity)

    return m

end 

"""
    Returns the IWG version of the FUND3.8 model for the specified scenario name.
"""
function get_fund_model(scenario_name::String)
    m = get_fund_model()
    apply_fund_scenario!(m, scenario_name)
    return m 
end

"""
    Set the scenario-specific parameters in a FUND model m for the specified scenario name.
"""
function apply_fund_scenario!(m, scenario_name)

    scenario_params = load_fund_scenario_params(scenario_name)

    # Two global emissions values were previously endogenous; now set them to external IWG scenario values
    set_param!(m, :climatech4cycle, :globch4, scenario_params["globch4"])
    set_param!(m, :climaten2ocycle, :globn2o, scenario_params["globn2o"])

    set_param!(m, :population, :pgrowth, scenario_params["pgrowth"])
    set_param!(m, :socioeconomic, :pgrowth, scenario_params["pgrowth"])
    set_param!(m, :socioeconomic, :ypcgrowth, scenario_params["ypcgrowth"])
    set_param!(m, :emissions, :aeei, scenario_params["aeei"])
    set_param!(m, :emissions, :acei, scenario_params["acei"])
    set_param!(m, :emissions, :pgrowth, scenario_params["pgrowth"])
    set_param!(m, :emissions, :ypcgrowth, scenario_params["ypcgrowth"])

end

"""
    Returns a dictionary of FUND parameter values for the specified scenario.
"""
function load_fund_scenario_params(scenario_name)

    scenario_file = joinpath(iwg_fund_datadir, "Parameter - EMF22 $(fund_scenario_convert[scenario_name]).xlsm")

    scenario_params = Dict{Any, Any}()
    f = openxl(scenario_file)
    for p in ["ypcgrowth", "pgrowth", "AEEI", "ACEI", "ch4", "n2o"] 
        scenario_params[lowercase(p)] = readxl(f, "$(p)!B2:Q1052")
    end
    scenario_params["globch4"] = sum(Array{Float64,2}(scenario_params["ch4"]), dims = 2)[:] # sum horizontally for global emissions
    scenario_params["globn2o"] = sum(Array{Float64,2}(scenario_params["n2o"]), dims = 2)[:]

    return scenario_params
end

"""
    Returns marginal damages each year from an additional emissions pulse in the specified year. 
    User must specify an IWG scenario name `scenario_name`.
    If no `year` is specified, will run for an emissions pulse in $_default_year.
    If no `discount` is specified, will return undiscounted marginal damages.
    The `income_normalized` parameter indicates whether the damages from the marginal run should be scaled by the ratio of incomes between the base and marginal runs. 
"""
function get_fund_marginaldamages(scenario_name::String, year::Int, discount::Float64, income_normalized::Bool=true)

    # Check the emissions year
    if ! (year in fund_years)
        error("$year not a valid year; must be in model's time index $fund_years.")
    end

    base = get_fund_model(scenario_name)
    marginal = Model(base)
    MimiFUND.add_marginal_emissions!(marginal, year)     # Function from original fund code

    run(base)
    run(marginal)

    damages1 = base[:impactaggregation, :loss]
    if income_normalized
        damages2 = marginal[:impactaggregation, :loss] ./ marginal[:socioeconomic, :income] .* base[:socioeconomic, :income]
    else
        damages2 = marginal[:impactaggregation, :loss]
    end

    global_diff = sum((damages2 .- damages1), dims = 2) / 10000000. * 12.0/44.0 * fund_inflator   # /10 for 10 year pulse; /10^6 for Mt pulse

    nyears = length(fund_years)
    if discount != 0 
        DF = zeros(nyears)
        first = MimiFUND.getindexfromyear(year)
        DF[first:end] = [1/(1+discount)^t for t in 0:(nyears-first)]
        return global_diff[1:nyears] .* DF
    else
        return global_diff[1:nyears]
    end

end

"""
    Returns the Social Cost of Carbon for a given `year` and `discount` rate from one deterministic run of the IWG-FUND model.
    User must specify an IWG scenario name `scenario_name`.
    If no `year` is specified, will return SCC for $_default_year.
    If no `discount` is specified, will return SCC for a discount rate of $(_default_discount * 100)%.
"""
function get_fund_scc(scenario_name::String, year::Int, discount::Float64, income_normalized::Bool=true)

    # Check the emissions year
    if !(year in fund_years)
        error("$year is not a valid year; can only calculate SCC within the model's time index $fund_years.")
    end

    md = get_fund_marginaldamages(scenario_name, year, discount, income_normalized)
    scc = sum(md[MimiFUND.getindexfromyear(year):end])    # Sum from the perturbation year to the end (avoid the NaN in the first timestep)
    return scc 
end