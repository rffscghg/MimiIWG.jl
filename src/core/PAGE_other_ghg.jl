# Exogenous PAGE marginal forcing pathways from Marten et al 2014

_page_perturbation_data_file = joinpath(@__DIR__, "../../data/IWG_inputs/PAGE/Non-co2 perturbation data - 1 Mt.xlsx")
_page_f = openxl(_page_perturbation_data_file)

_page_ch4_shocks = Dict()
_page_ch4_shocks[2010] = readxl(_page_f, "Sheet1!I4:M13")
_page_ch4_shocks[2020] = readxl(_page_f, "Sheet1!P4:T13")
_page_ch4_shocks[2030] = readxl(_page_f, "Sheet1!W4:AA13")
_page_ch4_shocks[2040] = readxl(_page_f, "Sheet1!AD4:AH13")
_page_ch4_shocks[2050] = readxl(_page_f, "Sheet1!AK4:AO13")

_page_n2o_shocks = Dict()
_page_n2o_shocks[2010] = readxl(_page_f, "Sheet1!I18:M27")
_page_n2o_shocks[2020] = readxl(_page_f, "Sheet1!P18:T27")
_page_n2o_shocks[2030] = readxl(_page_f, "Sheet1!W18:AA27")
_page_n2o_shocks[2040] = readxl(_page_f, "Sheet1!AD18:AH27")
_page_n2o_shocks[2050] = readxl(_page_f, "Sheet1!AK18:AO27")


function _get_page_forcing_shock(scenario_num::Int, gas::Symbol, year::Int)
    if gas == :CH4
        return convert(Vector{Float64}, _page_ch4_shocks[year][:, scenario_num])
    elseif gas == :N2O
        return convert(Vector{Float64}, _page_n2o_shocks[year][:, scenario_num])
    else
        error("Unknown gas :$gas.")
    end
end