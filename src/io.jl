"""
    write(path, table; kwargs...)

Write a geospatial table to a file. Like Arrow.write, but with geospatial metadata.
Any kwargs are passed to Arrow.write.
"""
function write(path, t; geocolumns=GeoInterface.geometrycolumns(t), crs=GeoInterface.crs(t), encoding::AbstractEncoding=Interleaved(), kwargs...)

    if isnothing(crs)
        dcrs = Dict{String,Any}()
    else
        pcrs = convert(Proj.CRS, crs)
        jcrs = convert(ProjJSON, pcrs)
        dcrs = Dict("crs" => JSON.parse(GeoFormatTypes.val(jcrs)))
    end
    ct = Tables.columntable(t)
    metadata = DataAPI.metadata(t)
    if !isnothing(metadata)
        # GEOINTERFACE: keys hold Julia objects; GeoArrow stores the CRS per column
        metadata = (k=>string(v) for (k,v) in pairs(metadata) if !startswith(k, "GEOINTERFACE:"))
    end
    colmetadata = Dict{Symbol,Dict{String,String}}()
    tcolmetadata = DataAPI.colmetadata(t)
    if !isnothing(tcolmetadata)
        for (k, v) in pairs(tcolmetadata)
            colmetadata[k] = Dict(k=>string(v) for (k, v) in pairs(v))
        end
    end
    for column in geocolumns
        column in Tables.columnnames(t) || error("Geometry column $column not found in table")
        data = Tables.getcolumn(t, column)
        T = nonmissingtype(Tables.columntype(t, column))
        if ArrowTypes.arrowname(T) == Symbol("")
            GeoInterface.isgeometry(T) || error("Geometry type $T in column $column must support the GeoInterface")
            data = Wrapper.(Ref(encoding), data)
        end
        # Arrow overwrites the extension metadata of an extension type with an empty string,
        # so write the column as plain Arrow storage and set the extension keys ourselves.
        name = ArrowTypes.arrowname(nonmissingtype(eltype(data)))
        storage = map(x -> ismissing(x) ? missing : ArrowTypes.toarrow(x), data)
        ct = merge(ct, NamedTuple{(column,)}((storage,)))
        geometa = Dict("ARROW:extension:name" => String(name), "ARROW:extension:metadata" => JSON.json(dcrs))
        if haskey(colmetadata, column)
            merge!(colmetadata[column], geometa)
        else
            colmetadata[column] = geometa
        end
    end
    Arrow.write(path, ct; metadata, colmetadata, kwargs...)
end

"""
    read(path; kwargs...)

Read a geospatial table from a file. Like Arrow.Table, but with geospatial metadata.
Any kwargs are passed to Arrow.Table.
"""
function read(path; kwargs...)
    at = Arrow.Table(path; kwargs...)
    t = DataFrame(at, copycols=false)

    # Remove GEOINTERFACE: keys stringified by older versions of GeoArrow.write
    for key in keys(DataAPI.metadata(t))
        startswith(key, "GEOINTERFACE:") && DataAPI.deletemetadata!(t, key)
    end

    # set GeoInterface metadata
    names = []
    for (column, metadata) in DataAPI.colmetadata(t)
        "ARROW:extension:name" in keys(metadata) || continue
        startswith(metadata["ARROW:extension:name"], "geoarrow.") || continue
        push!(names, Symbol(column))

        "ARROW:extension:metadata" in keys(metadata) || continue
        extmetadata = metadata["ARROW:extension:metadata"]
        isempty(extmetadata) && continue
        crs = get(JSON.parse(extmetadata), "crs", nothing)
        isnothing(crs) || DataAPI.metadata!(t, "GEOINTERFACE:crs", _crs(crs); style=:note)
    end
    isempty(names) || DataAPI.metadata!(t, "GEOINTERFACE:geometrycolumns", Tuple(names); style=:note)

    return t
end

# The CRS is preferably a PROJJSON object, otherwise a string in any CRS format
_crs(crs::AbstractDict) = GeoFormatTypes.ProjJSON(JSON.json(crs))
_crs(crs) = crs
