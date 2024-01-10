function add_interface_limits!(sys::PSY.System, itl_results_loc::String; serialize = false, sys_export_loc::Union{Nothing, String} = nothing)
    # Checks
    if (serialize)
        if (sys_export_loc === nothing)
            @warn "Location to serialize the modified System wasn't passed. The modified System is not being serialized. If you want to serialize the 
                   modified System, you can do this using PSY.to_json() yourself."
        else
            if ~(isjson(sys_export_loc))
                error("The System export location passed should be JSON file.")
            end
        end
    end

    PSY.set_units_base_system!(sys, PSY.UnitSystem.NATURAL_UNITS)

    itl_data = parse_itl_results(itl_results_loc)

    inter_regional_lines = collect(PSY.get_components(x -> ~(x.arc.from.area.name == x.arc.to.area.name),LineTypes,sys));
    region_names = PSY.get_name.(collect(PSY.get_components(PSY.Area, sys)));
    sorted_lines, interface_reg_idxs, interface_line_idxs, itl_interfaces = get_sorted_lines(inter_regional_lines, region_names);

    # Check all interfaces have limits in the CSV
    no_itl_interfaces = String[]
    if (~all(itl_interfaces.∈ Ref(itl_data[!,"interface"])))
        no_itl_interfaces = itl_interfaces[(itl_interfaces.∉ Ref(itl_data[!,"interface"]))]
        @warn "No ITL limits to and from in the data for these interfaces : \n
        $(no_itl_interfaces). \n
        Using aggregate capacity for these interfaces."
    end

    @info "Adding ITL values as Lines to the System..."
    itl_values = Dict()

    for (interface_reg_idx,interface_line_idx,itl_interface) in zip(interface_reg_idxs, interface_line_idxs, itl_interfaces)
        if (itl_interface ∉ no_itl_interfaces)
            itl_df_from_idx = findfirst(itl_data[!,"interface"] .== region_names[interface_reg_idx[1]]*"_"*region_names[interface_reg_idx[2]])
            itl_df_to_idx = findfirst(itl_data[!,"interface"] .== region_names[interface_reg_idx[2]]*"_"*region_names[interface_reg_idx[1]])
            push!(itl_values,itl_interface => Dict("limit_from" => itl_data[itl_df_from_idx, "transfer_limit"],
                                                "limit_to" => itl_data[itl_df_to_idx, "transfer_limit"],
                                                "arc" => first(sorted_lines[interface_line_idx]).arc)                              
                )   
        else
            push!(itl_values,itl_interface => Dict("limit_from" => sum(get_limit_from.(sorted_lines[interface_line_idx])),
            "limit_to" => sum(get_limit_to.(sorted_lines[interface_line_idx])),
            "arc" => first(sorted_lines[interface_line_idx]).arc )                              
                ) 
        end
    end

    for (line_name,line_params) in itl_values
        itl_line = PSY.TwoTerminalHVDCLine(
            name = line_name,
            available = true,
            active_power_flow = 0.0,
            arc = line_params["arc"],
            active_power_limits_from = (min = 0.0, max = line_params["limit_from"]/100.0) ,
            active_power_limits_to = (min = 0.0, max = line_params["limit_to"]/100.0),
            reactive_power_limits_from = (min = 0.0, max = 0.0),
            reactive_power_limits_to = (min = 0.0, max = 0.0) ,
            loss =  (l0 = 0.0, l1 = 0.0),
        )
        PSY.add_component!(sys, itl_line)
    end
    
    @info "Remove existing inter-regional lines from the System..."
    for line in sorted_lines
        PSY.remove_component!(sys, line)
    end

    if (serialize && sys_export_loc !== nothing)
        @info "Serializing the System with inter-regional lines removed and ITL represented as TwoTerminalHVDCLines..."
        PSY.to_json(sys,sys_export_loc,pretty = true, force = true)
    end

    return sys
end

function add_interface_limits!(sys_location::String, itl_results_loc::String; serialize = false, sys_export_loc::Union{Nothing, String} = nothing)
    @info "Running checks on the System location provided ..."
    runchecks(sys_location)
    
    @info "The PowerSystems System is being de-serialized from the System JSON ..."
    sys = 
    try
        PSY.System(sys_location;time_series_read_only = true,runchecks = false);
    catch
        error("The PSY System could not be de-serialized using the location of JSON provided. Please check the location and make sure you have permission to access time_series_storage.h5")
    end

    if (serialize)
        if (sys_export_loc === nothing)
            sys_export_loc = joinpath(dirname(sys_location), first(split(basename(sys_location),".json"))*"_ITL.json")
            @warn "Location to serialize the modified System wasn't passed. Using $(sys_export_loc) to serialize the modified system."
        end
    end
    add_interface_limits!(sys,itl_results_loc,serialize = serialize, sys_export_loc = sys_export_loc)
end




