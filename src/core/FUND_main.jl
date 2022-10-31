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
    Sets FUND scenario parameters with the arguments:
    
    m: a Mimi model with and IWGScenarioChoice component
    comp_name: the name of the IWGScenarioChoice component in the model, defaults to :IWGScenarioChoice
    connect: whether or not to connect the outgoing variables to the other components who depend on them as parameter values
"""
function set_fund_all_scenario_params!(m::Model; comp_name::Symbol = :IWGScenarioChoice, connect::Bool = true)

    # reshape each array of values into one array for each param, then set that value in the model
    for (k, v) in _fund_scenario_params_dict
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

## For HFC implementation
# Read in rfs from file
hfc_rf_data = joinpath(@__DIR__, "..", "..", "data", "ghg_radiative_forcing_perturbation.csv")
hfc_rf_df = DataFrame(load(hfc_rf_data))

# Create new component -- see MimiFUND new_marginaldamages.jl
@defcomp marginal_hfc_forcings begin
    add    = Parameter(index=[time]) # marginal forcing
    input  = Parameter(index=[time]) # original forcing 
    output = Variable(index=[time]) # original forcing + marginal hfc forcing

    function run_timestep(p, v, d, t)
        v.output[t] = Mimi.@allow_missing(p.input[t]) + p.add[t]
    end
end

# Function to replace MimiFUND.perturb_marginal_emissions in fund_post_trial_func
function perturb_fund_marginal_emissions!(m::Model, year; comp_name::Symbol = :emissionspulse, gas::Symbol = :CO2)
    if ! (gas in HFC_list)
        MimiFUND.perturb_marginal_emissions!(m, year, gas=gas)
    elseif gas in HFC_list
        ci = Mimi.compinstance(m, :marginal_hfc_forcings)
        hfc_forcing = Mimi.get_param_value(ci, :add)

        nyears = length(Mimi.time_labels(m))
        # hfc_forcing.data = zeros(nyears)
        new_forcing = zeros(nyears)

        HFC_df = @from i in hfc_rf_df begin
            @where i.ghg .== string(gas)
            @select {i.rf}
            @collect DataFrame
        end
    
        # Process rfs such that rf for each year is cumulative sum of previous 10 years (corresponding to a 10-year pulse)
        rf_cumsum = cumsum(HFC_df.rf)
        rf_cumsum_10yr = zeros(length(rf_cumsum))
        for i in 1:length(rf_cumsum)
            if i <= 10
               rf_cumsum_10yr[i] = rf_cumsum[i]
            else
                rf_cumsum_10yr[i] = rf_cumsum[i] - rf_cumsum[i-10]
            end
        end

        # Set new marginal forcing vector equal to the "cumulative" rfs vector generated above
        new_forcing[MimiFUND.getindexfromyear(year):MimiFUND.getindexfromyear(year) + 299] = rf_cumsum_10yr
        hfc_forcing[:] = new_forcing
    else
        error("Unknown gas: $gas")
    end
end

# Function from original MimiFUND code, modified for IWG CH4 and N2O + modified for HFCs
function add_fund_marginal_emissions!(m::Model, year = nothing; gas, pulse_size = 1e7) # pulse size is in metric tonnes

    if ! (gas in HFC_list)
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
        else
            error("Unknown gas: $gas")
        end
    elseif gas in HFC_list
        # Add marginal_hfc_forcings component to m
        add_comp!(m, marginal_hfc_forcings, before = :climatedynamics)
        # add_comp!(m, marginal_hfc_forcings, after = :climateforcing)
        nyears = length(Mimi.time_labels(m))
        add_rf = zeros(nyears) 

        # Select values of rf for HFC specified
        HFC_df = @from i in hfc_rf_df begin
            @where i.ghg .== string(gas)
            @select {i.rf}
            @collect DataFrame
        end

        # Process rfs such that rf for each year is cumulative sum of previous 10 years (corresponding to a 10-year pulse)
        rf_cumsum = cumsum(HFC_df.rf)
        rf_cumsum_10yr = zeros(length(rf_cumsum))
        for i in 1:length(rf_cumsum)
            if i <= 10
               rf_cumsum_10yr[i] = rf_cumsum[i]
            else
                rf_cumsum_10yr[i] = rf_cumsum[i] - rf_cumsum[i-10]
            end
        end

        # Set add_rf equal to the "cumulative" rfs vector generated above
        if year !== nothing 
            add_rf[MimiFUND.getindexfromyear(year):MimiFUND.getindexfromyear(year) + 299] = rf_cumsum_10yr
        end

        # Set :add parameter in new component equal to add_rf
        set_param!(m, :marginal_hfc_forcings, :add, add_rf)

        # Connect parameters to other parts of the model: input parameter equal to radforc from :climateforcing, and output parameter equal to radforc in :climatedynamics
        connect_param!(m, :marginal_hfc_forcings, :input, :climateforcing, :radforc)
        connect_param!(m, :climatedynamics, :radforc, :marginal_hfc_forcings, :output)
    end
end

"""
    Returns marginal damages each year from an additional emissions pulse of the specified `gas` in the specified `year`. 
    User must specify an IWG scenario `scenario_choice`.
    If no `gas` is sepcified, will run for an emissions pulse of CO2.
    If no `year` is specified, will run for an emissions pulse in $_default_year.
    The `income_normalized` parameter indicates whether the damages from the marginal run should be scaled by the ratio of incomes between the base and marginal runs. 
