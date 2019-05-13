
# helper function for linear interpolation
function _interpolate(values, orig_x, new_x)
    itp = extrapolate(
                interpolate((orig_x,), Array{Float64,1}(values), Gridded(Linear())), 
                Line())
    # return [itp(i...) for i in new_x]
    return itp(new_x)
end

"""
connect_all!(m::Model, comps::Vector{Pair{Symobl, Symbol}}, src::Pair{Symbol, Symbol})
    helper function for connecting a list of (compname, paramname) pairs all to the same source pair
"""
function connect_all!(m::Model, comps::Vector{Pair{Symbol, Symbol}}, src::Pair{Symbol, Symbol})
    for dest in comps 
        connect_param!(m, dest, src)
    end
end
"""
connect_all!(m::Model, comps::Vector{Symbols}, src::Pair{Symbol, Symbol})
    helper function for connecting a list of compnames all to the same source pair. The parameter name in all the comps must be the same as in the src pair.
"""
function connect_all!(m::Model, comps::Vector{Symbol}, src::Pair{Symbol, Symbol})
    src_comp, param = src
    for comp in comps 
        connect_param!(m, comp=>param, src_comp=>param)
    end
end