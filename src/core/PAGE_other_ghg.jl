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

# Exogenous HFC marginal forcing pathways

_page_hfc_rf_data = joinpath(@__DIR__, "..\\..\\data\\ghg_radiative_forcing_perturbation.csv")
# _page_hfc_rf_data = joinpath(@__DIR__, "data\\ghg_radiative_forcing_perturbation.csv")
_page_hfc_rf = DataFrame(load(_page_hfc_rf_data))

# Pulse years Dict -- used for averaging
years_dict = Dict()
years_dict[2020] = collect(2020:1:2029)
years_dict[2030] = collect(2030:1:2039)
years_dict[2040] = collect(2040:1:2049)
years_dict[2050] = collect(2050:1:2059)
years_dict[2060] = collect(2060:1:2079)
years_dict[2080] = collect(2080:1:2099)
years_dict[2100] = collect(2100:1:2199)
years_dict[2200] = collect(2200:1:2299)
years_dict[2300] = collect(2300:1:2300)

function _get_hfc_marginal_forcings(gas::Symbol, year::Int)
    # Create subset of dataframe with all rfs for the chosen gas
    HFC_df = @from i in _page_hfc_rf begin
        @where i.ghg .== string(gas)
        @select {i.rf}
        @collect DataFrame
    end

    years_index = collect(year:(year + 300 - 1)) # 300 is the number of years for which we have the rf data for each HFC
    insertcols!(HFC_df, 2, :years_index => years_index)

    pulse_years = append!(collect(year:10:2060), [2080, 2100, 2200, 2300]) ## note: written like this, i think that PAGE will only work for pulse years 2020:10:2060
    
    ## AVERAGING METHOD
    average_rf = DataFrame(year = page_years, avg_rf = zeros(length(page_years)))
    # Select rfs to take the average of
    for x in 1:length(pulse_years)
        years_tmp = years_dict[pulse_years[x]] # selects rfs according to PAGE periods
        # years_tmp = pulse_years[x]:pulse_years[x]+9 # selects the pulse year rf and the 9 years after it
        rfs_tmp = @from i in HFC_df begin
            @where i.years_index in years_tmp
            @select {i.rf}
            @collect DataFrame
        end
        
        # Take the average of the rfs for each 10-year period
        j = length(page_years) - length(pulse_years) + x # create index j that only selects years starting from the pulse year (so that rfs for the years before the pulse year will remain as 0.0 in the table)
        average_rf.avg_rf[j] = mean(rfs_tmp.rf) # replace jth value (corresponding to the rf for the pulse year) with the mean for the following 10 years
    end
    
    return convert(Vector{Float64}, average_rf.avg_rf)

#     ## USING DISCRETE PULSE YEAR RFS (NO AVERAGING)
#     marginal_rfs = DataFrame(year = page_years, rf = zeros(length(page_years)))
    
#     for x in 1:length(pulse_years)
#         rfs_tmp = @from i in HFC_df begin
#             @where i.years_index .== pulse_years[x]
#             @select {i.rf}
#             @collect DataFrame
#         end
    
#         j = length(page_years) - length(pulse_years) + x # create index j that only selects years starting from the pulse year (so that rfs for the years before the pulse year will remain as 0.0 in the table)
#         marginal_rfs.rf[j] = rfs_tmp.rf[1]
#     end
    
#     return convert(Vector{Float64}, marginal_rfs.rf)
end

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
    elseif gas in HFC_list # see constants.jl for HFC_list
        _get_hfc_marginal_forcings(gas, year)
    else
        error("Unknown gas :$gas.")
    end
end