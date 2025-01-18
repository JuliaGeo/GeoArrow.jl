module GeoArrow
using Arrow
using GeoInterface
using GeoFormatTypes
using JSON3
using WellKnownGeometry
using Extents
using Tables
using StringViews
using Proj
using DataAPI
using DataFrames

include("type.jl")
include("arrow.jl")
include("io.jl")

export read, write

end  # module
