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
        # A `return` here would skip all remaining testsets, so use a flag
        python = !Sys.iswindows()  # doesn't work on Windows
        if python
            # ENV["JULIA_CONDAPKG_OFFLINE"] = true  # for running locally
            ENV["JULIA_CONDAPKG_ENV"] = joinpath(@__DIR__, ".cpenv")
            try
                using PythonCall
            catch e
                @error "PythonCall not available:"
                @error e
                python = false
            end
        end
        if python
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
        @test ArrowTypes.ArrowType(typeof(w)) <: Base.CodeUnits
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
    @testset "WKB is stored as Binary" begin
        storagetype(io) = (seekstart(io); nonmissingtype(eltype(Arrow.Table(io; convert=false).geometry)))
        df = DataFrame(geometry=[GeoInterface.Point(1.0, 2.0)])
        io = IOBuffer()
        GeoArrow.write(io, df; encoding=GeoArrow.WellKnownBinary())
        @test storagetype(io) <: Base.CodeUnits  # Binary, not List<UInt8>
        seekstart(io)
        @test GeoInterface.coordinates(GeoArrow.read(io).geometry[1]) == [1.0, 2.0]

        # WKB read from a file is written as Binary as well
        t = Arrow.Table(joinpath(testdatadir, "example_point_wkb.arrows"))
        io = IOBuffer()
        GeoArrow.write(io, t)
        @test storagetype(io) <: Base.CodeUnits

        io = IOBuffer()
        GeoArrow.write(io, df; encoding=GeoArrow.WellKnownText())
        @test storagetype(io) == String
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
    @testset "Several record batches" begin
        io = IOBuffer()
        GeoArrow.write(io, DataFrame(geometry=[(1.0, 2.0)]); crs=GeoFormatTypes.EPSG(4326))
        t = Arrow.Table(seekstart(io); convert=false)
        io = IOBuffer()
        Arrow.write(io, Arrow.Tables.partitioner([t, t]))
        dfn = GeoArrow.read(seekstart(io))
        @test length(dfn.geometry.arrays) == 2
        @test GeoInterface.geometrycolumns(dfn) == (:geometry,)
        @test occursin("4326", GeoFormatTypes.val(GeoInterface.crs(dfn)))
        @test DataAPI.colmetadata(dfn, :geometry, "ARROW:extension:name") == "geoarrow.point"
    end
    @testset "GeoInterface metadata is not stringified" begin
        df = DataFrame(a=1, geometry=[(1., 2.)])
        DataAPI.metadata!(df, "GEOINTERFACE:crs", GeoFormatTypes.EPSG(4326))
        DataAPI.metadata!(df, "GEOINTERFACE:geometrycolumns", (:geometry,))
        io = IOBuffer()
        GeoArrow.write(io, df)
        seekstart(io)
        @test !any(startswith("GEOINTERFACE:"), keys(Arrow.getmetadata(Arrow.Table(io))))

        # Files written by older versions contain the stringified CRS
        io = IOBuffer()
        Arrow.write(io, (; geometry=[GeoArrow.Wrapper((1., 2.))]);
            metadata=["GEOINTERFACE:crs" => "GeoFormatTypes.EPSG{1}((4326,))"])
        seekstart(io)
        dfn = GeoArrow.read(io)
        @test isnothing(GeoInterface.crs(dfn))
        @test GeoInterface.geometrycolumns(dfn) == (:geometry,)
    end
    @testset "CRS" begin
        df = DataFrame(a=1:2, geometry=[(1.0, 2.0), (3.0, 4.0)])
        io = IOBuffer()
        GeoArrow.write(io, df; crs=GeoFormatTypes.EPSG(4326))
        seekstart(io)
        dfn = GeoArrow.read(io)
        crs = GeoInterface.crs(dfn)
        @test crs isa GeoFormatTypes.ProjJSON
        @test occursin("4326", GeoFormatTypes.val(crs))
        # Replacing a column (as GeoDataFrames does) keeps the GeoInterface metadata
        dfn[!, :geometry] = copy(dfn.geometry)
        @test GeoInterface.crs(dfn) == crs
        @test GeoInterface.geometrycolumns(dfn) == (:geometry,)

        # A table read with a CRS can be written again, keeping its CRS
        t = GeoArrow.read(joinpath(testdatadir, "example-crs_vermont-4326_wkb.arrows"))
        io = IOBuffer()
        GeoArrow.write(io, t)
        seekstart(io)
        @test occursin("4326", GeoFormatTypes.val(GeoInterface.crs(GeoArrow.read(io))))
    end
end
