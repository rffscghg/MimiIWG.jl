
@testset "FUND" begin 

    # include("../src/MimiIWG.jl")

    @testset "API" begin

        m = get_model(FUND, scenarios[1])
        run(m)

        md = get_marginaldamages(FUND, scenarios[1])

        scc = get_scc(FUND, scenarios[1])

        tmp_dir = joinpath(@__DIR__, "tmp")
        run_scc_mcs(FUND, trials=2, output_dir = tmp_dir, domestic=true)
        rm(tmp_dir, recursive=true)
    end

end