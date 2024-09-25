# GeoArrow

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliageo.github.io/GeoArrow.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliageo.github.io/GeoArrow.jl/dev/)
[![Build Status](https://github.com/juliageo/GeoArrow.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/juliageo/GeoArrow.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/juliageo/GeoArrow.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/juliageo/GeoArrow.jl)
[![PkgEval](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/G/GeoArrow.svg)](https://JuliaCI.github.io/NanosoldierReports/pkgeval_badges/report.html)

A [geoarrow](https://github.com/geoarrow/geoarrow) implementation in Julia.

*work in progress*

## Installation
    
```julia
] add GeoArrow
```

## Usage

```julia-repl
julia> using GeoArrow
julia> using GeoInterface
julia> using DataFrames
julia> t = GeoArrow.read("test/data/example-linestring_z-interleaved.arrow")
Arrow.Table with 3 rows, 2 columns, and schema:
 :row_number  Union{Missing, Int32}
 :geometry    Union{Missing, GeoArrow.Geometry{GeoInterface.LineStringTrait}}
julia> t.geometry[1]
LineStringTrait geometry in 3D with eltype Float64
julia> GeoInterface.coordinates(t.geometry[1])
3-element Vector{Vector{Float64}}:
 [30.0, 10.0, 40.0]
 [10.0, 30.0, 40.0]
 [40.0, 40.0, 80.0]
 julia> df = DataFrame(t)
3×2 DataFrame
 Row │ row_number  geometry
     │ Int32?      Geometry…?
─────┼───────────────────────────────────────────────
   1 │          1  LineStringTrait geometry in 3D w…
   2 │          2  LineStringTrait geometry in 3D w…
   3 │          3  LineStringTrait geometry in 3D w…
```

## In progress
- [ ] Write support for custom geometry types
- [ ] CRS access (ideally using https://github.com/apache/arrow-julia/pull/481)
