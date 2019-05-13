
@testset "FUND" begin 

    @testset "API" begin

        m = get_model(FUND, MimiIWG.scenarios[1])
        run(m)

        md = get_marginaldamages(FUND, MimiIWG.scenarios[1])

        scc = get_scc(FUND, MimiIWG.scenarios[1])

        tmp_dir = joinpath(@__DIR__, "tmp")
        run_scc_mcs(FUND, trials=2, output_dir = tmp_dir, domestic=true)
        rm(tmp_dir, recursive=true)
    end

end