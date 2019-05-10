@defcomp IWG_FUND_roebakerclimatesensitivity begin

    roebakercsparameter = Parameter(default = 0.62)
    climatesensitivity = Variable()

    function run_timestep(p, v, d, t)

        if is_first(t)
            v.climatesensitivity = 1.2 / (1.0 - p.roebakercsparameter)
        end 
    end 
    
end 