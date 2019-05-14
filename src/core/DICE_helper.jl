"""
    Returns the IWG version of the DICE 2010 model for the specified scenario.
"""
function get_dice_model(scenario_choice::scenario_choice)
    params = load_dice_scenario_params(scenario_choice)
    return get_dice_model(params)
end 

"""
    Returns the IWG version of the DICE 2010 model for the specified parameter dictionary.
"""
function get_dice_model(params::Dict)

    # Get the original default version of DICE2010
    m = MimiDICE2010.construct_dice()

    # Shorten the time index
    set_dimension!(m, :time, dice_years)

    disconnect_param!(m, :radiativeforcing, :MAT_final) # need to disconnect this param (not used in IWG version) before replacing co2cycle
    
    # Replace the IWG modified components
    replace_comp!(m, IWG_DICE_co2cycle, :co2cycle)
    replace_comp!(m, IWG_DICE_radiativeforcing, :radiativeforcing)
    replace_comp!(m, IWG_DICE_climatedynamics, :climatedynamics)
    replace_comp!(m, IWG_DICE_neteconomy, :neteconomy)

    # Delete emissions component
    delete!(m, :emissions)
    set_param!(m, :co2cycle, :E, params[:E])    # Emissions in co2cycle are now exogenous

    # Update all parameter values for this scenario
    update_params!(m, params, update_timesteps=true)

    return m
end 

"""
    Returns a dictionary of DICE parameter values for the specified scenario.
"""
function load_dice_scenario_params(scenario_choice, scenario_file=nothing)

    # Input parameters from EPA's Matlab code
    A0    = 0.0303220  # First period total factor productivity, from DICE2010
    gamma = 0.3        # Labor factor productivity, from DICE2010
    delta = 0.1        # Capital depreciation rate [yr^-1], from DICE2010
    s     = 0.23       # Approximate optimal savings in DICE2010 

    params = Dict{Any, Any}()
    nyears = length(dice_years)

    # Replace some parameter values to match EPA's matlab code
    params[:S]          = repeat([s], nyears)    # previously called 'savebase'. :S in neteconomy
    params[:MIU]        = zeros(nyears)             # previously called 'miubase'-- :MIU in neteconomy;  make this all zeros so abatement in neteconomy is calculated as zero; EPA doesn't include abatement costs
    params[:a1]         = 0.00008162
    params[:a2]         = 0.00204626
    params[:b1]         = 0.00518162                # previously called 'slrcoeff'-- :b1 in SLR
    params[:b2]         = 0.00305776                # previously called 'slrcoeffsq'-- :b2 in SLR 

    # Get the scenario number
    idx = Int(scenario_choice)

    # All scenario data
    scenario_file = scenario_file==nothing ? iwg_dice_input_file : scenario_file
    f = openxl(scenario_file)

    Y = readxl(f, "GDP!B2:F32")[:, idx] * dice_inflate      # GDP
    N = readxl(f, "Population!B2:F32")[:, idx]              # Population
    E = readxl(f, "IndustrialCO2!B2:F32")[:, idx]           # Industrial CO2
    El = readxl(f, "LandCO2!B2:F32")[:, idx]                # Land CO2 
    Fex1 = readxl(f, "EMFnonCO2forcings!B2:F32")[:, idx]    # EMF non-CO2 forcings
    Fex2 = readxl(f, "OthernonCO2forcings!B2:B32")          # Other non-CO2 forcings
    Fex = Fex1 + Fex2                                       # All non-CO2 forcings

    # Use 2010 EMF value for dice period 2005-2015 etc. (need additional zeros to run past the 31st timestep)
    Y = [Y[2:end]; zeros(nyears - length(Y[2:end]))]
    N = [N[2:end]; zeros(nyears - length(N[2:end]))]
    E = [E[2:end]; zeros(nyears - length(E[2:end]))]
    El = [El[2:end]; zeros(nyears - length(El[2:end]))]
    Fex = [Fex[2:end]; zeros(nyears - length(Fex[2:end]))]

    # Set these scenario values in the parameter dictionary:
    params[:l] = N          # population
    params[:E] = El + E     # total CO2 emissions
    params[:forcoth] = Fex  # other forcings

    # Solve for implied path of exogenous technical change using the given GDP (Y data) 
    al = zeros(nyears)   
    K = zeros(nyears)
    al[1] = A0
    K[1] = (Y[1] / al[1] / (N[1] ^ (1 - gamma))) ^ (1 / gamma)
    for t in 2:nyears
        K[t] = K[t-1] * (1 - delta) ^ 10 + s * Y[t-1] * 10
        al[t] = Y[t] / (N[t] + eps()) ^ (1 - gamma) / (K[t] + eps()) ^ gamma
    end

    # Update these parameters for grosseconomy component
    params[:al] = al    # total factor productivity
    params[:k0] = K[1]  # initial capital stock

    return params
end

