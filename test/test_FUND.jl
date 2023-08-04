using DelimitedFiles
using MimiIWG
using Test

validation_dir = joinpath(@__DIR__, "../data/validation/FUND/usg 2013 fund deterministic run results/")
validation_files = readdir(validation_dir)  # separate file for each scenario and gas

_atol = 1e-3

@testset "FUND" begin 

    @testset "API" begin

        m = MimiIWG.get_model(FUND, MimiIWG.scenarios[1])
        run(m)

        md1 = MimiIWG.get_marginaldamages(FUND, MimiIWG.scenarios[1])
        md2 = MimiIWG.get_marginaldamages(FUND, MimiIWG.scenarios[1], regional = true)
        md3 = MimiIWG.get_marginaldamages(FUND, MimiIWG.scenarios[1], discount = 0.03)
    
        @test sum(md2, dims = 2)[2:end] ≈ md1[2:end] atol = 1e-12 # sum regional to global, skip missing first value
        @test sum(skipmissing(md3)) < sum(skipmissing(md1)) # discount of 0. v discount of 0.03
        
        scc1 = MimiIWG.compute_scc(FUND, MimiIWG.scenarios[1])
        scc2 = MimiIWG.compute_scc(FUND, MimiIWG.scenarios[1], domestic = true)
        @test scc2 < scc1  # test global SCC is larger than domestic SCC

        # Test monte carlo simulation runs without error
        # bug: a bug in VSCode makes this crash the terminal when run line by line
        tmp_dir = joinpath(@__DIR__, "tmp")
        MimiIWG.run_scc_mcs(FUND, gas=:CO2, trials=2, output_dir = tmp_dir, domestic=true)
        rm(tmp_dir, recursive=true)

        # make sure old and new discounting keyword args work
        scc_old = MimiIWG.compute_scc(FUND, USG1; gas=:CO2, year=2020, discount=0.025)
        scc_new = MimiIWG.compute_scc(FUND, USG1; gas=:CO2, year=2020, prtp=0.025)
        @test scc_old ≈ scc_new atol = 1e-12
    end

    # Test the deterministic (non Monte Carlo) results from a modal run of FUND against values from the EPA
    
    # Carbon dioxide
    @testset "Deterministic SC-CO2 validation" begin
        
        for scen in MimiIWG.scenarios
            @info("Testing FUND SC-CO2 $(MimiIWG.fund_scenario_convert[scen])...")
            file_idx = findfirst(x -> occursin("$(MimiIWG.fund_scenario_convert[scen]) - C", x), validation_files)
            scen_file = validation_files[file_idx]
            scen_validation_values = readdlm(joinpath(validation_dir, scen_file), ',')[3, 2:16]
        
            idx = 1
            for year in 2010:10:2050, dr in [0.025, 0.03, 0.05]
                mimi_scc = MimiIWG.compute_scc(FUND, scen, gas=:CO2, year=year, prtp=dr)
                iwg_scc = scen_validation_values[idx]
                @test mimi_scc ≈ iwg_scc atol = _atol
                idx += 1
            end
        end
    end

    # Methane
    @testset "Deterministic SC-CH4 validation" begin
    
        for scen in MimiIWG.scenarios
            @info("Testing FUND SC-CH4 $(MimiIWG.fund_scenario_convert[scen])...")
            file_idx = findfirst(x -> occursin("$(MimiIWG.fund_scenario_convert[scen]) - CH4", x), validation_files)
            scen_file = validation_files[file_idx]
            scen_validation_values = readdlm(joinpath(validation_dir, scen_file), ',')[3, 2:16]
        
            idx = 1
            for year in 2010:10:2050, dr in [0.025, 0.03, 0.05]
                mimi_scc = MimiIWG.compute_scc(FUND, scen, gas=:CH4, year=year, prtp=dr)
                iwg_scc = scen_validation_values[idx]
                @test mimi_scc ≈ iwg_scc atol = _atol
                idx += 1
            end
        end
    end

    # Nitrous oxide
    @testset "Deterministic SC-N2O validation" begin
    
        for scen in MimiIWG.scenarios
            @info("Testing FUND SC-N2O $(MimiIWG.fund_scenario_convert[scen])...")
            file_idx = findfirst(x -> occursin("$(MimiIWG.fund_scenario_convert[scen]) - N2O", x), validation_files)
            scen_file = validation_files[file_idx]
            scen_validation_values = readdlm(joinpath(validation_dir, scen_file), ',')[3, 2:16]
        
            idx = 1
            for year in 2010:10:2050, dr in [0.025, 0.03, 0.05]
                mimi_scc = MimiIWG.compute_scc(FUND, scen, gas=:N2O, year=year, prtp=dr)
                iwg_scc = scen_validation_values[idx]
                @test mimi_scc ≈ iwg_scc atol = 5.
                idx += 1
            end
        end
    end

    @testset "Deterministic SCC Options" begin 
        
       # basic option
       scc_base = MimiIWG.compute_scc(FUND, MimiIWG.USG1, prtp = 0.03, eta = 1., gas = :CO2, year = 2020)
       # equity weighting option, and normalized by the US
       scc_eq = MimiIWG.compute_scc(FUND, MimiIWG.USG1, prtp = 0.03, eta = 1., gas = :CO2, year = 2020, equity_weighting = true)
       scc_eq_norm = MimiIWG.compute_scc(FUND, MimiIWG.USG1, prtp = 0.03, eta  = 1., gas = :CO2, year = 2020, normalization_region = 1, equity_weighting = true)
       # domestic option
       scc_dom = MimiIWG.compute_scc(FUND, MimiIWG.USG1, prtp = 0.03, eta = 1., gas = :CO2, year = 2020, domestic = true)

        @test scc_eq < scc_eq_norm

        # test errors
        @test_throws ErrorException MimiIWG.compute_scc(FUND, MimiIWG.USG1, normalization_region = 1) # can't set norm region without equity weighitng
        @test_throws ErrorException MimiIWG.compute_scc(FUND, MimiIWG.USG1, equity_weighting = true, domestic = true) # can't have equity weighting with domestic
 
    end
end

