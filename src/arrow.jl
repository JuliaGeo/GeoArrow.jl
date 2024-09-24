ArrowTypes.isstringtype(::ArrowTypes.StructKind) = false

POINT = Symbol("geoarrow.point")
LINESTRING = Symbol("geoarrow.linestring")
POLYGON = Symbol("geoarrow.polygon")
MULTIPOINT = Symbol("geoarrow.multipoint")
MULTILINESTRING = Symbol("geoarrow.multilinestring")
MULTIPOLYGON = Symbol("geoarrow.multipolygon")
WKB = Symbol("geoarrow.wkb")
WKT = Symbol("geoarrow.wkt")
BOX = Symbol("geoarrow.box")

function ArrowTypes.JuliaType(::Val{POINT}, x, metadata)
    D = length(x.types)
    T = x.types[1]
    return Geometry{PointTrait,D,T}
end
ArrowTypes.JuliaType(::Val{LINESTRING}, x, metadata) = Geometry{LineStringTrait}
ArrowTypes.JuliaType(::Val{POLYGON}, x, metadata) = Geometry{PolygonTrait}
ArrowTypes.JuliaType(::Val{MULTIPOINT}, x, metadata) = Geometry{MultiPointTrait}
ArrowTypes.JuliaType(::Val{MULTILINESTRING}, x, metadata) = Geometry{MultiLineStringTrait}
ArrowTypes.JuliaType(::Val{MULTIPOLYGON}, x, metadata) = Geometry{MultiPolygonTrait}
ArrowTypes.JuliaType(::Val{WKB}, x, metadata) = GeoFormatTypes.WellKnownBinary
ArrowTypes.JuliaType(::Val{WKT}, x, metadata) = GeoFormatTypes.WellKnownText
function ArrowTypes.JuliaType(::Val{BOX}, x, metadata)
    D = length(x.types)
    if D == 4
        Extents.Extent{(:X, :Y)}
    elseif D == 6
        Extents.Extent{(:X, :Y, :Z)}
    elseif D == 8
        Extents.Extent{(:X, :Y, :Z, :M)}
    else
        throw(ArgumentError("Invalid number of dimensions for Extent"))
    end
end
ArrowTypes.ArrowKind(::Type{Geometry}) = ArrowTypes.ListKind()
ArrowTypes.ArrowKind(::Type{<:Geometry{PointTrait,D,T}}) where {D,T} = ArrowTypes.FixedSizeListKind{D,T}()
ArrowTypes.ArrowKind(::Type{<:GeoFormatTypes.WellKnownBinary}) = ArrowTypes.PrimitiveKind()
ArrowTypes.ArrowKind(::Type{<:GeoFormatTypes.WellKnownText}) = ArrowTypes.ListKind()

ArrowTypes.ArrowType(::Type{<:GeoFormatTypes.WellKnownBinary}) = Vector{UInt8}
ArrowTypes.ArrowType(::Type{<:GeoFormatTypes.WellKnownText}) = String
ArrowTypes.ArrowType(::Type{Geometry{X,D,T,G}}) where {X,D,T,G} = G

ArrowTypes.arrowname(::Type{Geometry{PointTrait}}) = POINT
ArrowTypes.arrowname(::Type{Geometry{LineStringTrait}}) = LINESTRING
ArrowTypes.arrowname(::Type{Geometry{PolygonTrait}}) = POLYGON
ArrowTypes.arrowname(::Type{Geometry{MultiPointTrait}}) = MULTIPOINT
ArrowTypes.arrowname(::Type{Geometry{MultiLineStringTrait}}) = MULTILINESTRING
ArrowTypes.arrowname(::Type{Geometry{MultiPolygonTrait}}) = MULTIPOLYGON
ArrowTypes.arrowname(::Type{<:GeoFormatTypes.WellKnownBinary}) = WKB
ArrowTypes.arrowname(::Type{<:GeoFormatTypes.WellKnownText}) = WKT
ArrowTypes.arrowname(::Type{Extents.Extent}) = BOX

ArrowTypes.toarrow(x::Geometry) = x.geom
ArrowTypes.toarrow(x::GeoFormatTypes.WellKnownText) = GeoFormatTypes.val(x)
ArrowTypes.toarrow(x::GeoFormatTypes.WellKnownBinary) = GeoFormatTypes.val(x)
ArrowTypes.toarrow(x::Extents.Extent{(:X, :Y)}) = (; xmin=ex.X[1], ymin=ex.Y[1], xmax=ex.X[2], ymax=ex.Y[2])
ArrowTypes.toarrow(x::Extents.Extent{(:X, :Y, :Z)}) = (; xmin=ex.X[1], ymin=ex.Y[1], zmin=ex.Z[1], xmax=ex.X[2], ymax=ex.Y[2], zmax=ex.Z[2])
ArrowTypes.toarrow(x::Extents.Extent{(:X, :Y, :Z, :M)}) = (; xmin=ex.X[1], ymin=ex.Y[1], zmin=ex.Z[1], mmin=ex.M[1], xmax=ex.X[2], ymax=ex.Y[2], zmax=ex.Z[2], mmax=ex.M[2])

ArrowTypes.fromarrow(::Type{GeoFormatTypes.WellKnownBinary}, x) = GeoFormatTypes.WellKnownBinary(GeoFormatTypes.Geom(), x)
ArrowTypes.fromarrow(::Type{GeoFormatTypes.WellKnownText}, x) = GeoFormatTypes.WellKnownText(GeoFormatTypes.Geom(), x)

function ArrowTypes.fromarrow(::Type{Geometry{X}}, x) where {X}
    nt = nested_eltype(x)
    D = length(nt.types)
    T = nt.types[1]
    return Geometry{X,D,T}(x)
end
ArrowTypes.fromarrow(::Type{Extents.Extent}, x) = Extents.Extent(X=(x.xmin, x.xmax), Y=(x.ymin, x.ymax))

nested_eltype(x) = nested_eltype(typeof(x))
nested_eltype(::Type{T}) where {T<:AbstractArray} = nested_eltype(eltype(T))
nested_eltype(::Type{T}) where {T} = T
