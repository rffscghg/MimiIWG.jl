
"""
Returns a Monte Carlo Simulation object over the uncertain parameters used by the IWG for the PAGE model.
    The only changes are that sens_climatesensitivity is now a RV with Empirical Roe and Baker Distribution,
    and tcr_transientresponse and emuc_utilityconvexity are no longer RVs.
"""
function get_page_mcs()

    mcs = @defsim begin

        # ADDITIONAL IWG DISTRIBUTIONAL PARAMETER:
        sens_climatesensitivity = EmpiricalDistribution(RB_cs_values, RB_cs_probs)

        sampling(LHSData)

        # ORIGINAL PAGE RANDOM VARIABLES:
        
        #The folllowing RVs are in more than one component.  For clarity they are 
        #set here as opposed to below within the blocks of RVs separated by component
        #so that they are not set more than once.

        save_savingsrate = TriangularDist(10, 20, 15) # components: MarketDamages, NonMarketDamages. GDP, SLRDamages

        wincf_weightsfactor["USA"] = TriangularDist(.6, 1, .8) # components: MarketDamages, NonMarketDamages, , SLRDamages, Discountinuity
        wincf_weightsfactor["OECD"] = TriangularDist(.4, 1.2, .8)
        wincf_weightsfactor["USSR"] = TriangularDist(.2, .6, .4)
        wincf_weightsfactor["China"] = TriangularDist(.4, 1.2, .8)
        wincf_weightsfactor["SEAsia"] = TriangularDist(.4, 1.2, .8)
        wincf_weightsfactor["Africa"] = TriangularDist(.4, .8, .6)
        wincf_weightsfactor["LatAmerica"] = TriangularDist(.4, .8, .6)

        automult_autonomouschange = TriangularDist(0.5, 0.8, 0.65)  #components: AdaptationCosts, AbatementCosts
        
        #The following RVs are divided into blocks by component

        # CO2cycle
        air_CO2fractioninatm = TriangularDist(57, 67, 62)
        res_CO2atmlifetime = TriangularDist(50, 100, 70)
        ccf_CO2feedback = TriangularDist(4, 15, 10)
        ccfmax_maxCO2feedback = TriangularDist(30, 80, 50)
        stay_fractionCO2emissionsinatm = TriangularDist(0.25,0.35,0.3)
        
        # SulphateForcing
        d_sulphateforcingbase = TriangularDist(-0.8, -0.2, -0.4)
        ind_slopeSEforcing_indirect = TriangularDist(-0.8, 0, -0.4)
        
        # ClimateTemperature
        rlo_ratiolandocean = TriangularDist(1.2, 1.6, 1.4)
        pole_polardifference = TriangularDist(1, 2, 1.5)
        frt_warminghalflife = TriangularDist(10, 65, 30)
        # tcr_transientresponse = TriangularDist(1, 2.8, 1.3)
        
        # SeaLevelRise
        s0_initialSL = TriangularDist(0.1, 0.2, 0.15)
        sltemp_SLtemprise = TriangularDist(0.7, 3., 1.5)
        sla_SLbaselinerise = TriangularDist(0.5, 1.5, 1.)
        sltau_SLresponsetime = TriangularDist(500, 1500, 1000)
        
        # GDP
        isat0_initialimpactfxnsaturation = TriangularDist(20, 50, 30) 
        
        # MarketDamages
        tcal_CalibrationTemp = TriangularDist(2.5, 3.5, 3.)
        iben_MarketInitialBenefit = TriangularDist(0, .3, .1)
        W_MarketImpactsatCalibrationTemp = TriangularDist(.2, .8, .5)
        pow_MarketImpactExponent = TriangularDist(1.5, 3, 2)
        ipow_MarketIncomeFxnExponent = TriangularDist(-.3, 0, -.1)

        # NonMarketDamages
        tcal_CalibrationTemp = TriangularDist(2.5, 3.5, 3.)
        iben_NonMarketInitialBenefit = TriangularDist(0, .2, .05)
        w_NonImpactsatCalibrationTemp = TriangularDist(.1, 1, .5)
        pow_NonMarketExponent = TriangularDist(1.5, 3, 2)
        ipow_NonMarketIncomeFxnExponent = TriangularDist(-.2, .2, 0)
        
        # SLRDamages
        scal_calibrationSLR = TriangularDist(0.45, 0.55, .5)
        #iben_SLRInitialBenefit = TriangularDist(0, 0, 0) # only usable if lb <> ub
        W_SatCalibrationSLR = TriangularDist(.5, 1.5, 1)
        pow_SLRImpactFxnExponent = TriangularDist(.5, 1, .7)
        ipow_SLRIncomeFxnExponent = TriangularDist(-.4, -.2, -.3)
        
        # Discountinuity
        rand_discontinuity = Uniform(0, 1)
        tdis_tolerabilitydisc = TriangularDist(2, 4, 3)
        pdis_probability = TriangularDist(10, 30, 20)
        wdis_gdplostdisc = TriangularDist(5, 25, 15)
        ipow_incomeexponent = TriangularDist(-.3, 0, -.1)
        distau_discontinuityexponent = TriangularDist(20, 200, 50)
        
        # EquityWeighting
        civvalue_civilizationvalue = TriangularDist(1e10, 1e11, 5e10)
        # emuc_utilityconvexity = TriangularDist(0.5,2,1)       # IWG does not sample this; instead use constant discounting
        
        # AbatementCosts
        AbatementCostParametersCO2_emit_UncertaintyinBAUEmissFactorinFocusRegioninFinalYear = TriangularDist(-50,75,0)
        AbatementCostParametersCH4_emit_UncertaintyinBAUEmissFactorinFocusRegioninFinalYear = TriangularDist(-25,100,0)
        AbatementCostParametersN2O_emit_UncertaintyinBAUEmissFactorinFocusRegioninFinalYear = TriangularDist(-50,50,0)
        AbatementCostParametersLin_emit_UncertaintyinBAUEmissFactorinFocusRegioninFinalYear = TriangularDist(-50,50,0)
        
        AbatementCostParametersCO2_q0propinit_CutbacksinNegativeCostinFocusRegioninBaseYear = TriangularDist(0,40,20)
        AbatementCostParametersCH4_q0propinit_CutbacksinNegativeCostinFocusRegioninBaseYear = TriangularDist(0,20,10)
        AbatementCostParametersN2O_q0propinit_CutbacksinNegativeCostinFocusRegioninBaseYear = TriangularDist(0,20,10)
        AbatementCostParametersLin_q0propinit_CutbacksinNegativeCostinFocusRegioninBaseYear = TriangularDist(0,20,10)
        
        AbatementCostParametersCO2_c0init_MostNegativeCostCutbackinBaseYear = TriangularDist(-400,-100,-200)
        AbatementCostParametersCH4_c0init_MostNegativeCostCutbackinBaseYear = TriangularDist(-8000,-1000,-4000)
        AbatementCostParametersN2O_c0init_MostNegativeCostCutbackinBaseYear = TriangularDist(-15000,0,-7000)
        AbatementCostParametersLin_c0init_MostNegativeCostCutbackinBaseYear = TriangularDist(-400,-100,-200)
        
        AbatementCostParametersCO2_qmaxminusq0propinit_MaxCutbackCostatPositiveCostinBaseYear = TriangularDist(60,80,70)
        AbatementCostParametersCH4_qmaxminusq0propinit_MaxCutbackCostatPositiveCostinBaseYear = TriangularDist(35,70,50)
        AbatementCostParametersN2O_qmaxminusq0propinit_MaxCutbackCostatPositiveCostinBaseYear = TriangularDist(35,70,50)
        AbatementCostParametersLin_qmaxminusq0propinit_MaxCutbackCostatPositiveCostinBaseYear = TriangularDist(60,80,70)
        
        AbatementCostParametersCO2_cmaxinit_MaximumCutbackCostinFocusRegioninBaseYear = TriangularDist(100,700,400)
        AbatementCostParametersCH4_cmaxinit_MaximumCutbackCostinFocusRegioninBaseYear = TriangularDist(3000,10000,6000)
        AbatementCostParametersN2O_cmaxinit_MaximumCutbackCostinFocusRegioninBaseYear = TriangularDist(2000,60000,20000)
        AbatementCostParametersLin_cmaxinit_MaximumCutbackCostinFocusRegioninBaseYear = TriangularDist(100,600,300)
        
        AbatementCostParametersCO2_ies_InitialExperienceStockofCutbacks = TriangularDist(100000,200000,150000)
        AbatementCostParametersCH4_ies_InitialExperienceStockofCutbacks = TriangularDist(1500,2500,2000)
        AbatementCostParametersN2O_ies_InitialExperienceStockofCutbacks = TriangularDist(30,80,50)
        AbatementCostParametersLin_ies_InitialExperienceStockofCutbacks = TriangularDist(1500,2500,2000)
        
        #the following variables need to be set, but set the same in all 4 abatement cost components
        #note that for these regional variables, the first region is the focus region (EU), which is set in the preceding code, and so is always one for these variables
        
        emitf_uncertaintyinBAUemissfactor["USA"] = TriangularDist(0.8,1.2,1.0)
        emitf_uncertaintyinBAUemissfactor["OECD"] = TriangularDist(0.8,1.2,1.0)
        emitf_uncertaintyinBAUemissfactor["USSR"] = TriangularDist(0.65,1.35,1.0)
        emitf_uncertaintyinBAUemissfactor["China"] = TriangularDist(0.5,1.5,1.0)
        emitf_uncertaintyinBAUemissfactor["SEAsia"] = TriangularDist(0.5,1.5,1.0)
        emitf_uncertaintyinBAUemissfactor["Africa"] = TriangularDist(0.5,1.5,1.0)
        emitf_uncertaintyinBAUemissfactor["LatAmerica"] = TriangularDist(0.5,1.5,1.0)
        
        q0f_negativecostpercentagefactor["USA"] = TriangularDist(0.75,1.5,1.0)
        q0f_negativecostpercentagefactor["OECD"] = TriangularDist(0.75,1.25,1.0)
        q0f_negativecostpercentagefactor["USSR"] = TriangularDist(0.4,1.0,0.7)      
        q0f_negativecostpercentagefactor["China"] = TriangularDist(0.4,1.0,0.7)
        q0f_negativecostpercentagefactor["SEAsia"] = TriangularDist(0.4,1.0,0.7)
        q0f_negativecostpercentagefactor["Africa"] = TriangularDist(0.4,1.0,0.7)
        q0f_negativecostpercentagefactor["LatAmerica"] = TriangularDist(0.4,1.0,0.7)
        
        cmaxf_maxcostfactor["USA"] = TriangularDist(0.8,1.2,1.0)
        cmaxf_maxcostfactor["OECD"] = TriangularDist(1.0,1.5,1.2)
        cmaxf_maxcostfactor["USSR"] = TriangularDist(0.4,1.0,0.7)
        cmaxf_maxcostfactor["China"] = TriangularDist(0.8,1.2,1.0)
        cmaxf_maxcostfactor["SEAsia"] = TriangularDist(1,1.5,1.2)
        cmaxf_maxcostfactor["Africa"] = TriangularDist(1,1.5,1.2)
        cmaxf_maxcostfactor["LatAmerica"] = TriangularDist(0.4,1.0,0.7)
        
        q0propmult_cutbacksatnegativecostinfinalyear = TriangularDist(0.3,1.2,0.7)
        qmax_minus_q0propmult_maxcutbacksatpositivecostinfinalyear = TriangularDist(1,1.5,1.3)
        c0mult_mostnegativecostinfinalyear = TriangularDist(0.5,1.2,0.8)
        curve_below_curvatureofMACcurvebelowzerocost = TriangularDist(0.25,0.8,0.45)
        curve_above_curvatureofMACcurveabovezerocost = TriangularDist(0.1,0.7,0.4)
        cross_experiencecrossoverratio = TriangularDist(0.1,0.3,0.2)
        learn_learningrate = TriangularDist(0.05,0.35,0.2)
        
        # AdaptationCosts
        AdaptiveCostsSeaLevel_cp_costplateau_eu = TriangularDist(0.01, 0.04, 0.02)
        AdaptiveCostsSeaLevel_ci_costimpact_eu = TriangularDist(0.0005, 0.002, 0.001)
        AdaptiveCostsEconomic_cp_costplateau_eu = TriangularDist(0.005, 0.02, 0.01)
        AdaptiveCostsEconomic_ci_costimpact_eu = TriangularDist(0.001, 0.008, 0.003)
        AdaptiveCostsNonEconomic_cp_costplateau_eu = TriangularDist(0.01, 0.04, 0.02)
        AdaptiveCostsNonEconomic_ci_costimpact_eu = TriangularDist(0.002, 0.01, 0.005)
        
        cf_costregional["USA"] = TriangularDist(0.6, 1, 0.8)
        cf_costregional["OECD"] = TriangularDist(0.4, 1.2, 0.8)
        cf_costregional["USSR"] = TriangularDist(0.2, 0.6, 0.4)
        cf_costregional["China"] = TriangularDist(0.4, 1.2, 0.8)
        cf_costregional["SEAsia"] = TriangularDist(0.4, 1.2, 0.8)
        cf_costregional["Africa"] = TriangularDist(0.4, 0.8, 0.6)
        cf_costregional["LatAmerica"] = TriangularDist(0.4, 0.8, 0.6)
        
        
        # save(ClimateTemperature.sens_climatesensitivity)

    end

    return mcs

