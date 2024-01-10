# Get all (from_reg_idx, to_reg_idx) pairs for lines
function get_sorted_region_tuples(lines::Vector{BRANCH}, region_names::Vector{String}) where {BRANCH <: PSY.ACBranch}
    region_idxs = Dict(name => idx for (idx, name) in enumerate(region_names))

    line_from_to_reg_idxs = similar(lines, Tuple{Int, Int})

    for (l, line) in enumerate(lines)
        from_name = PSY.get_name(PSY.get_area(PSY.get_from_bus(line)))
        to_name = PSY.get_name(PSY.get_area(PSY.get_to_bus(line)))

        from_idx = region_idxs[from_name]
        to_idx = region_idxs[to_name]

        line_from_to_reg_idxs[l] =
            from_idx < to_idx ? (from_idx, to_idx) : (to_idx, from_idx)
    end

    return line_from_to_reg_idxs
end

# inter-regional lines processing
function get_sorted_lines(lines::Vector{BRANCH}, region_names::Vector{String}) where {BRANCH <: PSY.ACBranch}
    line_from_to_reg_idxs = get_sorted_region_tuples(lines, region_names)
    line_ordering = sortperm(line_from_to_reg_idxs)

    sorted_lines = lines[line_ordering]
    sorted_from_to_reg_idxs = line_from_to_reg_idxs[line_ordering]
    interface_reg_idxs = unique(sorted_from_to_reg_idxs)

    itl_interfaces = String[]
    for int_idx in interface_reg_idxs
        push!(itl_interfaces, region_names[int_idx[1]]*"_"*region_names[int_idx[2]])
    end

    # Ref tells Julia to use interfaces as Vector, only broadcasting over
    # lines_sorted
    interface_line_idxs = searchsorted.(Ref(sorted_from_to_reg_idxs), interface_reg_idxs)

    return sorted_lines, interface_reg_idxs, interface_line_idxs, itl_interfaces
end

# Define from and to limits for lines in case we need to get aggregate capacity when ITL isn't available.
function get_limit_from(line::PSY.Line)
    return PSY.get_rate(line)
end

function get_limit_to(line::PSY.Line)
    return PSY.get_rate(line)
end

function get_limit_from(line::T) where {T<:PSY.Branch}
    error("get_limit_from isn't defined for $(typeof(line))")
    return
end

function get_limit_to(line::T) where {T<:PSY.Branch}
    error("get_limit_to isn't defined for $(typeof(line))")
    return
end