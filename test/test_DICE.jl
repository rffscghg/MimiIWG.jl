using MimiIWG
using ExcelReaders

@testset "DICE" begin

    @testset "API" begin

        m = MimiIWG.get_model(DICE, MimiIWG.scenarios[1])
        run(m)

        md = MimiIWG.get_marginaldamages(DICE, MimiIWG.scenarios[1])

        scc1 = MimiIWG.compute_scc(DICE, MimiIWG.scenarios[1])
        scc2 = MimiIWG.compute_scc(DICE, MimiIWG.scenarios[1], domestic = true)
        @test scc2 == 0.1 * scc1

        tmp_dir = joinpath(@__DIR__, "tmp")
        MimiIWG.run_scc_mcs(DICE, trials=2, output_dir = tmp_dir, domestic = true)
        rm(tmp_dir, recursive=true)

    end

    @testset "Deterministic SCC validation" begin 

        validation_file = joinpath(@__DIR__, "../data/validation/DICE/SCC_DICE2010_EPA_2018_12_18_12_56_deterministic.xlsx")
        f = openxl(validation_file)

        _atol = 1e-8

        for scenario in MimiIWG.scenarios
            @testset "$(string(scenario))" begin 
                for discount in [0.025, 0.03, 0.05]
                    validation_data = readxl(f, "$(MimiIWG.dice_scenario_convert[scenario])_$(discount)_2010-2050!A2:I2")
                    for (i, year) in enumerate(2010:5:2050)
                        iwg_scc = validation_data[i]
                        mimi_scc = MimiIWG.compute_scc(DICE, scenario; year=year, discount=discount)
                        # println(iwg_scc, ",", mimi_scc)
                        @test iwg_scc ≈ mimi_scc atol = _atol
                    end
                end
            end
        end

    end 

end