end

"""
    Run a Monte Carlo Simulation of the IWG version of PAGE09.
"""
function run_page_scc_mcs(mcs::Simulation = get_page_mcs(); 
        trials = 10,
        perturbation_years = _default_page_perturbation_years,
        discount_rates = _default_discount_rates, 
        save_trials = false,
        domestic = false,
        # interpolate_fiveyears = false,
        output_dir = nothing, 
        tables = true)

    # Set up output directory for trials and saved values
    output_dir == nothing ? error("Must provide an output_dir to run_page_scc_mcs.") : nothing
    mkpath(output_dir)

    # Make subdirectory for SCC output
    scc_dir = joinpath(output_dir, "SCC/")
    mkpath(scc_dir)

    # Set up scenario arguments
    scenario_args = [
        :scenario_names => scenario_names
        :discount_rates => discount_rates
    ]

    # Precompute discount factors for each of the discount rates
    discount_factors = [[(1 / (1 + r)) ^ (Y - 2000) for Y in page_years] for r in discount_rates]

    # Check if any desired perturbation years need to be interpolated (aren't in the time index)
    all_years = copy(perturbation_years)    # preserve a copy of the original desired SCC years
    perturbation_years = page_years[1 : length(filter(x->x<maximum(all_years), page_years)) + 1]
    _need_to_interpolate = all_years == perturbation_years ? false : true    # Boolean flag for whether or not we need to interpolate at the end

    # Allocate matrix to store each trial's SCC values
    SCC_values = Array{Float64, 4}(undef, trials, length(perturbation_years), length(scenario_names), length(discount_rates))
    if domestic 
        SCC_values_domestic = Array{Float64, 4}(undef, trials, length(perturbation_years), length(scenario_names), length(discount_rates))
    end

    function scenario_setup(mcs::Simulation, tup::Tuple)

        # Unpack the scenario arguments
        (scenario_name, rate) = tup 
        global scenario_num = findfirst(isequal(scenario_name), scenario_names)
        global rate_num = findfirst(isequal(rate), discount_rates)

        # Build the page versions for this scenario
        base, marginal = mcs.models
        set_param!(base, :IWGScenarioChoice, :scenario_num, scenario_num)
        set_param!(marginal, :IWGScenarioChoice, :scenario_num, scenario_num)
        update_param!(base, :ptp_timepreference, rate*100)  # update the pure rate of time preference for this scenario's discount rate
        update_param!(marginal, :ptp_timepreference, rate*100)  # update the pure rate of time preference for this scenario's discount rate

        Mimi.build(base)
        Mimi.build(marginal)

    end 

    function post_trial_scc(mcs::Simulation, trialnum::Int, ntimesteps::Int, tup::Tuple)

        # Unpack the scenario arguments
        (scenario_name, rate) = tup
        DF = discount_factors[rate_num]

        # Access the models
        base, marginal = mcs.models 
        
        # Get base impacts:
        td_base = base[:EquityWeighting, :td_totaldiscountedimpacts]
        if domestic 
            td_base_domestic = sum(base[:EquityWeighting, :addt_equityweightedimpact_discountedaggregated][:, 2])  # US is the second region
        end

        EMUC = base[:EquityWeighting, :emuc_utilityconvexity]
        UDFT_base = DF .* (base[:EquityWeighting, :cons_percap_consumption][:, 1] / base[:EquityWeighting, :cons_percap_consumption_0][1]) .^ (-EMUC)

        for pyear in perturbation_years 
            idx = getpageindexfromyear(pyear)

            perturb_marginal_page_emissions!(base, marginal, pyear)
            run(marginal)
            td_marginal = marginal[:EquityWeighting, :td_totaldiscountedimpacts] 
            UDFT_marginal = DF[idx] * (marginal[:EquityWeighting, :cons_percap_consumption][idx, 1] / base[:EquityWeighting, :cons_percap_consumption_0][idx]) ^ (-EMUC)
            
            scc = ((td_marginal / UDFT_marginal) - (td_base / UDFT_base[idx])) / 100000 * page_inflator
            j = findfirst(isequal(pyear), perturbation_years)
            # if isnan(scc)
                # println(td_marginal, " - ", td_base)
                # println(base[:EquityWeighting, :rcons_percap_dis])
                # println(base[:Discontinuity, :rcons_per_cap_NonMarketRemainConsumption])
            # end 
            SCC_values[trialnum, j, scenario_num, rate_num] = scc   

            if domestic 
                td_marginal_domestic = sum(marginal[:EquityWeighting, :addt_equityweightedimpact_discountedaggregated][:, 2])
                scc_domestic = ((td_marginal_domestic / UDFT_marginal) - (td_base_domestic / UDFT_base[idx])) / 100000 * page_inflator
                SCC_values_domestic[trialnum, j, scenario_num, rate_num] = scc_domestic
            end

        end 
    end 

    fn = save_trials ? joinpath(output_dir, "trials.csv") : nothing 
    generate_trials!(mcs, trials; filename = fn)

    base, marginal = get_marginal_page_models()  
    set_models!(mcs, [base, marginal])

    run_sim(mcs; 
        trials = trials, 
        models_to_run = 1,
        output_dir = joinpath(output_dir, "saved_variables"),
        scenario_args = scenario_args,
        scenario_func = scenario_setup, 
        post_trial_func = post_trial_scc
    )

    # generic interpolation if user requested SCC values for years in between page_years
    if _need_to_interpolate
        new_SCC_values = Array{Float64, 4}(undef, trials, length(all_years), length(scenario_names), length(discount_rates))

        for i in 1:trials, j in 1:length(scenario_names), k in 1:length(discount_rates)
            itp = interpolate((perturbation_years,), SCC_values[i, :, j, k], Gridded(Linear()))
            new_SCC_values[i, :, j, k] = [itp[y] for y in all_years]
        end

        SCC_values = new_SCC_values

        if domestic 
            new_domestic_values = Array{Float64, 4}(undef, trials, length(all_years), length(scenario_names), length(discount_rates))
            for i in 1:trials, j in 1:length(scenario_names), k in 1:length(discount_rates)
                itp = interpolate((perturbation_years,), SCC_values_domestic[i, :, j, k], Gridded(Linear()))
                new_domestic_values[i, :, j, k] = [itp[y] for y in all_years]
            end
            SCC_values_domestic = new_domestic_values
        end

        perturbation_years = all_years
    end

    # Interpolate 2010:10:2050 to 2010:5:2050
    # if interpolate_fiveyears
    #     new_years = collect(2010:5:2050)
    #     new_SCC_values = Array{Float64, 4}(trials, length(new_years), length(scenario_names), length(discount_rates))

    #     for i in 1:trials, j in 1:length(scenario_names), k in 1:length(discount_rates)
    #         itp = interpolate((perturbation_years,), SCC_values[i, :, j, k], Gridded(Linear()))
    #         new_SCC_values[i, :, j, k] = [itp[y] for y in new_years]
    #     end

    #     SCC_values = new_SCC_values

    #     if domestic 
    #         new_domestic_values = Array{Float64, 4}(trials, length(new_years), length(scenario_names), length(discount_rates))
    #         for i in 1:trials, j in 1:length(scenario_names), k in 1:length(discount_rates)
    #             itp = interpolate((perturbation_years,), SCC_values_domestic[i, :, j, k], Gridded(Linear()))
    #             new_domestic_values[i, :, j, k] = [itp[y] for y in new_years]
    #         end
    #         SCC_values_domestic = new_domestic_values
    #     end

    #     perturbation_years = new_years

    # end

    # Save the SCC values to files
    for (i, scenario_name) in enumerate(scenario_names), (j, rate) in enumerate(discount_rates)
        # Global SCC values
        scc_file = joinpath(scc_dir, "$scenario_name $rate.csv")
        open(scc_file, "w") do f
            write(f, join(perturbation_years, ","), "\n")
            writedlm(f, SCC_values[:, :, i, j], ',')
        end
        # Domestic SCC values
        if domestic 
            scc_file = joinpath(scc_dir, "$scenario_name $rate domestic.csv")
            open(scc_file, "w") do f
                write(f, join(perturbation_years, ","), "\n")
                writedlm(f, SCC_values_domestic[:, :, i, j], ',')
            end
        end
    end

    # Make TSD tables and standard error tables
    if tables
        _make_page_percentile_tables(output_dir, discount_rates, perturbation_years)
        _make_page_stderror_tables(output_dir, discount_rates, perturbation_years)
        if discount_rates == _default_discount_rates
            _make_summary_table(output_dir, discount_rates, perturbation_years)
        end
    end

