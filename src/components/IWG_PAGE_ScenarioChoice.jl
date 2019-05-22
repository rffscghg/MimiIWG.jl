# This component holds data for all IWG scenarios in its parameters, and the `scenario_num` parameter specifies which scenario to use.
# During the first timestep, values for the specified scenario are copied into the variables.
# Functions for loading in the necessaring parameters are defined in src/core/PAGE_helper.jl
@defcomp IWG_PAGE_ScenarioChoice begin

    scenarios = Index()

    # Variables (each one has its value set for the chosen scenario in the first timestep)
    gdp_0 = Variable(index = [region], unit="\$M")
    grw_gdpgrowthrate = Variable(index = [time, region], unit = "%/year")
    GDP_per_cap_focus_0_FocusRegionEU = Variable(unit = "\$/person")
    pop0_initpopulation = Variable(index = [region], unit = "million person")
    popgrw_populationgrowth = Variable(index=[time, region], unit = "%/year")
    e0_baselineCO2emissions = Variable(index = [region], unit = "Mtonne/year") # also called AbatementCostsCO2_e0_baselineemissions and AbatementCostParametersCO2_e0_baselineemissions in two components
    e0_globalCO2emissions = Variable(unit = "Mtonne/year")
    er_CO2emissionsgrowth = Variable(index = [time, region], unit = "%") # also called AbatementCostsCO2_er_emissionsgrowth
    f0_CO2baseforcing = Variable(unit = "W/m2")
    exf_excessforcing = Variable(index = [time], unit = "W/m2")

    # The number for which scenario to use 
    scenario_num::Integer = Parameter(default = 0)

    # Parameters (each one holds all five scenarios)
    gdp_0_all = Parameter(index = [region, scenarios])
    grw_gdpgrowthrate_all = Parameter(index = [time, region, scenarios])
    GDP_per_cap_focus_0_FocusRegionEU_all = Parameter(index = [scenarios])
    pop0_initpopulation_all = Parameter(index = [region, scenarios])
    popgrw_populationgrowth_all = Parameter(index=[time, region, scenarios])
    e0_baselineCO2emissions_all = Parameter(index = [region, scenarios])     # also called AbatementCostsCO2_e0_baselineemissions and AbatementCostParametersCO2_e0_baselineemissions in two components
    e0_globalCO2emissions_all = Parameter(index = [scenarios])
    er_CO2emissionsgrowth_all = Parameter(index = [time, region, scenarios])      # also called AbatementCostsCO2_er_emissionsgrowth
    f0_CO2baseforcing_all = Parameter(index = [scenarios])
    exf_excessforcing_all = Parameter(index = [time, scenarios])

    function run_timestep(p, v, d, t)
        if is_first(t)
            # Get the specified scenario
            scenario_num = p.scenario_num
            if scenario_num == 0
                # @warn("scenario_num was not set in the IWG_PAGE_ScenarioChoice component. Will use average values of all five scenarios.")
                v.gdp_0[:] = dropdims(mean(p.gdp_0_all[:, :], dims=2), dims=2)
                v.grw_gdpgrowthrate[:, :] = dropdims(mean(p.grw_gdpgrowthrate_all[:, :, :], dims=3), dims=3)
                v.GDP_per_cap_focus_0_FocusRegionEU = mean(p.GDP_per_cap_focus_0_FocusRegionEU_all[:])
                v.pop0_initpopulation[:] = dropdims(mean(p.pop0_initpopulation_all[:, :], dims=2), dims=2)
                v.popgrw_populationgrowth[:, :] = dropdims(mean(p.popgrw_populationgrowth_all[:, :, :], dims=3), dims=3)
                v.e0_baselineCO2emissions[:] = dropdims(mean(p.e0_baselineCO2emissions_all[:, :], dims=2), dims=2)
                v.e0_globalCO2emissions = mean(p.e0_globalCO2emissions_all[:])
                v.er_CO2emissionsgrowth[:, :] = dropdims(mean(p.er_CO2emissionsgrowth_all[:, :, :], dims=3), dims=3)
                v.f0_CO2baseforcing = mean(p.f0_CO2baseforcing_all[:])
                v.exf_excessforcing[:] = dropdims(mean(p.exf_excessforcing_all[:, :], dims=2), dims=2)
            else
                # Copy over all of the values for that scenario
                v.gdp_0[:] = p.gdp_0_all[:, scenario_num]
                v.grw_gdpgrowthrate[:, :] = p.grw_gdpgrowthrate_all[:, :, scenario_num]
                v.GDP_per_cap_focus_0_FocusRegionEU = p.GDP_per_cap_focus_0_FocusRegionEU_all[scenario_num]
                v.pop0_initpopulation[:] = p.pop0_initpopulation_all[:, scenario_num]
                v.popgrw_populationgrowth[:, :] = p.popgrw_populationgrowth_all[:, :, scenario_num]
                v.e0_baselineCO2emissions[:] = p.e0_baselineCO2emissions_all[:, scenario_num] 
                v.e0_globalCO2emissions = p.e0_globalCO2emissions_all[scenario_num]
                v.er_CO2emissionsgrowth[:, :] = p.er_CO2emissionsgrowth_all[:, :, scenario_num]
                v.f0_CO2baseforcing = p.f0_CO2baseforcing_all[scenario_num]
                v.exf_excessforcing[:] = p.exf_excessforcing_all[:, scenario_num]
            end
        end
    end

end


