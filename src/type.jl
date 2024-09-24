struct Geometry{X,D,T,G}
    geom::G
end
Base.show(io::IO, x::Geometry{X,D,T}) where {X,D,T} = print(io, "$X geometry in $(D)D with eltype $T")
Geometry{X,D,T}(x) where {X,D,T} = Geometry{X,D,T,typeof(x)}(x)
Geometry{PointTrait}(x::Vararg{T,D}) where {T,D} = Geometry{PointTrait,D,T}(reinterpret(NTuple{D,T}, x))
Geometry{PointTrait,D,T}(x, y, z) where {T,D} = Geometry{PointTrait,D,T}((x, y, z))
Geometry{PointTrait,D,T}(x, y) where {T,D} = Geometry{PointTrait,D,T}((x, y))

Base.getindex(x::Geometry{X,D,T}, i) where {X,D,T} = Geometry{childtrait(X()),D,T}(Base.getindex(x.geom, i))
Base.getindex(x::Geometry{PointTrait,D,T}, i) where {D,T} = Base.getindex(x.geom, i)

GeoInterface.isgeometry(::Type{<:Geometry}) = true
GeoInterface.ncoord(_, ::Geometry{X,D}) where {X,D} = D
GeoInterface.getcoord(::PointTrait, g::Geometry, i) = Base.getindex(g.geom, i)
GeoInterface.geomtrait(::Geometry{X}) where {X} = X()
GeoInterface.ngeom(_, g::Geometry) = length(g.geom)
GeoInterface.getgeom(_, g::Geometry, i) = Base.getindex(g, i)

childtrait(::LineStringTrait) = PointTrait
childtrait(::LinearRingTrait) = PointTrait
childtrait(::PolygonTrait) = LinearRingTrait
childtrait(::MultiPointTrait) = PointTrait
childtrait(::MultiLineStringTrait) = LineStringTrait
childtrait(::MultiPolygonTrait) = PolygonTrait