end

"""
Replicate the percentile summary tables from the IWG TSD documents.
"""
function _make_page_percentile_tables(output_dir, discount_rates, perturbation_years)

    scc_dir = "$output_dir/SCC"     # folder with output from the MCS runs
    tables = "$output_dir/Tables/Percentiles"   # folder to save TSD tables to
    mkpath(tables)

    results = readdir(scc_dir)      # all saved SCC output files

    pcts = [.01, .05, .1, .25, .5, :avg, .75, .90, .95, .99]

    for dr in discount_rates, (idx, year) in enumerate(perturbation_years)
        table = joinpath(tables, "$year SCC Percentiles - $dr.csv")
        open(table, "w") do f 
            write(f, "Scenario,1st,5th,10th,25th,50th,Avg,75th,90th,95th,99th\n")
            for fn in filter(x -> endswith(x, "$dr.csv"), results)  # Get the results files for this discount rate
                scenario = split(fn)[1] # get the scenario name
                d = readdlm(joinpath(scc_dir, fn), ',')[2:end, idx] # just keep 2020 values
                filter!(x->!isnan(x), d)
                values = [pct == :avg ? Int(round(mean(d))) : Int(round(quantile(d, pct))) for pct in pcts]
                write(f, "$scenario,", join(values, ","), "\n")
            end 
        end
    end
    nothing  
