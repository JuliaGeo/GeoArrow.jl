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
ArrowTypes.ArrowKind(::Type{Wrapper}) = ArrowTypes.ListKind()
ArrowTypes.ArrowKind(::Type{Wrapper{Seperated, T, G}}) where {T,G} = ArrowTypes.StructKind()
ArrowTypes.ArrowKind(::Type{Wrapper{Interleaved, T, N, G}}) where {T,N,G} = ArrowTypes.ListKind()
ArrowTypes.ArrowKind(::Type{Wrapper{Interleaved, PointTrait, N, G}}) where {N,G} = ArrowTypes.FixedSizeListKind{N,Float64}()
ArrowTypes.ArrowKind(::Type{Wrapper{WellKnownText, T, N, G}}) where {T,N,G} = ArrowTypes.ListKind()
ArrowTypes.ArrowKind(::Type{Wrapper{WellKnownBinary, T, N, G}}) where {T,N,G} = ArrowTypes.ListKind()

ArrowTypes.ArrowType(::Type{Geometry{X,D,T,G}}) where {X,D,T,G} = G
ArrowTypes.ArrowType(::Type{Wrapper{WellKnownText,T,N,G}}) where {T,N,G} = String
ArrowTypes.ArrowType(::Type{Wrapper{WellKnownBinary,T,N,G}}) where {T,N,G} = Vector{UInt8}
ArrowTypes.ArrowType(::Type{Wrapper{Interleaved,PointTrait,N,G}}) where {N,G} = NTuple{N,Float64}
ArrowTypes.ArrowType(::Type{Wrapper{Interleaved,LineStringTrait,N,G}}) where {N,G} = Vector{NTuple{N,Float64}}
ArrowTypes.ArrowType(::Type{Wrapper{Interleaved,MultiLineStringTrait,N,G}}) where {N,G} = Vector{Vector{NTuple{N,Float64}}}  
ArrowTypes.ArrowType(::Type{Wrapper{Interleaved,MultiPointTrait,N,G}}) where {N,G} = Vector{NTuple{N,Float64}}
ArrowTypes.ArrowType(::Type{Wrapper{Interleaved,PolygonTrait,N,G}}) where {N,G} = Vector{Vector{NTuple{N,Float64}}}
ArrowTypes.ArrowType(::Type{Wrapper{Interleaved,MultiPolygonTrait,N,G}}) where {N,G} = Vector{Vector{Vector{NTuple{N,Float64}}}}
ArrowTypes.ArrowType(::Type{Wrapper{Seperated,PointTrait,N,G}}) where {N,G} = _named(NTuple{N,Float64})
ArrowTypes.ArrowType(::Type{Wrapper{Seperated,LineStringTrait,N,G}}) where {N,G} = Vector{_named(NTuple{N,Float64})}
ArrowTypes.ArrowType(::Type{Wrapper{Seperated,MultiLineStringTrait,N,G}}) where {N,G} = Vector{Vector{_named(NTuple{N,Float64})}}  
ArrowTypes.ArrowType(::Type{Wrapper{Seperated,MultiPointTrait,N,G}}) where {N,G} = Vector{_named(NTuple{N,Float64})}
ArrowTypes.ArrowType(::Type{Wrapper{Seperated,PolygonTrait,N,G}}) where {N,G} = Vector{Vector{_named(NTuple{N,Float64})}}
ArrowTypes.ArrowType(::Type{Wrapper{Seperated,MultiPolygonTrait,N,G}}) where {N,G} = Vector{Vector{Vector{_named(NTuple{N,Float64})}}}

