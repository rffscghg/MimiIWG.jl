using MimiIWG
using DelimitedFiles

@testset "PAGE" begin

@testset "API" begin

    m = MimiIWG.get_model(PAGE, MimiIWG.scenarios[1])
    run(m)

    md1 = MimiIWG.get_marginaldamages(PAGE, MimiIWG.scenarios[1])
    md2 = MimiIWG.get_marginaldamages(PAGE, MimiIWG.scenarios[1], regional = true)
    md3 = MimiIWG.get_marginaldamages(PAGE, MimiIWG.scenarios[1], discount = 0.03)

    @test sum(md2, dims = 2) ≈ md1 atol = 1e-12 # sum regional to global 
    @test sum(md3) < sum(md1) # discount of 0. v discount of 0.03

    scc1 = MimiIWG.compute_scc(PAGE, MimiIWG.scenarios[1])
    scc2 = MimiIWG.compute_scc(PAGE, MimiIWG.scenarios[1], domestic = true)
    @test scc2 < scc1  # test global SCC is larger than domestic SCC

    # # Test monte carlo simulation runs without error
    # # bug: a bug in VSCode makes this crash the terminal when run line by line
    # tmp_dir = joinpath(@__DIR__, "tmp")
    # MimiIWG.run_scc_mcs(PAGE, trials=2, output_dir = tmp_dir, domestic=true)
    # rm(tmp_dir, recursive=true)

    # # test the drop discontinuities flag set to `true`
    # tmp_dir = joinpath(@__DIR__, "tmp")
    # MimiIWG.run_scc_mcs(PAGE, trials=2, output_dir = tmp_dir, domestic=true, drop_discontinuities = true)
    # rm(tmp_dir, recursive=true)

    # make sure old and new discounting keyword args work
    scc_old = MimiIWG.compute_scc(PAGE, USG1; gas=:CO2, year=2020, discount=0.025)
    scc_new = MimiIWG.compute_scc(PAGE, USG1; gas=:CO2, year=2020, prtp=0.025)
    @test scc_old ≈ scc_new atol = 1e-12

end

@testset "Deterministic SCC validation" begin 

    validation_dir = joinpath(@__DIR__, "../data/validation/PAGE/deterministic")
    files = readdir(validation_dir)

    _atol = 0.01    # one cent

    scenario_convert_flip = Dict([v=>k for (k,v) in MimiIWG.page_scenario_convert]) # need to convert scenario names in the other direction from the validation data files

    for f in files
        validation_data = readdlm(joinpath(validation_dir, f), ',')
        scenario = String(split(f, ".")[1])

        @testset "$scenario" begin

            for line in 1:size(validation_data, 1)
                year        = Int(validation_data[line, 1])
                discount    = validation_data[line, 2]
                iwg_scc     = validation_data[line, 3] * MimiIWG.page_inflator     # 2000$ => $2007

                mimi_scc = MimiIWG.compute_scc(PAGE, scenario_convert_flip[scenario], year=year, prtp=discount)
                # println(iwg_scc, ",", mimi_scc)
                @test iwg_scc ≈ mimi_scc atol = _atol
            end
        end
    end 

    @testset "Deterministic SCC Options" begin 
        
        scc2 = MimiIWG.compute_scc(PAGE, MimiIWG.USG1, prtp = 0.03, eta = 1., gas = :CO2, year = 2020, domestic = true)
        scc3 = MimiIWG.compute_scc(PAGE, MimiIWG.USG1, prtp = 0.03, eta = 1., gas = :CO2, year = 2020, domestic = true, equity_weighting = true)
        @test scc2 ==  scc3 # no difference for equity weighting since domestic - TODO is this right (ask David)

        @test_throws ErrorException MimiIWG.compute_scc(PAGE, MimiIWG.USG1, normalization_region = 1) # can't set norm region without equity weighitng
        scc4 = MimiIWG.compute_scc(PAGE, MimiIWG.USG1, eta = 1., normalization_region = 1, equity_weighting = true) # normalize by US
        scc5 = MimiIWG.compute_scc(PAGE, MimiIWG.USG1, eta = 1., equity_weighting = true)
        @test scc4 < scc5

    end

end 

end