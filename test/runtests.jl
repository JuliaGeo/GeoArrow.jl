using GeoArrow
using Arrow
using GeoInterface
using Downloads
using Test
# ENV["JULIA_CONDAPKG_OFFLINE"] = true
ENV["JULIA_CONDAPKG_ENV"] = joinpath(@__DIR__, ".cpenv")
using PythonCall
# ga = pyimport("geoarrow.pyarrow")
feather = pyimport("pyarrow.feather")

mkpath(joinpath(@__DIR__, "data/write"), exist_ok=true)

@testset "GeoArrow.jl" begin
    @testset "Test datasets" begin
        # Data taken from the geopandas tests, courtesy of Joris Van den Bossche
        for url in readlines("links.txt")
            fn = joinpath("data", split(url, "/")[end])
            isfile(fn) && continue
            try
                @info "Downloading $fn"
                Downloads.download(url, fn)
            catch
                @warn "Failed to download $fn"
            end
        end

        for arrowfn in filter(endswith("arrow"), readdir("data", join=true))
            @testset "$arrowfn" begin
                t = Arrow.Table(arrowfn)
                geom = t.geometry[1]
                @test GeoInterface.isgeometry(geom)
                @test GeoInterface.geomtrait(geom) isa GeoInterface.AbstractGeometryTrait
                @test GeoInterface.ncoord(geom) in [2, 3]
                @test GeoInterface.testgeometry(geom)

                io = IOBuffer()
                GeoArrow.write(io, t; compress=:zstd)
                seekstart(io)
                nt = GeoArrow.read(io, convert=true)
                ngeom = t.geometry[1]
                @test GeoInterface.isgeometry(geom)

                @test ngeom == geom
            end
        end
    end
    @testset "Python" begin
        for arrowfn in filter(endswith("arrow"), readdir("data", join=true))
            @testset "$arrowfn" begin
                t = Arrow.Table(arrowfn)
                fn = joinpath("data/write", basename(arrowfn))
                GeoArrow.write(fn, t)
                pt = feather.read_table(fn)
            end
        end
    end
end
