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

# _page_hfc23_shocks = Dict()
# _page_hfc23_shocks[2010] = _page_xf["Sheet1"]["I32:M41"]
# _page_hfc23_shocks[2020] = _page_xf["Sheet1"]["P32:T41"]
# _page_hfc23_shocks[2030] = _page_xf["Sheet1"]["W32:AA41"]
# _page_hfc23_shocks[2040] = _page_xf["Sheet1"]["AD32:AH41"]
# _page_hfc23_shocks[2050] = _page_xf["Sheet1"]["AK32:AO41"]
# _page_hfc23_shocks[2060] = _page_xf["Sheet1"]["AR32:AV41"]


using CSV, DataFrames, Query, Statistics

_page_hfc_rf_data = joinpath(@__DIR__, "data\\ghg_radiative_forcing_perturbation.csv")
_page_hfc_rf = CSV.read(_page_hfc_rf_data, DataFrame)

function _get_hfc_marginal_forcings(gas::Symbol, year::Int)
    HFC_df = @from i in _page_hfc_rf begin
        @where i.ghg .== gas
        @select {i.rf}
        @collect DataFrame
    end

    years_index = collect(year:(year + 300 - 1)) # 300 is the number of years for which we have the rf data for each HFC
    insertcols!(HFC_df, 2, :years_index => years_index)

    pulse_years = append!(collect(year:10:2060), [2080, 2100, 2200, 2300])
    average_rf = DataFrame(year = page_years, avg_rf = zeros(length(page_years)))

    for i in 1:length(pulse_years)
        years_tmp = pulse_years[i]:pulse_years[i]+9
        rfs_tmp = @from i in HFC_df begin
            @where i.years_index in years_tmp
            @select {i.rf}
            @collect DataFrame
        end
    
        j = length(page_years) - length(pulse_years) + i
        average_rf.avg_rf[j] = mean(rfs_tmp.rf)
    end
    
    return convert(Vector{Float64}, average_rf.avg_rf)

end

# gas = "HFC32"

# HFC_df = DataFrame(@from i in _page_hfc_rf begin
#     @where i.ghg .== gas
#     @select {i.rf}
# end)

# year = 2020
# years_index = collect(year:(year + 300 - 1)) # 300 is the number of years for which we have the rf data for each HFC

# insertcols!(HFC_df, 2, :years_index => years_index)

# pulse_years = append!(collect(year:10:2060), [2080, 2100, 2200, 2300])
# average_rf = DataFrame(year = page_years, avg_rf = zeros(length(page_years)))

# const page_years = [2010, 2020, 2030, 2040, 2050, 2060, 2080, 2100, 2200, 2300]

# for i in 1:length(pulse_years)
#     years_tmp = pulse_years[i]:pulse_years[i]+9
#     rfs_tmp = @from i in HFC_df begin
#         @where i.years_index in years_tmp
#         @select {i.rf}
#         @collect DataFrame
#     end

#     j = length(page_years) - length(pulse_years) + i
#     average_rf.avg_rf[j] = mean(rfs_tmp.rf)
# end

# average_rf.avg_rf

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
        _get_hfc_marginal_forcings(gas, year)
        # HFC = "HFC-23"
        # HFC_df = DataFrame(@from i in _page_hfc_rf begin
        #     @where i.ghg .== HFC
        #     @select {i.rf}
        # end)
        # years_index = collect(year:(year + 300 - 1)) # 300 is the number of years for which we have the rf data for each HFC
        # insertcols!(HFC_df, 2, :years_index => years_index)
        # pulse_years = append!(collect(year:10:2060), [2080, 2100, 2200, 2300])
        # average_rf = DataFrame(year = page_years, avg_rf = zeros(length(page_years)))
        # for i in 1:length(pulse_years)
        #     years_tmp = pulse_years[i]:pulse_years[i]+9
        #     rfs_tmp = @from i in HFC_df begin
        #         @where i.years_index in years_tmp
        #         @select {i.rf}
        #         @collect DataFrame
        #     end
        #     j = length(page_years) - length(pulse_years) + i
        #     average_rf.avg_rf[j] = mean(rfs_tmp.rf)
        # end
        # return convert(Vector{Float64}, average_rf.avg_rf)
    elseif gas == :HFC32
        _get_hfc_marginal_forcings(gas, year)
    else
        error("Unknown gas :$gas.")
    end
end
