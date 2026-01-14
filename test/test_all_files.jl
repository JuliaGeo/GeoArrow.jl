# Test script to verify all GeoArrow test files can be read

using Arrow
using GeoArrow
using GeoFormatTypes
using Extents
using Tables

test_data_dir = joinpath(@__DIR__, "data")

# Get all .arrow and .arrows files
files = filter(f -> endswith(f, ".arrow") || endswith(f, ".arrows"), readdir(test_data_dir))

# Track results
passed = String[]
failed = Dict{String, String}()

for file in files
    filepath = joinpath(test_data_dir, file)
    try
        tbl = Arrow.Table(filepath)
        # Try to materialize each column
        for col in Tables.columnnames(tbl)
            coldata = Tables.getcolumn(tbl, col)
            # Access first element to trigger fromarrow
            if length(coldata) > 0
                _ = coldata[1]
            end
        end
        push!(passed, file)
        println("✓ $file")
    catch e
        failed[file] = sprint(showerror, e)
        println("✗ $file: $(sprint(showerror, e))")
    end
end

println("\n" * "="^60)
println("Results: $(length(passed)) passed, $(length(failed)) failed")
println("="^60)

if !isempty(failed)
    println("\nFailed files:")
    for (file, err) in sort(collect(failed))
        println("\n--- $file ---")
        println(err)
    end
end
