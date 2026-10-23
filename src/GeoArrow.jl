module GeoArrow
using Arrow
using GeoInterface
using GeoFormatTypes
import JSON
using WellKnownGeometry
using Extents
using Tables
using StringViews: StringView  # Base exports StringView since Julia 1.15
using Proj
using DataAPI
using DataFrames
using PrecompileTools: @setup_workload, @compile_workload

include("type.jl")
include("arrow.jl")
include("io.jl")
include("precompile.jl")

export read, write

end  # module
