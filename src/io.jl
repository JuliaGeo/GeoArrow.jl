"""
    write(path, table; kwargs...)

Write a geospatial table to a file. Like Arrow.write, but with geospatial metadata.
Any kwargs are passed to Arrow.write.
"""
function write(path, t; kwargs...)
    projjson = ""
    crs = Dict("crs" => projjson)
    colmetadata =
        Dict(:geometry => ["ARROW:extension:metadata" => JSON3.write(crs)])
    Arrow.write(path, t; colmetadata, kwargs...)
end

"""
    read(path; kwargs...)

Read a geospatial table from a file. Like Arrow.Table, but with geospatial metadata.
Any kwargs are passed to Arrow.Table.
"""
function read(path; kwargs...)
    t = Arrow.Table(path; kwargs...)
    meta = Arrow.getmetadata(t)
    return t
end
