"""
    Returns the IWG version of the FUND3.8 model without any scenario parameters set yet. 
    Need to call apply_scenario!(m, scenario_choice) before this model can be run.
"""
function get_fund_model(scenario_choice::Union{scenario_choice, Nothing} = nothing)

    # Get the default FUND model
    m = getfund()

    # Replace the Impact Sea Level Rise component
    replace!(m, :impactsealevelrise => IWG_FUND_impactsealevelrise)

    # Add Roe Baker Climate Sensitivity parameter and make connection from Climate Dynamics component
    add_comp!(m, IWG_RoeBakerClimateSensitivity, :roebakerclimatesensitivity; before = :climatedynamics)
    connect_param!(m, :climatedynamics, :climatesensitivity, :roebakerclimatesensitivity, :climatesensitivity)

    # Add the scenario choice component and load all the scenario parameter values
    add_comp!(m, IWG_FUND_ScenarioChoice, :IWGScenarioChoice; before = :population)
    set_dimension!(m, :scenarios, length(scenarios))
    set_fund_all_scenario_params!(m)
        
    # Set the scenario number if a scenario_choice was provided
    if scenario_choice !== nothing 
        scenario_num = Int(scenario_choice)
        set_param!(m, :IWGScenarioChoice, :scenario_num, scenario_num)
    end

    return m
end 

"""
set_fund_all_scenario_params!(m::Model; comp_name::Symbol = :IWGScenarioChoice, connect::Boolean = true)
    m: a Mimi model with and IWGScenarioChoice component
    comp_name: the name of the IWGScenarioChoice component in the model, defaults to :IWGScenarioChoice
    connect: whether or not to connect the outgoing variables to the other components who depend on them as parameter values
"""
function set_fund_all_scenario_params!(m::Model; comp_name::Symbol = :IWGScenarioChoice, connect::Bool = true)
    params_dict = Dict{String, Array}([k=>[] for k in fund_scenario_specific_params])

    # add an array of each scenario's value to the dictionary
    for scenario in scenarios
        params = load_fund_scenario_params(scenario)
        for p in fund_scenario_specific_params
            push!(params_dict[p], params[p])
        end
    end

    # reshape each array of values into one array for each param, then set that value in the model
    for (k, v) in params_dict
        _size = size(v[1])
        param = zeros(_size..., 5)
        for i in 1:5
            param[[1:l for l in _size]..., i] = v[i]
        end
        set_param!(m, comp_name, Symbol("$(k)_all"), param)
    end

    if connect 
        # Two global emissions values were previously endogenous; now set them to external IWG scenario values
        connect_param!(m, :climatech4cycle => :globch4, comp_name => :globch4)
        connect_param!(m, :climaten2ocycle => :globn2o, comp_name => :globn2o)

        # Socioeconomics
        connect_all!(m, [:population, :socioeconomic, :emissions], comp_name => :pgrowth)
        connect_all!(m, [:socioeconomic, :emissions], comp_name => :ypcgrowth)
        connect_param!(m, :emissions => :aeei, comp_name => :aeei)
        connect_param!(m, :emissions => :acei, comp_name => :acei)

    end
end

"""
    Returns a dictionary of FUND parameter values for the specified scenario.
"""
function load_fund_scenario_params(scenario_choice)

    scenario_file = joinpath(iwg_fund_datadir, "Parameter - EMF22 $(fund_scenario_convert[scenario_choice]).xlsm")

    scenario_params = Dict{Any, Any}()
    f = openxl(scenario_file)
    for p in ["ypcgrowth", "pgrowth", "AEEI", "ACEI", "ch4", "n2o"] 
        scenario_params[lowercase(p)] = readxl(f, "$(p)!B2:Q1052")
    end
    scenario_params["globch4"] = sum(Array{Float64,2}(scenario_params["ch4"]), dims = 2)[:] # sum horizontally for global emissions
    scenario_params["globn2o"] = sum(Array{Float64,2}(scenario_params["n2o"]), dims = 2)[:]

    return scenario_params
end