"""
function get_fund_marginaldamages(scenario_choice::scenario_choice, gas::Symbol, year::Int, discount::Float64; regional::Bool = false, income_normalized::Bool=true, return_m::Bool = false)

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
        md = diff[1:nyears, :] .* DF
    else
        md = diff[1:nyears, :]
    end

    if return_m
        return (md, base)
    else
        return md
    end
end

"""
    Returns the Social Cost of `gas` for a given `year` and discount rate determined 
    by `eta` and `prtp` from one deterministic run of the IWG-FUND model. User must 
    specify an IWG scenario `scenario_choice`.

    Users can optionally turn on `equity_weighting` and an optional `normalization_region`, 
    which default to `false` and `nothing`.

    If no `gas` is specified, will retrun the SC-CO2.
    If no `year` is specified, will return SC for $_default_year.
    If no `prtp` is specified, will return SC for a prtp of $(_default_discount * 100)%.
"""
function compute_fund_scc(scenario_choice::scenario_choice, gas::Symbol, year::Int, 
                        prtp::Float64; eta::Float64 = 0., domestic::Bool = false, 
                        equity_weighting::Bool = false, income_normalized::Bool = true,
                        normalization_region::Union{Int, Nothing} = nothing,
                        reference_year::Union{Int, Nothing} = nothing
                    )

    if isnothing(reference_year)
        reference_year = year
    else
        if reference_year > year
            error("Reference year must be before emissions year")
        end
    end
    
    # check equity weighting cases, the only options are (1) only domestic (2) only 
    # equity weighting (3) equity weighting with a normalizationr egion
    if equity_weighting && domestic
        error("Cannot set both domestic and equity weighting to true at the same time for SCC computation")
    elseif !(equity_weighting) && !isnothing(normalization_region)
        error("Cannot set a normalization region if equity weighting is false for SCC computation.")
    end
    
    # Check the emissions year
    if !(year in fund_years)
        error("$year is not a valid year; can only calculate SCC within the model's time index $fund_years.")
    end

    p_idx = MimiFUND.getindexfromyear(year) # index of the year of the pulse
    r_idx = MimiFUND.getindexfromyear(reference_year) # index of the reference year for the discount rate (default to same as p_idx)
    
    offset = p_idx - r_idx # difference between the p_idx and r_idx for summing to NPV

    nyears = length(fund_years)

    md, m = get_fund_marginaldamages(scenario_choice, gas, year, 0., income_normalized = income_normalized, regional = true, return_m = true)
    consumption = m[:socioeconomic, :consumption]
    pop = m[:socioeconomic, :population]

    if domestic
        consumption = consumption[:, 1] # US is the first region
        pop = pop[:, 1]
        md = md[:, 1]
    end

    return get_discrete_scc(md[r_idx:end, :], 
                            prtp, 
                            eta, 
                            consumption[r_idx:nyears, :], 
                            pop[r_idx:nyears, :], 
                            collect(fund_years[r_idx:end]), 
                            equity_weighting = equity_weighting, 
                            normalization_region = normalization_region, 
                            offset = offset
                        )
    
end