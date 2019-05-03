
@testset "DICE" begin

    include("../src/MimiIWG2016.jl")

    @testset "API" begin

        m = get_model(DICE, scenario_names[1])
        run(m)

        # run_scc_mcs(DICE, trials=2)

    end

    @testset "Deterministic SCC validation" begin 

        validation_file = joinpath(@__DIR__, "../data/validation/DICE/SCC_DICE2010_EPA_2018_12_18_12_56_deterministic.xlsx")
        f = openxl(validation_file)

        _atol = 1e-8

        for scenario in scenario_names
            @testset "$scenario" begin 
                for discount in [0.025, 0.03, 0.05]
                    validation_data = readxl(f, "$(dice_scenario_convert[scenario])_$(discount)_2010-2050!A2:I2")
                    for (i, year) in enumerate(2010:5:2050)
                        iwg_scc = validation_data[i]
                        mimi_scc = get_scc(DICE, scenario, year, discount)
                        # println(iwg_scc, ",", mimi_scc)
                        @test iwg_scc ≈ mimi_scc atol = _atol
                    end
                end
            end
        end

    end 

end