end

function _make_page_stderror_tables(output_dir, discount_rates, perturbation_years)

    scc_dir = "$output_dir/SCC"     # folder with output from the MCS runs
    tables = "$output_dir/Tables/Std Errors"   # folder to save TSD tables to
    mkpath(tables)

    results = readdir(scc_dir)      # all saved SCC output files

    for dr in discount_rates, (idx, year) in enumerate(perturbation_years)
        table = joinpath(tables, "$year SCC Std Errors - $dr.csv")
        open(table, "w") do f 
            write(f, "Scenario,Mean,SE\n")
            for fn in filter(x -> endswith(x, "$dr.csv"), results)  # Get the results files for this discount rate
                scenario = split(fn)[1] # get the scenario name
                d = readdlm(joinpath(scc_dir, fn), ',')[2:end, idx] # just keep 2020 values
                filter!(x->!isnan(x), d)
                write(f, "$scenario, $(round(mean(d), digits=2)), $(round(sem(d), digits=2)) \n")
            end 
        end
    end
    nothing  
end

function _make_summary_table(output_dir, discount_rates, perturbation_years)

    scc_dir = "$output_dir/SCC"     # folder with output from the MCS runs
    tables = "$output_dir/Tables"   # folder to save TSD tables to
    mkpath(tables)

    results = readdir(scc_dir)      # all saved SCC output files


    data = Array{Any, 2}(undef, length(perturbation_years)+1, 5)
    data[1, :] = ["Year","5% Average","3% Average","2.5% Average", "High Impact (95th Pct at 3%)"]
    data[2:end, 1] = perturbation_years

    for (j, dr) in enumerate([0.05, 0.03, 0.025])
        vals = Matrix{Float64}(undef, 0, length(perturbation_years))
        for scenario in scenario_names
            vals = vcat(vals, readdlm(joinpath(scc_dir, "$scenario $dr.csv"), ',')[2:end, :])
        end
        data[2:end, j+1] = mean(vals, dims=1)[:]
        if dr==0.03
            data[2:end, end] = [quantile(vals[2:end, y], .95) for y in 1:length(perturbation_years)]
        end
    end

    table = joinpath(tables, "Summary Table.csv")
    writedlm(table, data, ',')
    nothing 
end

