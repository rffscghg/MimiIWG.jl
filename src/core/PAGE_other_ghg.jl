# Exogenous PAGE marginal forcing pathways from Marten et al 2014

_page_perturbation_data_file = joinpath(@__DIR__, "../../data/IWG_inputs/PAGE/Non-co2 perturbation data - 1 Mt.xlsx")
_page_xf = readxlsx(_page_perturbation_data_file)

_page_ch4_shocks = Dict()
_page_ch4_shocks[2010] = _page_xf["Sheet1"]["I4:M13"]
_page_ch4_shocks[2020] = _page_xf["Sheet1"]["P4:T13"]
_page_ch4_shocks[2030] = _page_xf["Sheet1"]["W4:AA13"]
_page_ch4_shocks[2040] = _page_xf["Sheet1"]["AD4:AH13"]
_page_ch4_shocks[2050] = _page_xf["Sheet1"]["AK4:AO13"]
_page_ch4_shocks[2060] = _page_xf["Sheet1"]["AR4:AV13"]

_page_n2o_shocks = Dict()
_page_n2o_shocks[2010] = _page_xf["Sheet1"]["I18:M27"]
_page_n2o_shocks[2020] = _page_xf["Sheet1"]["P18:T27"]
_page_n2o_shocks[2030] = _page_xf["Sheet1"]["W18:AA27"]
_page_n2o_shocks[2040] = _page_xf["Sheet1"]["AD18:AH27"]
_page_n2o_shocks[2050] = _page_xf["Sheet1"]["AK18:AO27"]
_page_n2o_shocks[2060] = _page_xf["Sheet1"]["AR18:AV27"]

_page_hfc23_shocks = Dict()
_page_hfc23_shocks[2010] = _page_xf["Sheet1"]["I32:M41"]
_page_hfc23_shocks[2020] = _page_xf["Sheet1"]["P32:T41"]
_page_hfc23_shocks[2030] = _page_xf["Sheet1"]["W32:AA41"]
_page_hfc23_shocks[2040] = _page_xf["Sheet1"]["AD32:AH41"]
_page_hfc23_shocks[2050] = _page_xf["Sheet1"]["AK32:AO41"]
_page_hfc23_shocks[2060] = _page_xf["Sheet1"]["AR32:AV41"]

function _get_page_forcing_shock(scenario_num::Int, gas::Symbol, year::Int)
    if scenario_num == 1
        col_num = 1
    elseif scenario_num == 2
        col_num = 4     # MERGE data is in the 4th column of Marten et al input file
    elseif scenario_num == 3
        col_num = 2     # MESSAGE is in the second column
    elseif scenario_num == 4
        col_num = 3     # MiniCAM is in the third column
    elseif scenario_num == 5
        col_num = 5
    end

    if gas == :CH4
        return convert(Vector{Float64}, _page_ch4_shocks[year][:, col_num])
    elseif gas == :N2O
        return convert(Vector{Float64}, _page_n2o_shocks[year][:, col_num])
    elseif gas == :HFC23
        return convert(Vector{Float64}, _page_hfc23_shocks[year][:, col_num])
    else
        error("Unknown gas :$gas.")
    end
end
