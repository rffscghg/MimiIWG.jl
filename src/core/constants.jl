
# Model and scenario choices
@enum model_choice DICE FUND PAGE 
@enum scenario_choice USG1=1 USG2=2 USG3=3 USG4=4 USG5=5
const scenarios = [USG1, USG2, USG3, USG4, USG5]    # for use in iterating
# const tsd_scenario_names = ["IMAGE", "MERGE Optimistic", "MESSAGE", "MiniCAM Base", "5th Scenario"]

# Default values for user facing functions
const _default_year = 2020      # default perturbation year for marginal damages and scc
const _default_discount = 0.03  # 3% constant discounting
const _default_horizon = 2300   # Same as H (the variable name used by the IWG)
const _default_discount_rates = [.025, .03, .05]            # used by MCS

# Roe and Baker climate sensitivity distribution file
const RBdistribution_file = joinpath(@__DIR__, "../../data/IWG_inputs/DICE/2009 11 23 Calibrated R&B distribution.xls")
const RB_cs_values = Vector{Float64}(readxl(RBdistribution_file, "Sheet1!A2:A1001")[:, 1])  # cs values
const RB_cs_probs  = Vector{Float64}(readxl(RBdistribution_file, "Sheet1!B2:B1001")[:, 1])  # probabilities associated with those values

#------------------------------------------------------------------------------
# 1. DICE specific constants
#------------------------------------------------------------------------------

const iwg_dice_input_file = joinpath(@__DIR__, "../../data/IWG_inputs/DICE/SCC_input_EMFscenarios.xls")

const dice_ts = 10                              # length of DICE timestep: 10 years
const dice_years = 2005:dice_ts:2405   # time dimension of the IWG's DICE model

const _default_dice_perturbation_years = collect(2005:dice_ts:2055)   # used by MCS for SCC calculations

# Input parameters from EPA's Matlab code
const H     = 2300       # Time horizon for calculating SCC [year]
const A0    = 0.0303220  # First period total factor productivity, from DICE2010
const gamma = 0.3        # Labor factor productivity, from DICE2010
const delta = 0.1        # Capital depreciation rate [yr^-1], from DICE2010
const s     = 0.23       # Approximate optimal savings in DICE2010 

const dice_inflate = 122.58 / 114.52 # World GDP inflator 2005 => 2007

const dice_scenario_convert = Dict{scenario_choice, String}(    # convert from standard names to the DICE-specific names used in the input files
    USG1 => "IMAGE",
    USG2 => "MERGEoptimistic",
    USG3 => "MESSAGE",
    USG4 => "MiniCAMbase",
    USG5 => "5thScenario"
)

#------------------------------------------------------------------------------
# 2. FUND specific constants
#------------------------------------------------------------------------------

const iwg_fund_datadir = joinpath(@__DIR__, "../../data/IWG_inputs/FUND/")    

const fund_inflator = 1.3839  # 1990(?)$ => 2007$

const fund_years = 1950:2300   # number of years to include for the SCC calculation, even though model is run to 3000

const _default_fund_perturbation_years = collect(2010:5:2050)

const fund_scenario_convert = Dict{scenario_choice, String}(    # convert from standard names to the FUND-specific names used in the input files
    USG1  => "IMAGE",
    USG2  => "MERGE Optimistic",
    USG3  => "MESSAGE",
    USG4  => "MiniCAM",
    USG5  => "Policy Level Average"
)

#------------------------------------------------------------------------------
# 3. PAGE specific constants 
#------------------------------------------------------------------------------

const iwg_page_datadir = joinpath(@__DIR__, "../../data/IWG_inputs/PAGE/")
const iwg_page_input_file = joinpath(iwg_page_datadir, "PAGE09 v1.7 SCCO2 (550 Avg, for 2013 SCC technical update - Input files).xlsx")   # One input file used for RB distribution in mcs

const page_years = [2010, 2020, 2030, 2040, 2050, 2060, 2080, 2100, 2200, 2300]

const page_inflator = 1.225784    # 2000 USD => 2007 USD

const _default_page_perturbation_years = collect(2010:5:2050)

# list of parameters that are different between the IWG scenarios
const page_scenario_specific_params = [
    "gdp_0",
    "grw_gdpgrowthrate",
    "GDP_per_cap_focus_0_FocusRegionEU",
    "pop0_initpopulation",
    "popgrw_populationgrowth",
    "e0_baselineCO2emissions",
    "e0_globalCO2emissions",
    "er_CO2emissionsgrowth",
    "f0_CO2baseforcing",
    "exf_excessforcing"
]

const page_scenario_convert = Dict{scenario_choice, String}(    # convert from standard names to the PAGE specific names used in the input files
    USG1  => "IMAGE",
    USG2  => "MERGE",
    USG3  => "MESSAGE",
    USG4  => "MiniCAM",
    USG5  => "550 Avg"
)

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

"""
connect_all!(m::Model, comps::Vector{Pair{Symobl, Symbol}}, src::Pair{Symbol, Symbol})
    helper function for connecting a list of (compname, paramname) pairs all to the same source pair
"""
function connect_all!(m::Model, comps::Vector{Pair{Symbol, Symbol}}, src::Pair{Symbol, Symbol})
    for dest in comps 
        connect_param!(m, dest, src)
    end
end
"""
connect_all!(m::Model, comps::Vector{Symbols}, src::Pair{Symbol, Symbol})
    helper function for connecting a list of compnames all to the same source pair. The parameter name in all the comps must be the same as in the src pair.
"""
function connect_all!(m::Model, comps::Vector{Symbol}, src::Pair{Symbol, Symbol})
    src_comp, param = src
    for comp in comps 
        connect_param!(m, comp=>param, src_comp=>param)
    end
end