ArrowTypes.arrowname(::Type{Geometry{PointTrait}}) = POINT
ArrowTypes.arrowname(::Type{Geometry{LineStringTrait}}) = LINESTRING
ArrowTypes.arrowname(::Type{Geometry{PolygonTrait}}) = POLYGON
ArrowTypes.arrowname(::Type{Geometry{MultiPointTrait}}) = MULTIPOINT
ArrowTypes.arrowname(::Type{Geometry{MultiLineStringTrait}}) = MULTILINESTRING
ArrowTypes.arrowname(::Type{Geometry{MultiPolygonTrait}}) = MULTIPOLYGON
ArrowTypes.arrowname(::Type{Wrapper{WellKnownBinary,T,N,G}}) where {T,N,G} = WKB
ArrowTypes.arrowname(::Type{Wrapper{WellKnownText,T,N,G}}) where {T,N,G} = WKT
ArrowTypes.arrowname(::Type{Wrapper{E,PointTrait,N,G}}) where {E<:AbstractNativeEncoding,N,G} = POINT
ArrowTypes.arrowname(::Type{Wrapper{E,LineStringTrait,N,G}}) where {E<:AbstractNativeEncoding,N,G} = LINESTRING
ArrowTypes.arrowname(::Type{Wrapper{E,PolygonTrait,N,G}}) where {E<:AbstractNativeEncoding,N,G} = POLYGON
ArrowTypes.arrowname(::Type{Wrapper{E,MultiPointTrait,N,G}}) where {E<:AbstractNativeEncoding,N,G} = MULTIPOINT
ArrowTypes.arrowname(::Type{Wrapper{E,MultiLineStringTrait,N,G}}) where {E<:AbstractNativeEncoding,N,G} = MULTILINESTRING
ArrowTypes.arrowname(::Type{Wrapper{E,MultiPolygonTrait,N,G}}) where {E<:AbstractNativeEncoding,N,G} = MULTIPOLYGON
ArrowTypes.arrowname(::Type{Extents.Extent}) = BOX

ArrowTypes.toarrow(x::Geometry) = x.geom
ArrowTypes.toarrow(x::Wrapper{E,T,<:Geometry}) where {E,T} = x.geom
ArrowTypes.toarrow(x::Wrapper) = data(x)
ArrowTypes.toarrow(ex::Extents.Extent{(:X, :Y)}) = (; xmin=ex.X[1], ymin=ex.Y[1], xmax=ex.X[2], ymax=ex.Y[2])
ArrowTypes.toarrow(ex::Extents.Extent{(:X, :Y, :Z)}) = (; xmin=ex.X[1], ymin=ex.Y[1], zmin=ex.Z[1], xmax=ex.X[2], ymax=ex.Y[2], zmax=ex.Z[2])
ArrowTypes.toarrow(ex::Extents.Extent{(:X, :Y, :Z, :M)}) = (; xmin=ex.X[1], ymin=ex.Y[1], zmin=ex.Z[1], mmin=ex.M[1], xmax=ex.X[2], ymax=ex.Y[2], zmax=ex.Z[2], mmax=ex.M[2])

ArrowTypes.fromarrow(::Type{GeoFormatTypes.WellKnownBinary}, x) = GeoFormatTypes.WellKnownBinary(GeoFormatTypes.Geom(), x)
ArrowTypes.fromarrow(::Type{GeoFormatTypes.WellKnownText}, x) = GeoFormatTypes.WellKnownText(GeoFormatTypes.Geom(), String(x))  # should be StringView
function ArrowTypes.fromarrow(::Type{Geometry{X}}, x) where {X}
    nt = nested_eltype(x)
    D = length(nt.types)
    return Geometry{X,D,Float64}(x)
end
function fromarrow(::Type{GeoArrow.Geometry{X}}, nt::NamedTuple) where X
    return Geometry{X,length(nt),Float64}(nt)
end
ArrowTypes.fromarrow(::Type{Extents.Extent}, x) = Extents.Extent(X=(x.xmin, x.xmax), Y=(x.ymin, x.ymax))

nested_eltype(x) = nested_eltype(typeof(x))
nested_eltype(::Type{Union{Missing,T}}) where {T} = nested_eltype(T)
nested_eltype(::Type{T}) where {T<:AbstractArray} = nested_eltype(eltype(T))
nested_eltype(::Type{T}) where {T} = T

_named(::Type{NTuple{2, T}}) where {T} = @NamedTuple{x::Float64, y::Float64}
_named(::Type{NTuple{3, T}}) where {T} = @NamedTuple{x::Float64, y::Float64, z::Float64}
_named(::Type{NTuple{4, T}}) where {T} = @NamedTuple{x::Float64, y::Float64, z::Float64, m::Float64}
