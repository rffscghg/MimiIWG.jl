
module MimiIWG

using Mimi
using MimiDICE2010
using MimiFUND          # pinned to version 3.8.2 in package registration Compat.toml
using MimiPAGE2009      
using ExcelReaders
using StatsBase
using Distributions
using Interpolations
using Dates
using DelimitedFiles

export get_model, get_marginaldamages, get_scc, run_scc_mcs, 
        DICE, FUND, PAGE, # export the enumerated model_choice options
        USG1, USG2, USG3, USG4, USG5 # export the enumerated scenario_choice options 

# General constants and functions
include("core/constants.jl")
include("core/utils.jl")

# IWG modified components
include("components/IWG_DICE_co2cycle.jl")
include("components/IWG_DICE_radiativeforcing.jl")
include("components/IWG_DICE_climatedynamics.jl")
include("components/IWG_DICE_neteconomy.jl")
include("components/IWG_FUND_impactsealevelrise.jl")
include("components/IWG_RoeBakerClimateSensitivity.jl")
include("components/IWG_PAGE_ClimateTemperature.jl")
include("components/IWG_PAGE_ScenarioChoice.jl")
include("components/IWG_PAGE_GDP.jl")

# Main models and functions
include("core/DICE_helper.jl")
include("core/FUND_helper.jl")
include("core/PAGE_helper.jl")
include("core/main.jl")

# Monte carlo support
include("montecarlo/DICE_mcs.jl")
include("montecarlo/FUND_mcs.jl")
include("montecarlo/PAGE_mcs.jl")
include("montecarlo/run_scc_mcs.jl")


end