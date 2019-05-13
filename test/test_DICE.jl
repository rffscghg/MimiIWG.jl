
@testset "DICE" begin

    # include("../src/MimiIWG.jl")

    @testset "API" begin

        m = get_model(DICE, scenarios[1])
        run(m)

        md = get_marginaldamages(DICE, scenarios[1])

        scc = get_scc(DICE, scenarios[1])

        tmp_dir = joinpath(@__DIR__, "tmp")
        run_scc_mcs(DICE, trials=2, output_dir = tmp_dir)
        rm(tmp_dir, recursive=true)

    end

    @testset "Deterministic SCC validation" begin 

        validation_file = joinpath(@__DIR__, "../data/validation/DICE/SCC_DICE2010_EPA_2018_12_18_12_56_deterministic.xlsx")
        f = openxl(validation_file)

        _atol = 1e-8

        for scenario in scenarios
            @testset "$(string(scenario))" begin 
                for discount in [0.025, 0.03, 0.05]
                    validation_data = readxl(f, "$(dice_scenario_convert[scenario])_$(discount)_2010-2050!A2:I2")
                    for (i, year) in enumerate(2010:5:2050)
                        iwg_scc = validation_data[i]
                        mimi_scc = get_scc(DICE, scenario; year=year, discount=discount)
                        # println(iwg_scc, ",", mimi_scc)
                        @test iwg_scc ≈ mimi_scc atol = _atol
                    end
                end
            end
        end

    end 

end