# Function from original MimiFUND code, modified for IWG CH4 and N2O
function add_fund_marginal_emissions!(m, year = nothing; gas = :CO2, pulse_size = 1e7)

    # Add additional emissions to m
    add_comp!(m, MimiFUND.emissionspulse, before = :climateco2cycle)
    nyears = length(Mimi.time_labels(m))
    addem = zeros(nyears) 
    if year !== nothing 
        # pulse is spread over ten years, and emissions components is in Mt so divide by 1e7, and convert from CO2 to C if gas==:CO2 because emissions component is in MtC
        addem[MimiFUND.getindexfromyear(year):MimiFUND.getindexfromyear(year) + 9] .= pulse_size / 1e7 * MimiFUND._gas_normalization(gas)
    end
    set_param!(m, :emissionspulse, :add, addem)

    # Reconnect the appropriate emissions in m
    if gas == :CO2
        connect_param!(m, :emissionspulse, :input, :emissions, :mco2)
        connect_param!(m, :climateco2cycle, :mco2, :emissionspulse, :output)
    elseif gas == :CH4
        connect_param!(m, :emissionspulse, :input, :IWGScenarioChoice, :globch4)
        connect_param!(m, :climatech4cycle, :globch4, :emissionspulse, :output)
    elseif gas == :N2O
        connect_param!(m, :emissionspulse, :input, :IWGScenarioChoice, :globn2o)
        connect_param!(m, :climaten2ocycle, :globn2o, :emissionspulse, :output)
    elseif gas == :SF6
        connect_param!(m, :emissionspulse, :input, :emissions, :globsf6)
        connect_param!(m, :climatesf6cycle, :globsf6, :emissionspulse, :output)
    else
        error("Unknown gas: $gas")
    end
end

"""
    Returns marginal damages each year from an additional emissions pulse of the specified `gas` in the specified `year`. 
    User must specify an IWG scenario `scenario_choice`.
    If no `gas` is sepcified, will run for an emissions pulse of CO2.
    If no `year` is specified, will run for an emissions pulse in $_default_year.
    If no `discount` is specified, will return undiscounted marginal damages.
    The `income_normalized` parameter indicates whether the damages from the marginal run should be scaled by the ratio of incomes between the base and marginal runs. 
"""
function get_fund_marginaldamages(scenario_choice::scenario_choice, gas::Symbol, year::Int, discount::Float64; regional::Bool = false, income_normalized::Bool=true)

    # Check the emissions year
    if ! (year in fund_years)
        error("$year not a valid year; must be in model's time index $fund_years.")
    end

    base = get_fund_model(scenario_choice)
    marginal = Model(base)
    add_fund_marginal_emissions!(marginal, year, gas = gas)

    run(base)
    run(marginal)

    damages1 = base[:impactaggregation, :loss]
    if income_normalized
        damages2 = marginal[:impactaggregation, :loss] ./ marginal[:socioeconomic, :income] .* base[:socioeconomic, :income]
    else
        damages2 = marginal[:impactaggregation, :loss]
    end

    if regional
        diff = (damages2 .- damages1) * 1e-7 * fund_inflator
    else
        diff = sum((damages2 .- damages1), dims = 2) * 1e-7 * fund_inflator   
    end

    nyears = length(fund_years)
    if discount != 0 
        DF = zeros(nyears)
        first = MimiFUND.getindexfromyear(year)
        DF[first:end] = [1/(1+discount)^t for t in 0:(nyears-first)]
        return diff[1:nyears, :] .* DF
    else
        return diff[1:nyears, :]
    end

end

"""
    Returns the Social Cost of `gas` for a given `year` and `discount` rate from one deterministic run of the IWG-FUND model.
    User must specify an IWG scenario `scenario_choice`.
    If no `gas` is specified, will retrun the SC-CO2.
    If no `year` is specified, will return SC for $_default_year.
    If no `discount` is specified, will return SC for a discount rate of $(_default_discount * 100)%.
"""
function compute_fund_scc(scenario_choice::scenario_choice, gas::Symbol, year::Int, discount::Float64; domestic::Bool = false, income_normalized::Bool = true)

    # Check the emissions year
    if !(year in fund_years)
        error("$year is not a valid year; can only calculate SCC within the model's time index $fund_years.")
    end

    if domestic
        md = get_fund_marginaldamages(scenario_choice, gas, year, discount, income_normalized = income_normalized, regional = true)[:, 1]
    else
        md = get_fund_marginaldamages(scenario_choice, gas, year, discount, income_normalized = income_normalized, regional = false)
    end
        
    scc = sum(md[MimiFUND.getindexfromyear(year):end])    # Sum from the perturbation year to the end (avoid the NaN in the first timestep)
    return scc 
end