function add_interface_limits!(sys::PSY.System, itl_results_loc::String)
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
        itl_line = PSY.Line(
            name = line_name,
            available = true,
            active_power_flow = 0.0,
            reactive_power_flow = 0.0,
            arc = line_params["arc"],
            r = 0.0,
            x =  0.0,
            b = (from = 0.0, to = 0.0),
            rate = line_params["limit_from"]/100.0,
            angle_limits = (min = -1.571, max = 1.571),
            ext = Dict("limit_to" => line_params["limit_to"])
        )
        PSY.add_component!(sys, itl_line)
    end
    
    @info "Remove existing inter-regional lines from the System..."
    for line in sorted_lines
        PSY.remove_component!(sys, line)
    end

    return sys
end

function add_interface_limits!(sys_location::String, itl_results_loc::String)
    @info "Running checks on the System location provided ..."
    runchecks(sys_location)
    
    @info "The PowerSystems System is being de-serialized from the System JSON ..."
    sys = 
    try
        PSY.System(sys_location;time_series_read_only = true,runchecks = false);
    catch
        error("The PSY System could not be de-serialized using the location of JSON provided. Please check the location and make sure you have permission to access time_series_storage.h5")
    end

    add_interface_limits!(sys,itl_results_loc)
end




