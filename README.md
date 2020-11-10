# MimiIWG

This package contains code replicating the models used by the EPA's Interagency Work Group (IWG) on the Social Cost of Carbon. The IWG used three integrated assessment models for calculating the social cost of carbon:
- DICE 2010 (originally written in Excel and GAMS; re-written in Matlab by the IWG)
- FUND 3.8 (originally written in C#)
- PAGE 2009 (originally written in Excel with the @RISK package)

This package replicates the versions of these models used by the IWG in the Julia programming language, using the Julia package for Integrated Assesment Modeling, Mimi.jl. For more information on Mimi and its applications, visit the [Mimi Framework website](https://www.mimiframework.org/). For more information on Julia, documentation can be found [here](https://docs.julialang.org/en/v1/).

## Project Overview

### Getting set up

It is highly recommended to use the Julia package management system to download this package code rather than cloning through github.
To get started, you will need to download Julia version 1.1 [here](https://julialang.org/downloads/).

Begin an interactive Julia session and enter the Package REPL by typing "]"
```
julia> ]
```
Next you will need to add the [MimiRegistry](https://github.com/mimiframework/MimiRegistry), which is a custom Julia package regsitry of integrated assessment models that use Mimi.jl. Then you will be able to add the MimiIWG package. In the package REPL, do the following:
```
pkg> registry add https://github.com/mimiframework/MimiRegistry.git
pkg> add MimiIWG
```
Type a `backspace` to exit the package REPL and get back to the interactive Julia environment.
To begin using this project, execute:
```
julia> using MimiIWG
```

### API

The main available functions are:
- `MimiIWG.get_model(MODEL_NAME, SCENARIO_CHOICE)`

- `MimiIWG.get_marginaldamages(MODEL_NAME, SCENARIO_CHOICE, gas=:CO2, year=2020, discount=0)`

- `MimiIWG.compute_scc(MODEL_NAME, SCENARIO_CHOICE, gas=:CO2, year=2020, discount=0.03)`

- `MimiIWG.run_scc_mcs(MODEL_NAME; gas=:CO2, trials=10000, perturbation_years=2010:5:2050, discount_rates=[0.025, 0.03, 0.05])`

The choices for `MODEL_NAME` are `DICE`, `FUND`, or `PAGE`.

The choices for `SCENARIO_CHOICE` are `USG1`, `USG2`, `USG3`, `USG4`, and `USG5`. For more information on these scenarios, see below.

For example uses of the code, see "scripts/example.jl".

### Monte Carlo simulations

To run the same suite of Monte Carlo simulations that the IWG used for estimating the Social Cost of Carbon, see "scripts/main.jl".

The first argument to `MimiIWG.run_scc_mcs` must be the name of one of the three models, `DICE`, `FUND`, or `PAGE`. After that, there are several keyword arguments to choose from. The following list describes these arguments and their default values if the user does not specifiy them.
```
MimiIWG.run_scc_mcs(MODEL,
    gas = :CO2,     # specify the greenhouse gas. :CH4 and :N2O also available
    trials = 10000,  # the size of the Monte Carlo sample
    perturbation_years = 2010:5:2050,  # List of years for which to calculate the SCC
    discount_rates = [0.025, 0.03, 0.05],  # List of discount rates for which to calculate the SCC
    domestic = false,  # Whether to calculate domestic SCC values, in addition to calculating the global values
    output_dir = nothing,  # Output directory. If unspecified, a directory with the following name will be created: "output/MODEL yyyy-mm-dd HH-MM-SS SCC MC#trials"
    save_trials = false,   # Whether to save all of the input data sampled for each trial of the Monte Carlo Simulation. If true, values get saved to "output_dir/trials.csv"
    tables = true   # Whether to save a series of summary tables in the output folder; these include statistics such as percentiles and std errors of the SCC values.
)
```
Note that the Monte Carlo Simulations are run across all five of the USG socioeconomics scenarios.

## Summary of modifications made by the IWG

### Socioeconomics scenarios
The IWG ran a standardized set of five socioeconomic scenarios as inputs to each of the three models. Each scenario has a deterministic path for population, GDP, CO2 emissions, and other radiative forcings. The longer names associated with the five scenarios are:

- `USG1`: "IMAGE"
- `USG2`: "MERGE Optimistic"
- `USG3`: "MESSAGE"
- `USG4`: "MiniCAM Base"
- `USG5`: "5th Scenario"

The first four scenarios were based on an Energy Modeling Forum (EMF 22), and the 5th scenario was constructed to represent a future where CO2 concentration in the atmosphere stays below 550ppm. The original EMF scenarios only extended to the year 2100, so in order to run the models out to 2300, the IWG had to use the following assumptions to extend these scenarios:
- Population growth rate declines linearly, reaching zero in the year 2200
- GDP per capita growth rate declines linearly, reaching zero in the year 2300
- The decline in the fossil and industrial carbon intensity (CO2/GDP) growth rate over 2090-2100 is maintained from 2100 through 2300
- Net land use CO2 emissions decline linearly, reaching zero in the year 2200
- Non-CO2 radiative forcing remains constant after 2100

### Roe and Baker climate sensitivity distribution

The Monte Carlo simulations for all three models sample values for equilibrium climate sensitivity from the Roe and Baker distribution.
To view the shape of this distribution, try the following:
```
using Plots
plot(MimiIWG.RB_cs_values, MimiIWG.RB_cs_probs)
```
These data are also available as an Excel file in "MimiIWG/data/IWG_inputs/DICE/2009 11 23 Calibrated R&B distribution.xls".

### DICE notes

The package repository for the original version of MimiDICE2010 is [here](https://github.com/anthofflab/MimiDICE2010.jl).

The main changes made by the IWG to DICE2010, reflected in this project code are:
- The time index: the original DICE 2010 is run on ten year timesteps from 2005 to 2595. The IWG ran it only out to 2405, but only values up to 2300 are used for SCC. Socioeconomics values drop to zero after 2300, so values of all variables calculated after the 2295 timestep in this version are nonsensical.
- In order to use the 5 USG socioeconomics scenarios for DICE, the IWG had to calculate the path of exogenous technical change and capital stock implied by the GDP and population levels for each scenario, since those are the actual parameters that are used as inputs in DICE. 
- Since they sampled from the Roe and Baker distribution for values of equilibrium climate sensitivity, they had to add in an additional catch statement to the temperature calculation in DICE for extremely low (less than 0.5) values (this is reflected in the component definition in "src/components/IWG_DICE_climatedynamics.jl").
- In the original version of DICE, emissions are calculated endogenously. This emissions component has been removed, and instead the exogenous pathways from the USG socioeconomics scenarios are used and fed into DICE's CO2 cycle component.
- In the CO2 cycle component, an important difference is that the values of E in the original DICE represent GtCO2 per year, whereas the data used by the IWG are in units of GtCO2 per decade.

### FUND notes

The package repository for the original version of MimiFUND is [here](https://github.com/fund-model/MimiFUND.jl/tree/release-3.8). Note that the IWG uses an older version, version 3.8.

The main changes made by the IWG to FUND3.8, reflected in this project code are:
- The time index: while FUND can be run out to the year 3000, the IWG only used values out to 2300 for calculating the SCC. Unchanged from the original version, the start year is 1950. 
- The use of the five USG socioeconomic scenarios
- Sampling from the Roe and Baker climate sensitivity distribution 
- There is a change in the ImpactSeaLevelRise component, where the calculation of the `drycost` variable includes an additional parameter `protlevel`. This is reflected in "src/components/IWG_FUND_impactsealevelrise.jl"/

### PAGE notes

The package repository for the original version of MimiPAGE2009 is [here](https://github.com/anthofflab/MimiPAGE2009.jl).

The main changes made by the IWG to PAGE2009, reflected in this project code are:
- The time index: the original version of PAGE 2009 is run on timesteps of [2009, 2010, 2020, 2030, 2040, 2050, 2075, 2100, 2150, 2200]. The IWG changed this time index to [2010, 2020, 2030, 2040, 2050, 2060, 2080, 2100, 2200, 2300].
- The use of the five USG socioeconomic scenarios
- In the original version of PAGE 2009, equilibrium climate sensitivity is calculated endogenously based on values for transient climate sensitivity. The IWG changed this, and instead sampled values for ECS directly from the Roe and Baker distribution. 
- In the original Monte Carlo simulation for PAGE, values are sampled for the `ptp_timepreference parameter` parameter, but the IWG used constant discounting so this value is explicitly set for the different discount rates used and is not sampled during the Monte Carlo simulation in this package. The `emuc_utilityconvexity` parameter is also not sampled in this version, and is always set to zero, because the IWG only used constant pure rate of time preference discounting with no equity weighting.
