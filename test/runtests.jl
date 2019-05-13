using Test

@testset "MimiIWG" begin

include("../src/MimiIWG.jl")

include("test_DICE.jl")
include("test_FUND.jl")
include("test_PAGE.jl")

end