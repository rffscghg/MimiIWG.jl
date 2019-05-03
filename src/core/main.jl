"""

"""
function get_model(model::model_choice, scenario_name::Union{String, Nothing}=nothing)

    # Check for valid scenario name
    if scenario_name == nothing
        error("Must provide one of the following scenario names to get_model: $(join(scenario_names, ", "))")
    elseif ! (scenario_name in scenario_names)
        error("Unknown scenario name \"$scenario_name\". Must provide one of the following scenario names to get_model: $(join(scenario_names, ", "))")
    end

    # dispatch on provided model choice
    if model == DICE 
        return get_dice_model(scenario_name)
    elseif model == FUND 
        error("Not yet implemented")
    elseif model == PAGE 
        error("Not yet implemented")
    end
end

# function get_model(args...)
#     error("Must specifiy one of the following model choices as the first argument to `get_model`: DICE, FUND, or PAGE.")
# end

"""

"""
function get_marginaldamages(model::model_choice, scenario_name::Union{String, Nothing}=nothing, year::Union{Int, Nothing}=nothing, discount::Union{Float64, Nothing}=nothing)

    # Check for valid scenario name
    if scenario_name == nothing
        error("Must provide one of the following scenario names to get_model: $(join(scenario_names, ", "))")
    elseif ! (scenario_name in scenario_names)
        error("Unknown scenario name \"$scenario_name\". Must provide one of the following scenario names to get_model: $(join(scenario_names, ", "))")
    end

    # Check the emissions year
    if year == nothing 
        @warn("No `year` provided to `get_marginaldamages`; will return marginal damages from an emissions pulse in $_default_year.")
        year = _default_year
    end

    # Check the discount rate
    if discount == nothing 
        @warn("No `discount` provided to `get_marginaldamages`; will return undiscounted marginal damages.")
        discount = 0
    end 

    # dispatch on provided model choice
    if model == DICE 
        return get_dice_marginaldamages(scenario_name, year, discount, horizon)
    elseif model == FUND 
        error("Not yet implemented")
    elseif model == PAGE 
        error("Not yet implemented")
    end

end

"""

"""
function get_scc(model::model_choice, scenario_name::Union{String, Nothing}=nothing, year::Union{Int, Nothing}=nothing, discount::Union{Float64, Nothing}=nothing, horizon=_default_horizon)

    # Check for valid scenario name
    if scenario_name == nothing
        error("Must provide one of the following scenario names to get_model: $(join(scenario_names, ", "))")
    elseif ! (scenario_name in scenario_names)
        error("Unknown scenario name \"$scenario_name\". Must provide one of the following scenario names to get_model: $(join(scenario_names, ", "))")
    end

    # Check the emissions year
    if year == nothing 
        @warn("No `year` provided to `get_scc`; will return SCC from an emissions pulse in $_default_year.")
        year = _default_year
    end

    # Check the discount rate
    if discount == nothing 
        @warn("No `discount` provided to `get_scc`; will return SCC for a discount rate of $(_default_discount * 100)%.")
        discount = _default_discount
    end 

    # dispatch on provided model choice
    if model == DICE 
        return get_dice_scc(scenario_name, year, discount, horizon)
    elseif model == FUND 
        error("Not yet implemented")
    elseif model == PAGE 
        error("Not yet implemented")
    end

end