"""
    Returns marginal damages each year from an additional emissions pulse in the specified year. 
    User must specify an IWG scenario `scenario_choice`.
    If no `year` is specified, will run for an emissions pulse in $_default_year.
    If no `discount` is specified, will return undiscounted marginal damages.
"""
function get_dice_marginaldamages(scenario_choice::scenario_choice, year::Int, discount::Float64) 

    # Check the emissions year
    _is_mid_year = false
    if year < dice_years[1] || year > dice_years[end]
        error("$year is not a valid year; can only calculate marginal damages within the model's time index $dice_years.")
    elseif ! (year in dice_years)
        _is_mid_year = true         # boolean flag for if the desired year is in between values of the model's time index
        mid_year = year     # save the desired year to interpolate later
        year = dice_years[Int(floor((year - dice_years[1]) / dice_ts) + 1)]    # first calculate for the DICE year below the specified year
    end

    base = get_dice_model(scenario_choice)
    marginal = Model(base)
    add_dice_marginal_emissions!(marginal, year)

    run(base)
    run(marginal)

    base_C = base[:neteconomy, :C]
    marginal_C = marginal[:neteconomy, :C]

    diff = (base_C - marginal_C) * 10^3 * 12/44     # consumption is in trillions, pulse was Gt so *10^12/10^9

    if _is_mid_year     # need to calculate md for next year in time index as well, then interpolate for desired year
        lower_diff = diff
        next_year = dice_years[findfirst(isequal(year), dice_years) + 1]
        upper_diff = get_dice_marginaldamages(scenario_choice, next_year, 0.)
        diff = [_interpolate([lower_diff[i], upper_diff[i]], [year, next_year], [mid_year])[1] for i in 1:length(lower_diff)]
    end 

    if discount != 0 
        nyears = length(dice_years)
        DF = zeros(nyears)
        first = findfirst(isequal(year), dice_years)
        DF[first:end] = [1/(1+discount)^t for t in 0:(nyears-first)]
        return diff .* DF
    else
        return diff
    end

end

"""
    Adds a marginal emissions component to a DICE model. 
    If a year is specified, 1 GtC is added to emissions in that year.
"""
function add_dice_marginal_emissions!(m::Model, year=nothing)
    add_comp!(m, Mimi.adder, :marginalemission, before=:co2cycle)
    time = Mimi.dimension(m, :time)
    addem = zeros(length(time))

    if year != nothing 
        year_idx = findfirst(isequal(year), dice_years)
        if year_idx == nothing 
            error("year $year provided to add_dice_marginal_emissions! not in dice time dimension")
        end 
        addem[year_idx] = 1.0
    end 

    set_param!(m, :marginalemission, :add, addem)
    connect_param!(m.md, :marginalemission, :input, :E)    # connect to the external parameter (exogenous emissions)
    connect_param!(m, :co2cycle, :E, :marginalemission, :output)

    nothing
end 

"""
    Perturbs the marginal emissions in the given index year for a DICE model.
    Marginal emissions component must already exist in the model.
"""
function perturb_dice_marginal_emissions!(marginal::Model, year::Int; comp_name=:marginalemission)

    year_idx = findfirst(isequal(year), dice_years)
    ci = marginal.mi.components[comp_name]
    pulse = Mimi.get_param_value(ci, :add)

    pulse.data[:] .= 0.0    # pulse is a timestep array, need to access the data array to reset to zero because pulse[:] .= 0 doesn't work even though it doesn't error
    pulse.data[year_idx] = 1.0

    nothing
end

"""
    Returns the Social Cost of Carbon for a given `year` and `discount` rate from one deterministic run of the IWG-DICE model.
    User must specify an IWG scenario `scenario_choice`.
    If no `year` is specified, will return SCC for $_default_year.
    If no `discount` is specified, will return SCC for a discount rate of $(_default_discount * 100)%.
"""
function get_dice_scc(scenario_choice::scenario_choice, year::Int, discount::Float64, horizon=_default_horizon)

    # Check if the emissions year is valid, and whether or not we need to interpolate
    _is_mid_year = false
    if year < dice_years[1] || year > dice_years[end]
        error("$year is not a valid year; can only calculate SCC within the model's time index $years.")
    elseif ! (year in dice_years)
        _is_mid_year = true         # boolean flag for if the desired SCC years is in between values of the model's time index
        mid_year = year     # save the desired SCC year to interpolate later
        year = dice_years[Int(floor((year - dice_years[1]) / dice_ts) + 1)]    # first calculate for the DICE year below the specified year
    end

    md = get_dice_marginaldamages(scenario_choice, year, 0.)   # Get undiscounted marginal damages
    annual_years = dice_years[1]:horizon
    annual_md = _interpolate(md, dice_years, annual_years)   # Interpolate to annual timesteps

    DF = zeros(length(annual_years)) 
    first = findfirst(isequal(year), annual_years)
    DF[first:end] = [1/(1+discount)^t for t in 0:(length(annual_years)-first)]

    scc = sum(annual_md .* DF)

    if _is_mid_year     # need to calculate SCC for next year in time index as well, then interpolate for desired year
        lower_scc = scc
        next_year = dice_years[findfirst(isequal(year), dice_years) + 1]
        upper_scc = get_dice_scc(scenario_choice, next_year, discount, horizon)
        scc = _interpolate([lower_scc, upper_scc], [year, next_year], [mid_year])[1]
    end 

    return scc 
end