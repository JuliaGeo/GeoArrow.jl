"""
    write(path, table; kwargs...)

Write a geospatial table to a file. Like Arrow.write, but with geospatial metadata.
Any kwargs are passed to Arrow.write.
"""
function write(path, t; geocolumns=GeoInterface.geometrycolumns(t), crs=GeoInterface.crs(t), encoding::AbstractEncoding=Interleaved(), kwargs...)

    if isnothing(crs)
        dcrs = Dict{String,String}()
    else
        pcrs = convert(Proj.CRS, crs)
        jcrs = convert(ProjJSON, pcrs)
        dcrs = Dict("crs" => GeoFormatTypes.val(jcrs))
    end
    ct = Tables.columntable(t)
    colmetadata = Dict{Symbol,Vector{Pair{String,String}}}()
    for column in geocolumns
        column in Tables.columnnames(t) || error("Geometry column $column not found in table")
        data = Tables.getcolumn(t, column)
        T = nonmissingtype(Tables.columntype(t, column))
        if ArrowTypes.arrowname(T) == Symbol("")
            GeoInterface.isgeometry(T) || error("Geometry in $column must support the GeoInterface")
            ct = merge(ct, NamedTuple{(column,)}((Wrapper.(Ref(encoding), data),)))
        end
        colmetadata[column] = ["ARROW:extension:metadata" => JSON3.write(dcrs)]
    end
    Arrow.write(path, ct; colmetadata, kwargs...)
end

"""
    read(path; kwargs...)

Read a geospatial table from a file. Like Arrow.Table, but with geospatial metadata.
Any kwargs are passed to Arrow.Table.
"""
function read(path; kwargs...)
    at = Arrow.Table(path; kwargs...)
    t = DataFrame(at, copycols=false)

    # set GeoInterface metadata
    names = []
    for (column, metadata) in DataAPI.colmetadata(t)
        "ARROW:extension:name" in keys(metadata) || continue
        startswith(metadata["ARROW:extension:name"], "geoarrow.") || continue
        push!(names, Symbol(column))

        "ARROW:extension:metadata" in keys(metadata) || continue
        extmetadata = metadata["ARROW:extension:metadata"]
        isempty(extmetadata) && continue
        crs = get(JSON3.read(extmetadata), :crs, nothing)
        isnothing(crs) || DataAPI.metadata!(t, "GEOINTERFACE:crs", crs)
    end
    isempty(names) || DataAPI.metadata!(t, "GEOINTERFACE:geometrycolumns", Tuple(names))

    return t
end
