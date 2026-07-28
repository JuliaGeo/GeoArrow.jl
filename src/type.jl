# For reading
struct Geometry{X,D,T,G}
    geom::G
end
Base.:(==)(x::Geometry{X,D,T,G}, y::Geometry{X,D,T,G}) where {X,D,T,G} = x.geom == y.geom
Base.show(io::IO, x::Geometry{X,D,T}) where {X,D,T} = print(io, "$X geometry in $(D)D with eltype $T")
Geometry{X,D,T}(x) where {X,D,T} = Geometry{X,D,T,typeof(x)}(x)
Geometry{PointTrait}(x::Vararg{T,D}) where {T,D} = Geometry{PointTrait,D,T}(reinterpret(NTuple{D,T}, x))
Geometry{PointTrait,D,T}(x, y, z, m) where {T,D} = Geometry{PointTrait,D,T}((x, y, z, m))
Geometry{PointTrait,D,T}(x, y, z) where {T,D} = Geometry{PointTrait,D,T}((x, y, z))
Geometry{PointTrait,D,T}(x, y) where {T,D} = Geometry{PointTrait,D,T}((x, y))

Base.getindex(x::Geometry{X,D,T}, i) where {X,D,T} = Geometry{childtrait(X()),D,T}(Base.getindex(x.geom, i))
Base.getindex(x::Geometry{PointTrait,D,T}, i) where {D,T} = Base.getindex(x.geom, i)

GeoInterface.isgeometry(::Type{<:Geometry}) = true
GeoInterface.ncoord(_, ::Geometry{X,D}) where {X,D} = D
GeoInterface.getcoord(::PointTrait, g::Geometry, i) = Base.getindex(g.geom, i)
GeoInterface.getcoord(::PointTrait, g::Geometry{X,D,T,<:GeoFormatTypes.MixedFormat}, i) where {X,D,T} = getcoord(PointTrait(), g.geom, i)
GeoInterface.x(t::PointTrait, g::Geometry) = getcoord(t, g, 1)
GeoInterface.y(t::PointTrait, g::Geometry) = getcoord(t, g, 2)
# GeoInterface.z(t::PointTrait, g::Geometry) = getcoord(t, g, 3)  # TODO Fix!
GeoInterface.m(t::PointTrait, g::Geometry) = getcoord(t, g, 4)
GeoInterface.geomtrait(::Geometry{X}) where {X} = X()
GeoInterface.ngeom(_, g::Geometry) = length(g.geom)
GeoInterface.ngeom(t, g::Geometry{X,D,T,<:GeoFormatTypes.MixedFormat}) where {X,D,T} = ngeom(t, g.geom)
GeoInterface.getgeom(_, g::Geometry, i) = Base.getindex(g, i)
GeoInterface.getgeom(t, g::Geometry{X,D,T,<:GeoFormatTypes.MixedFormat}, i) where {X,D,T} = getgeom(t, g.geom, i)
GeoInterface.isempty(::GeoInterface.AbstractGeometryTrait, g::Geometry) = length(g.geom) == 0

# coordtype implementation
if :coordtype in names(GeoInterface; all = true)
    GeoInterface.coordtype(::GeoInterface.AbstractGeometryTrait, geom::Geometry{X,D,T}) where {X,D,T} = T
end

childtrait(::LineStringTrait) = PointTrait
childtrait(::LinearRingTrait) = PointTrait
childtrait(::PolygonTrait) = LinearRingTrait
childtrait(::MultiPointTrait) = PointTrait
childtrait(::MultiLineStringTrait) = LineStringTrait
childtrait(::MultiPolygonTrait) = PolygonTrait

# For writing
abstract type AbstractEncoding end
abstract type AbstractNativeEncoding <: AbstractEncoding end
struct Seperated <: AbstractNativeEncoding end
struct Interleaved <: AbstractNativeEncoding end
struct WellKnownBinary <: AbstractEncoding end
struct WellKnownText <: AbstractEncoding end

struct Wrapper{E,T,N,G}
    geom::G
end
Base.:(==)(x::Wrapper{E,T,N,G}, y::Wrapper{E,T,N,G}) where {E,T,N,G} = x.geom == y.geom
Base.show(io::IO, ::Wrapper{E,T,G}) where {E,T,G} = print(io, "$T geometry encoded as $E")
Wrapper(e::AbstractEncoding, x) = Wrapper{typeof(e),typeof(GeoInterface.geomtrait(x)),GeoInterface.ncoord(x),typeof(x)}(x)
Wrapper(::AbstractEncoding, ::Missing) = missing
Wrapper(x) = Wrapper(Interleaved(), x)

data(x::Wrapper{E,T,N,G}) where {E,T,N,G} = _coordinates(E(), T(), Val{N}(), x.geom)
data(x::Wrapper{WellKnownBinary,T,G}) where {T,G} = getwkb(x.geom).val
data(x::Wrapper{WellKnownText,T,G}) where {T,G} = getwkt(x.geom).val

_coordinates(::Interleaved, t::AbstractPointTrait, ::Val{N}, geom) where N = NTuple{N,Float64}(getcoord(t, geom))
_coordinates(::Seperated, t::AbstractPointTrait, ::Val{N}, geom) where N = nt(NTuple{N,Float64}(getcoord(t, geom)))
function _coordinates(E::AbstractNativeEncoding, t::AbstractGeometryTrait, N, geom)
    map(x -> _coordinates(E, GeoInterface.geomtrait(x), N, x), getgeom(t, geom))
end

nt(x::NTuple{2,Float64}) = NamedTuple{(:x, :y)}(x)
nt(x::NTuple{3,Float64}) = NamedTuple{(:x, :y, :z)}(x)
nt(x::NTuple{4,Float64}) = NamedTuple{(:x, :y, :z, :m)}(x)
