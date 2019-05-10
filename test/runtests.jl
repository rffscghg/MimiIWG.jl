using Test

@testset "MimiIWG2016" begin

include("../src/MimiIWG2016.jl")

include("test_DICE.jl")
include("test_FUND.jl")
include("test_PAGE.jl")

end