# MimiIWG

This repository contains code replicating the models used by the EPA's Interagency Work Group (IWG) on the Social Cost of Carbon. The IWG used three integrated assessment models for calculating the social cost of carbon:
- DICE 2010 (originally written in Excel and GAMS; re-written in Matlab by the IWG)
- FUND 3.8 (originally written in C#)
- PAGE 2009 (originally written in Excel with the @RISK package)

This project replicates the versions of these models used by the IWG in the Julia programming language, using the Julia package for Integrated Assesment Modeling, Mimi.jl. For more information on Mimi and its applications, visit the [Mimi Framework website](https://www.mimiframework.org/). For more information on Julia, documentation can be found [here](https://docs.julialang.org/en/v1/).

## Project Overview

### Getting set up

To get started, you will need to download Julia version 1.1 [here](https://julialang.org/downloads/).

Download this project code using git:
```
git clone "https://github.com/ckingdon95/MimiIWG2016"
```
Begin an interactive Julia session. First, navigate into the folder on your computer for this project code:
```
julia> cd("/pathtocode/MimiIWG2016")
```
Enter the Package REPL by typing "]"
```
julia> ]
```
Then in the package REPL activate the Julia environment for this project with the following commands. This will download and install all of the necessary package dependencies, including Mimi and the original versions of the models.
```
pkg> activate .
pkg> instantiate
```
Type a `backspace` to exit the package REPL and get back to the interactive Julia environment.
To begin using this project, execute:
```
include("src/MimiIWG2016.jl")
```

### API

The main available functions are:
- `get_model(MODEL_NAME, SCENARIO_CHOICE)`

- `get_marginaldamages(MODEL_NAME, SCENARIO_CHOICE, year=2020, discount=0)`

- `get_scc(MODEL_NAME, SCENARIO_CHOICE, year, discount)`

- `run_scc_mcs(MODEL_NAME; trials=10000, perturbation_years=2010:5:2050, discount_rates=[0.025, 0.03, 0.05])`

The choices for MODEL_NAME are DICE, FUND, or PAGE.

The choices for SCENARIO_CHOICE are USG1, USG2, USG3, USG4, and USG5. For more information on these scenarios, see below.

For example uses of the code, see "scripts/example.jl".

### Monte Carlo simulations

To run the same suite of Monte Carlo simulations that the IWG used for estimating the Social Cost of Carbon, see "scripts/main.jl".

## Documentation of the modifications made by the IWG

### Socioeconomics scenarios
The IWG ran a standardized set of socioeconomic scenarios as inputs to each of the three models. The longer names associated with the five scenarios are:

- USG1: "IMAGE"
- USG2: "MERGE Optimistic"
- USG3: "MESSAGE"
- USG4: "MiniCAM Base"
- USG5: "5th Scenario"

The first four scenarios were based on an Energy Modeling Forum (EMF 22), and the 5th scenario was cosntructed to represent a future where CO2 concentration in the atmosphere stays below 550ppm.

### Roe and Baker climate sensitivity distribution

The Monte Carlo simulations for all three models sampled equilibrium climate sensitivity values from the Roe and Baker distribution.

### DICE notes

The package repository for the original version of MimiDICE2010 is [here](https://github.com/anthofflab/MimiDICE2010.jl).

The main changes made by the IWG to DICE2010, reflected in this project code are:
- The use of the five USG economic scenarios
- Sampling from the Roe and Baker climate sensitivity distribution
- They ran it out to 2405, but only values up to 2300 are used for SCC. Socioeconomics values drop to zero after 2300, so values of all variables beyond that year are nonsensicle.
- further description coming soon. 

### FUND notes

The package repository for the original version of MimiFUND is [here](https://github.com/fund-model/MimiFUND.jl/tree/release-3.8). Note that the IWG uses an older version, version 3.8.

The main changes made by the IWG to FUND3.8, reflected in this project code are:
- The use of the five USG economic scenarios
- Sampling from the Roe and Baker climate sensitivity distribution
- further description coming soon. 

### PAGE notes

The package repository for the original version of MimiPAGE2009 is [here](https://github.com/anthofflab/MimiPAGE2009.jl).

The main changes made by the IWG to PAGE2009, reflected in this project code are:
- The use of the five USG economic scenarios
- Sampling from the Roe and Baker climate sensitivity distribution
- further description coming soon. 