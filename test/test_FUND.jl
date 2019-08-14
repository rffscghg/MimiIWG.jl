using MimiIWG

@testset "FUND" begin 

    @testset "API" begin

        m = MimiIWG.get_model(FUND, MimiIWG.scenarios[1])
        run(m)

        md1 = MimiIWG.get_marginaldamages(FUND, MimiIWG.scenarios[1])
        md2 = MimiIWG.get_marginaldamages(FUND, MimiIWG.scenarios[1], regional = true)

        scc1 = MimiIWG.compute_scc(FUND, MimiIWG.scenarios[1])
        scc2 = MimiIWG.compute_scc(FUND, MimiIWG.scenarios[1], domestic = true)
        @test scc2 < scc1

        tmp_dir = joinpath(@__DIR__, "tmp")
        MimiIWG.run_scc_mcs(FUND, trials=2, output_dir = tmp_dir, domestic=true)
        rm(tmp_dir, recursive=true)
    end

end