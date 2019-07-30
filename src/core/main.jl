"""

"""
function get_model(model::model_choice, scenario_choice::Union{scenario_choice, Nothing}=nothing)

    # Check for valid scenario name
    if scenario_choice === nothing
        @warn("No scenario name provided. If :scenario_num is not set in the :IWGScenarioChoice component before running the model, the average of the five scenarios will be used.")
    end

    # dispatch on provided model choice
    if model == DICE 
        return get_dice_model(scenario_choice)
    elseif model == FUND 
        return get_fund_model(scenario_choice)
    elseif model == PAGE 
        return get_page_model(scenario_choice)
    end
end

# function get_model(args...)
#     error("Must specifiy one of the following model choices as the first argument to `get_model`: DICE, FUND, or PAGE.")
# end

"""

"""
function get_marginaldamages(model::model_choice, scenario_choice::Union{scenario_choice, Nothing}=nothing; 
    year::Union{Int, Nothing}=nothing, 
    discount::Union{Float64, Nothing}=nothing, 
    regional::Bool=false)

    # Check for valid scenario name
    if scenario_choice === nothing
        @warn("No scenario name provided. If :scenario_num is not set in the :IWGScenarioChoice component before running the model, the average of the five scenarios will be used.")
    end

    # Check the emissions year
    if year === nothing 
        @warn("No `year` provided to `get_marginaldamages`; will return marginal damages from an emissions pulse in $_default_year.")
        year = _default_year
    end

    # Check the discount rate
    if discount === nothing 
        @warn("No `discount` provided to `get_marginaldamages`; will return undiscounted marginal damages.")
        discount = 0.
    end 

    # dispatch on provided model choice
    if model == DICE 
        return get_dice_marginaldamages(scenario_choice, year, discount)
    elseif model == FUND 
        return get_fund_marginaldamages(scenario_choice, year, discount)  #, regional)    #TODO: add this option for FUND
    elseif model == PAGE 
        return get_page_marginaldamages(scenario_choice, year, discount, regional)
    end

end

"""

"""
function get_scc(model::model_choice, scenario_choice::Union{scenario_choice, Nothing}=nothing; 
    year::Union{Int, Nothing}=nothing, 
    discount::Union{Float64, Nothing}=nothing,
    horizon=_default_horizon, 
    income_normalized=true, 
    domestic=false)  # some model specific arguments

    # Check for valid scenario name
    if scenario_choice === nothing
        @warn("No scenario name provided. If :scenario_num is not set in the :IWGScenarioChoice component before running the model, the average of the five scenarios will be used.")
    end

    # Check the emissions year
    if year === nothing 
        @warn("No `year` provided to `get_scc`; will return SCC from an emissions pulse in $_default_year.")
        year = _default_year
    end

    # Check the discount rate
    if discount === nothing 
        @warn("No `discount` provided to `get_scc`; will return SCC for a discount rate of $(_default_discount * 100)%.")
        discount = _default_discount
    end 

    # dispatch on provided model choice
    if model == DICE 
        return get_dice_scc(scenario_choice, year, discount, horizon)
    elseif model == FUND 
        return get_fund_scc(scenario_choice, year, discount, income_normalized)      # TODO: add `income_normalized` option to this general function?
    elseif model == PAGE 
        return get_page_scc(scenario_choice, year, discount; domestic=domestic)
    end

end