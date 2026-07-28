using GeoArrow
using Arrow
using GeoInterface
using Downloads
using Test
using GeoFormatTypes
using DataFrames
using Extents
using DataAPI

const testdatadir = joinpath(@__DIR__, "data")
mkpath(joinpath(testdatadir, "write"))

@testset "GeoArrow.jl" begin
    @testset "Test datasets" begin
        # Data taken from the geopandas tests, courtesy of Joris Van den Bossche
        for url in readlines("links.txt")
            (isempty(strip(url)) || startswith(url, "#")) && continue
            fn = joinpath(testdatadir, split(url, "/")[end])
            isfile(fn) && continue
            try
                @info "Downloading $fn"
                Downloads.download(url, fn)
            catch
                @warn "Failed to download $fn"
            end
        end

        for arrowfn in filter(endswith(r".arrow|.arrows"), readdir(testdatadir, join=true))
            @testset "$arrowfn" begin
                t = Arrow.Table(arrowfn)
                geom = t.geometry[1]
                @test GeoInterface.isgeometry(geom)
                @test GeoInterface.geomtrait(geom) isa GeoInterface.AbstractGeometryTrait
                @test GeoInterface.ncoord(geom) in [2, 3, 4]
                @test GeoInterface.testgeometry(geom)

                io = IOBuffer()
                GeoArrow.write(io, t; compress=:zstd)
                seekstart(io)
                nt = GeoArrow.read(io, convert=true)
                ngeom = nt.geometry[1]
                @test GeoInterface.testgeometry(ngeom)

                @test GeoInterface.coordinates(ngeom) == GeoInterface.coordinates(geom)
            end
        end
    end
    @testset "Python" begin
        Sys.iswindows() && return  # doesn't work on Windows

        # ENV["JULIA_CONDAPKG_OFFLINE"] = true  # for running locally
        ENV["JULIA_CONDAPKG_ENV"] = joinpath(@__DIR__, ".cpenv")
        try
            using PythonCall
        catch e
            @error "PythonCall not available:"
            @error e
            return
        end
        feather = pyimport("pyarrow.feather")

        for arrowfn in filter(endswith("arrow"), readdir("data", join=true))
            @testset "$arrowfn" begin
                t = GeoArrow.read(arrowfn)
                geom = t.geometry[1]

                fn = joinpath("data/write", basename(arrowfn))
                GeoArrow.write(fn, t)

                # Read with Python
                # gdf = geopandas.read_feather(fn)
                # print(gdf.geometry.type)
                t = feather.read_table(fn)
                meta = t.schema.field(-1).metadata
                @test length(meta.keys()) == 2
                @test any(occursin.("geoarrow", string.(meta.values())))

                # Read with Julia
                tt = GeoArrow.read(fn)
                tt.geometry[1] == geom
            end
        end
    end
    @testset "Encodings" begin
        g = GeoFormatTypes.WellKnownText(GeoFormatTypes.Geom(), "POINT (1 2)")

        w = GeoArrow.Wrapper(GeoArrow.WellKnownText(), g)
        @test ArrowTypes.ArrowKind(typeof(w)) == ArrowTypes.ListKind()
        @test ArrowTypes.ArrowType(typeof(w)) == String
        @test ArrowTypes.arrowname(typeof(w)) == Symbol("geoarrow.wkt")
        @test ArrowTypes.toarrow(w) == "POINT (1.0 2.0)"

        w = GeoArrow.Wrapper(GeoArrow.WellKnownBinary(), g)
        @test ArrowTypes.ArrowKind(typeof(w)) == ArrowTypes.ListKind()
        @test ArrowTypes.ArrowType(typeof(w)) == Vector{UInt8}
        @test ArrowTypes.arrowname(typeof(w)) == Symbol("geoarrow.wkb")
        @test ArrowTypes.toarrow(w)[1:10] == UInt8[0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]

        w = GeoArrow.Wrapper(g)  # Encoding defaults to Interleaved
        @test ArrowTypes.ArrowKind(typeof(w)) == ArrowTypes.FixedSizeListKind{2,Float64}()
        @test ArrowTypes.ArrowType(typeof(w)) == NTuple{2,Float64}
        @test ArrowTypes.arrowname(typeof(w)) == Symbol("geoarrow.point")
        @test ArrowTypes.toarrow(w) == (1.0, 2.0)

        w = GeoArrow.Wrapper(GeoArrow.Seperated(), g)
        @test ArrowTypes.ArrowKind(typeof(w)) == ArrowTypes.StructKind()
        @test ArrowTypes.ArrowType(typeof(w)) == @NamedTuple{x::Float64, y::Float64}
        @test ArrowTypes.arrowname(typeof(w)) == Symbol("geoarrow.point")
        @test ArrowTypes.toarrow(w) == (; x=1.0, y=2.0)
    end
    @testset "Box" begin
        box_type = @NamedTuple{xmin::Float64, ymin::Float64, xmax::Float64, ymax::Float64}
        extent_type = Extents.Extent{(:X, :Y),Tuple{Tuple{Float64,Float64},Tuple{Float64,Float64}}}
        @test ArrowTypes.JuliaType(Val(Symbol("geoarrow.box")), box_type, nothing) == extent_type
        @test ArrowTypes.arrowname(extent_type) == Symbol("geoarrow.box")
        @test ArrowTypes.ArrowType(extent_type) ==
              @NamedTuple{xmin::Float64,ymin::Float64,xmax::Float64,ymax::Float64}
        @test ArrowTypes.toarrow(Extents.Extent(X=(1.0, 3.0), Y=(2.0, 4.0))) ==
              (; xmin=1.0, ymin=2.0, xmax=3.0, ymax=4.0)
        @test ArrowTypes.fromarrow(extent_type, 1.0, 2.0, 3.0, 4.0) ==
              Extents.Extent(X=(1.0, 3.0), Y=(2.0, 4.0))
    end
    @testset "Simple" begin
        df = DataFrame(a=1, geometry=[(1., 2.)])
        GeoArrow.write("simple.arrow", df)
        dfn = GeoArrow.read("simple.arrow")
        @test GeoInterface.isgeometry(dfn.geometry[1])
    end
    @testset "Metadata" begin
        df = DataFrame(a=1, geometry=[(1., 2.)])
        DataAPI.metadata!(df, "author", "test")
        DataAPI.colmetadata!(df, :a, "description", "A normal column")
        DataAPI.colmetadata!(df, :geometry, "description", "A point geometry")
        GeoArrow.write("metadata.arrow", df)
        dfn = GeoArrow.read("metadata.arrow")
        @test DataAPI.metadata(dfn)["author"] == "test"
        @test DataAPI.colmetadata(dfn)[:a]["description"] == "A normal column"
        @test DataAPI.colmetadata(dfn)[:geometry]["description"] == "A point geometry"
    end
end
