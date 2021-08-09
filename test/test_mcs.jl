using MimiIWG
using Test

# test various combinations of keyword arguments for functionality, not for
# correctness

# run_scc_mcs(model::model_choice; 
#             gas::Union{Symbol, Nothing} = nothing,
#             trials::Int = 10000,
#             perturbation_years::Vector{Int} = _default_perturbation_years,
#             discount_rates::Union{Vector{Float64}, Nothing} = nothing, 
#             prtp_rates::Union{Vector{Float64}, Nothing} = nothing, 
#             eta_levels::Union{Vector{Float64}, Nothing} = nothing, 
#             domestic::Bool = false,
#             equity_weighting::Bool = false,
#             normalization_region::Union{Int, Nothing} = nothing,
#             output_dir::Union{String, Nothing} = nothing, 
#             save_trials::Bool = false,
#             tables::Bool = true,
#             drop_discontinuities::Bool = false,
#             save_md::Bool = false)

option_sets = Dict[
    domestic => [true, false, false],
    equity_weighting => [false, true, true],
    normalization_region => [nothing, nothing, 1],
    drop_discontinuities => [true, false, true]
]
num_options = length(option_sets[:domestic])
gases = [:CO2, :CH4, :N2O]

@testset "MCS" begin 

    @testset "DICE" begin
        for gas in gases
            for i in 1:num_options
                println("Running DICE: SC of $gas for Option Set $i")
                run_scc_mcs(:DICE;
                            gas = gas,
                            trials = 10, 
                            perturbation_years = MimiIWG._default_perturbation_years,
                            prtp_rates = MimiIWG._default_discount_rates,
                            eta_levels = [1., 1.5],
                            domestic = option_sets[:domestic][i],
                            equity_weighting = option_sets[:equity_weighting][i],
                            normalization_region = option_sets[:normalization_region][i],
                            save_trials = true,
                            tables = true,
                            drop_discontinuities = false,
                            save_md = true
                )
            end
        end
        @test_throws ErrorException run_scc_mcs(:DICE, domestic = true, equity_weighting = true)
        @test_throws ErrorException run_scc_mcs(:DICE; equity_weighting = false, normalization_region = true)
    end

    @testset "FUND" begin
        for gas in gases
            for i in 1:num_options
                println("Running FUND: SC of $gas for Option Set $i")
                run_scc_mcs(:FUND;
                            gas = gas,
                            trials = 10, 
                            perturbation_years = MimiIWG._default_perturbation_years,
                            prtp_rates = MimiIWG._default_discount_rates,
                            eta_levels = [1., 1.5],
                            domestic = option_sets[:domestic][i],
                            equity_weighting = option_sets[:equity_weighting][i],
                            normalization_region = option_sets[:normalization_region][i],
                            save_trials = true,
                            tables = true,
                            drop_discontinuities = false,
                            save_md = true
                )
            end
        end
        @test_throws ErrorException run_scc_mcs(:FUND, domestic = true, equity_weighting = true)
        @test_throws ErrorException run_scc_mcs(:FUND; equity_weighting = false, normalization_region = true)
    end

    @testset "PAGE" begin
        for gas in gases
            for i in 1:num_options
                println("Running PAGE: SC of $gas for Option Set $i")
                run_scc_mcs(:PAGE;
                            gas = gas,
                            trials = 10, 
                            perturbation_years = MimiIWG._default_perturbation_years,
                            prtp_rates = MimiIWG._default_discount_rates,
                            eta_levels = [1., 1.5],
                            domestic = option_sets[:domestic][i],
                            equity_weighting = option_sets[:equity_weighting][i],
                            normalization_region = option_sets[:normalization_region][i],
                            save_trials = true,
                            tables = true,
                            drop_discontinuities = option_sets[:drop_discontinuities][i],
                            save_md = true
                )
            end
        end
        @test_throws ErrorException run_scc_mcs(:PAGE, domestic = true, equity_weighting = true)
        @test_throws ErrorException run_scc_mcs(:PAGE; equity_weighting = false, normalization_region = true)
    end
end
