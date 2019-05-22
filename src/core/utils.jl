
# helper function for linear interpolation
function _interpolate(values, orig_x, new_x)
    itp = extrapolate(
                interpolate((orig_x,), Array{Float64,1}(values), Gridded(Linear())), 
                Line())
    return itp(new_x)
end


# helper function for connecting a list of (compname, paramname) pairs all to the same source pair
function connect_all!(m::Model, comps::Vector{Pair{Symbol, Symbol}}, src::Pair{Symbol, Symbol})
    for dest in comps 
        connect_param!(m, dest, src)
    end
end
    
#helper function for connecting a list of compnames all to the same source pair. The parameter name in all the comps must be the same as in the src pair.
function connect_all!(m::Model, comps::Vector{Symbol}, src::Pair{Symbol, Symbol})
    src_comp, param = src
    for comp in comps 
        connect_param!(m, comp=>param, src_comp=>param)
    end
end

# helper for calculating the SCC using Ramsey discounting
# marginaldamages: stream of global marginal damages starting in the scc emission year
# g: stream of annual global gdp/cap growth rates starting in the scc emission year
function scc_ramsey(marginaldamages, rho, eta, g)
    r = rho .+ eta .* g     # calculate annual discount rates
    # discount_factor = [exp(-1 * sum(r[1:t])) for t in 0:length(r)-1]   # calculate the discount factor for each year using continuous time discounting
    discount_factor = [exp(-1 * sum(r[1:t])) for t in 1:length(r)]   # calculate the discount factor for each year using continuous time discounting
    npv_md = discount_factor .* marginaldamages     # calculate net present value of marginal damages in each year
    scc = sum(npv_md)    # sum damages to the scc
    return scc
end

# helper function for writing the SCC values to files at the end of a monte carlo simulation
function write_scc_values(values, output_dir, perturbation_years, discount_rates; domestic=false)
    mkpath(output_dir)
    for scenario in scenarios, (j, rate) in enumerate(discount_rates)   # separate file for each scenario/discount combo
        i, scenario_name = Int(scenario), string(scenario)

        filename = domestic ? "$scenario_name $rate domestic.csv" : "$scenario_name $rate.csv"
        filepath = joinpath(output_dir, filename)

        open(filepath, "w") do f
            write(f, join(perturbation_years, ","), "\n")   # each column is a different SCC year, each row is a different trial result
            writedlm(f, values[:, :, i, j], ',')
        end
    end
end

# helper function for computing percentile tables at the end of a monte carlo simulation
function make_percentile_tables(output_dir, discount_rates, perturbation_years)
    scc_dir = "$output_dir/SCC"     # folder with output from the MCS runs
    tables = "$output_dir/Tables/Percentiles"   # folder to save TSD tables to
    mkpath(tables)

    results = readdir(scc_dir)      # all saved SCC output files

    pcts = [.01, .05, .1, .25, .5, :avg, .75, .90, .95, .99]

    for dr in discount_rates, (idx, year) in enumerate(perturbation_years)
        table = joinpath(tables, "$year SCC Percentiles - $(dr*100)%.csv")
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

# helper funcion for computing std error tables at the end of a monte carlo simulation
function make_stderror_tables(output_dir, discount_rates, perturbation_years)
    scc_dir = "$output_dir/SCC"     # folder with output from the MCS runs
    tables = "$output_dir/Tables/Std Errors"   # folder to save the tables to
    mkpath(tables)

    results = readdir(scc_dir)      # all saved SCC output files

    for dr in discount_rates, (idx, year) in enumerate(perturbation_years)
        table = joinpath(tables, "$year SCC Std Errors - $(dr*100)%.csv")
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

# helper function for computing a summary table. Reports average values for all discount rates and years, and high impact value (95th pct) for 3%.
function make_summary_table(output_dir, discount_rates, perturbation_years, high_impact_rate=0.03)

    high_impact_rate in discount_rates ? nothing : error("high_impact_rate must be one of the provided discount rates.")

    scc_dir = "$output_dir/SCC"     # folder with output from the MCS runs
    tables = "$output_dir/Tables"   # folder to save the table to
    mkpath(tables)

    results = readdir(scc_dir)      # all saved SCC output files

    data = Array{Any, 2}(undef, length(perturbation_years)+1, length(discount_rates)+2)
    data[1, :] = ["Year", ["$(r*100)% Average" for r in discount_rates]..., "High Impact (95th Pct at $(high_impact_rate*100)%)"]
    data[2:end, 1] = perturbation_years

    for (j, dr) in enumerate(discount_rates)
        vals = Matrix{Float64}(undef, 0, length(perturbation_years))
        for scenario in scenarios
            vals = vcat(vals, readdlm(joinpath(scc_dir, "$(string(scenario)) $dr.csv"), ',')[2:end, :])
        end
        data[2:end, j+1] = mean(vals, dims=1)[:]
        if dr==high_impact_rate
            data[2:end, end] = [quantile(vals[2:end, y], .95) for y in 1:length(perturbation_years)]
        end
    end

    table = joinpath(tables, "Summary Table.csv")
    writedlm(table, data, ',')
    nothing 
end