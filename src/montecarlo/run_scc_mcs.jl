
"""

"""
function run_scc_mcs(model::model_choice; 
    trials = 10,
    perturbation_years = nothing,
    discount_rates = _default_discount_rates, 
    domestic = false,
    horizon = _default_horizon,
    output_dir = nothing, 
    save_trials = false,
    tables = true)

    # Set up output directory for trials and saved values
    if output_dir == nothing
        output_dir = joinpath(dirname(@__FILE__), "../../output/", "$(string(model)) $(Dates.format(now(), "yyyy-mm-dd HH-MM-SS")) SCC MC$trials")
    end

    # dispatch on provided model choice
    if model == DICE 
        perturbation_years = perturbation_years == nothing ? _default_dice_perturbation_years : perturbation_years
        run_dice_scc_mcs(trials=trials, perturbation_years=perturbation_years, discount_rates=discount_rates, domestic=domestic, horizon=horizon, output_dir=output_dir, save_trials=save_trials, tables=tables)
    elseif model == FUND 
        perturbation_years = perturbation_years == nothing ? _default_fund_perturbation_years : perturbation_years
        run_fund_scc_mcs(trials=trials, perturbation_years=perturbation_years, discount_rates=discount_rates, domestic=domestic, output_dir=output_dir, save_trials=save_trials, tables=tables)
    elseif model == PAGE 
        perturbation_years = perturbation_years == nothing ? _default_page_perturbation_years : perturbation_years
        run_page_scc_mcs(trials=trials, perturbation_years=perturbation_years, discount_rates=discount_rates, domestic=domestic, output_dir=output_dir, save_trials=save_trials, tables=tables)
    end

    nothing
end