using GeoArrow
using Documenter

DocMeta.setdocmeta!(GeoArrow, :DocTestSetup, :(using GeoArrow); recursive=true)

makedocs(;
    modules=[GeoArrow],
    authors="Maarten Pronk <git@evetion.nl> and contributors",
    repo="https://github.com/evetion/GeoArrow.jl/blob/{commit}{path}#{line}",
    sitename="GeoArrow.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://evetion.github.io/GeoArrow.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/evetion/GeoArrow.jl",
    devbranch="main",
)
