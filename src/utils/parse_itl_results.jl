function parse_itl_results(itl_results_loc::String)
    itl_data = DataFrames.DataFrame()
    if isdir(itl_results_loc)
        (root, dirs, files) = first(walkdir(itl_results_loc))
        
        for file in files
            itl_df = CSV.read(joinpath(root,file), DataFrames.DataFrame);
            append!(itl_data, itl_df)
        end

    elseif (iscsv(itl_results_loc))
        itl_data = CSV.read(itl_results_loc, DataFrames.DataFrame);
    else
        error("Cannot parse ITL results.")
    end

    return itl_data
end