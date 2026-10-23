@setup_workload begin
    ring = [(0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 0.0)]
    polygon = GeoInterface.Polygon([ring])
    df = DataFrame(float=[1.0, 2.0], string=["a", "b"], geometry=[polygon, polygon])
    @compile_workload begin
        mktempdir() do dir
            fn = joinpath(dir, "precompile.arrow")
            write(fn, df)
            read(fn)
        end
    end
end
