

@enum model_choice DICE FUND PAGE 
const scenario_names = ["IMAGE", "MERGE Optimistic", "MESSAGE", "MiniCAM Base", "5th Scenario"]

# Default values for user facing functions
const _default_discount = 0.03  # 3%
const _default_horizon = 2300      # Same as H (the variable name used by the IWG)
const _default_year = 2020     # default perturbation year for marginal damages and scc
const _default_discount_rates = [.025, .03, .05]            # used by MCS

#------------------------------------------------------------------------------
# 1. DICE specific constants
#------------------------------------------------------------------------------

const iwg_dice_input_file = joinpath(@__DIR__, "../../data/IWG_inputs/DICE/SCC_input_EMFscenarios.xls")
const RBdistribution_file = joinpath(@__DIR__, "../../data/IWG_inputs/DICE/2009 11 23 Calibrated R&B distribution.xls")

const dice_ts = 10
const dice_years = collect(2005:dice_ts:2405)

const _default_dice_perturbation_years = collect(2005:dice_ts:2295)   # used by MCS

# Input parameters from EPA's Matlab code
const H     = 2300       # Time horizon for calculating SCC [year]
const A0    = 0.0303220  # First period total factor productivity, from DICE2010
const gamma = 0.3        # Labor factor productivity, from DICE2010
const delta = 0.1        # Capital depreciation rate [yr^-1], from DICE2010
const s     = 0.23       # Approximate optimal savings in DICE2010 

const inflate = 122.58 / 114.52 # World GDP inflator 2005 => 2007

const dice_scenario_convert = Dict{String, String}(    # convert to names standard across all three models and consistent with the TSDs
    "IMAGE"             => "IMAGE",
    "MERGE Optimistic"   => "MERGEoptimistic",
    "MESSAGE"           => "MESSAGE",
    "MiniCAM Base"       => "MiniCAMbase",
    "5th Scenario"       => "5thScenario"
)

#------------------------------------------------------------------------------
# 2. FUND specific constants
#------------------------------------------------------------------------------





#------------------------------------------------------------------------------
# 3. PAGE specific constants 
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
# 4. Utils
#------------------------------------------------------------------------------

# helper function for linear interpolation
function _interpolate(values, orig_x, new_x)
    itp = extrapolate(
                interpolate((orig_x,), Array{Float64,1}(values), Gridded(Linear())), 
                Line())
    # return [itp(i...) for i in new_x]
    return itp(new_x)
end