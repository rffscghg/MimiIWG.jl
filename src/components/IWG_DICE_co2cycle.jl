# Differences from the original co2cycle in DICE 2010:
#       - there's only one inditial concentration for MAT (in 2010, used for the timestep 2005-2015) rather than two
#       - E is in units of GtCO2 per decade instead of per year (so it doesn't get mulitiplied by 10)
@defcomp IWG_DICE_co2cycle begin

    MAT     = Variable(index=[time])    # Carbon concentration increase in atmosphere (GtC from 1750)
    ML      = Variable(index=[time])    # Carbon concentration increase in lower oceans (GtC from 1750)
    MU      = Variable(index=[time])    # Carbon concentration increase in shallow oceans (GtC from 1750)

    E       = Parameter(index=[time])   # Total CO2 emissions (GtCO2 per decade)
    mat0    = Parameter()               # Initial Concentration in atmosphere 2010 (GtC)
    ml0     = Parameter()               # Initial Concentration in lower strata (GtC)
    mu0     = Parameter()               # Initial Concentration in upper strata (GtC)

    # Parameters for long-run consistency of carbon cycle
    b11     = Parameter()               # Carbon cycle transition matrix atmosphere to atmosphere
    b12     = Parameter()               # Carbon cycle transition matrix atmosphere to shallow ocean
    b21     = Parameter()               # Carbon cycle transition matrix biosphere/shallow oceans to atmosphere
    b22     = Parameter()               # Carbon cycle transition matrix shallow ocean to shallow oceans
    b23     = Parameter()               # Carbon cycle transition matrix shallow to deep ocean
    b32     = Parameter()               # Carbon cycle transition matrix deep ocean to shallow ocean
    b33     = Parameter()               # Carbon cycle transition matrix deep ocean to deep oceans


    function run_timestep(p, v, d, t)

        # Define function for MU
        if is_first(t)
            v.MU[t] = p.mu0
        else
            v.MU[t] = v.MAT[t - 1] * p.b12 + v.MU[t - 1] * p.b22 + v.ML[t - 1] * p.b32
        end

        # Define function for ML
        if is_first(t)
            v.ML[t] = p.ml0
        else
            v.ML[t] = v.ML[t - 1] * p.b33 + v.MU[t - 1] * p.b23
        end

        # Define function for MAT
        if is_first(t)
            v.MAT[t] = p.mat0
            # and also calculate MAT[2] below
        end
        if !is_last(t)
            v.MAT[t + 1] = v.MAT[t] * p.b11 + v.MU[t] * p.b21 + p.E[t]
        end

    end

end