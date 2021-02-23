
## CH4 and N2O emissions
other_GHG_input_file = joinpath(@__DIR__, "../../data/IWG_inputs/DICE/CH4N20emissions_annualversion.xls")
f = openxl(other_GHG_input_file)

dice_annual_years = Vector{Int}(readxl(f, "CH4annual!A2:A301")[:])
decades = dice_annual_years[1]:10:dice_annual_years[end]-9
E_CH4A_all = readxl(f, "CH4annual!B2:F301")
E_N2OA_all = readxl(f, "N20annual!B2:F301")

function _get_marginal_gas_model(scenario_num::Int, gas::Symbol, year::Int)

    year in dice_annual_years || error("Invalid year $year. Must be within $(dice_annual_years[1])-$(dice_annual_years[end]).")
    year_index = findfirst(isequal(year), dice_annual_years)

    m = Model()
    set_dimension!(m, :time, dice_annual_years)
    set_dimension!(m, :decades, decades)
    add_comp!(m, IWG_DICE_simple_gas_cycle, :gas)
    set_param!(m, :gas, :E_CH4A, E_CH4A_all[:, scenario_num])
    set_param!(m, :gas, :E_N2OA, E_N2OA_all[:, scenario_num])

    mm = create_marginal_model(m)

    m2 = mm.modified
    if gas == :CH4
        pulse_E = E_CH4A_all[:, scenario_num]
        pulse_E[year_index] = pulse_E[year_index] + 1.
        update_param!(m2, :E_CH4A, pulse_E)
    elseif gas == :N2O
        pulse_E = E_N2OA_all[:, scenario_num]
        pulse_E[year_index] = pulse_E[year_index] + 1.
        update_param!(m2, :E_N2OA, pulse_E)
    end

    return mm
end

## HFC forcings
hfc_rf_data = joinpath(@__DIR__, "..\\..\\data\\ghg_radiative_forcing_perturbation.csv")
# hfc_rf_data = joinpath(@__DIR__, "data\\ghg_radiative_forcing_perturbation.csv")
hfc_rf_df = DataFrame(load(hfc_rf_data))

# using CSVFiles, DataFrames, Query, Statistics

function _get_dice_additional_forcing(scenario_num::Int, gas::Symbol, year::Int)

    if gas in [:CH4, :N2O]
        mm = _get_marginal_gas_model(scenario_num, gas, year)
        run(mm)

        if gas == :CH4
            return mm[:gas, :F_CH4] # returns a vector of length 30, guessing it corresponds to decadal forcings for 2005-2295. if year = 2005 or 2010, there is a non-zero first value. 2015-2020, first value is zero. 2025, first two values are zero, etc. But it returns a different number for 2020 vs 2021
        elseif gas == :N2O
            return mm[:gas, :F_N2O]
        end
    elseif gas in HFC_list
        HFC_df = @from i in hfc_rf_df begin
            @where i.ghg .== string(gas)
            @select {i.rf}
            @collect DataFrame
        end

        years_index = collect(year:(year + 300 - 1)) # 300 is the number of years for which we have the rf data for each HFC
        insertcols!(HFC_df, 2, :years_index => years_index)

        pulse_years = collect(year:10:2304)
        dice_years = collect(2005:10:2295)
        average_rf = DataFrame(year = dice_years, avg_rf = zeros(length(dice_years)))

        # Select rfs for the 10 year period after each pulse
        for i in 1:length(pulse_years)
            years_tmp = pulse_years[i]:pulse_years[i]+9 # can edit this as needed to select the appropriate years
            rfs_tmp = @from i in HFC_df begin
                @where i.years_index in years_tmp
                @select {i.rf}
                @collect DataFrame
            end
            
            # Take the average of the rfs for each 10-year period
            j = length(dice_years) - length(pulse_years) + i # create index j that only selects years starting from the pulse year (so that rfs for the years before the pulse year will remain as 0.0 in the table)
            average_rf.avg_rf[j] = mean(rfs_tmp.rf) # replace jth value (corresponding to the rf for the pulse year) with the mean for the following 10 years
        end
        
        return convert(Vector{Float64}, average_rf.avg_rf)

    else
        error("Unknown gas :$gas.")
    end

end
