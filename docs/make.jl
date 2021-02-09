using LWFBrook90Julia
using Documenter

makedocs(;
    modules=[LWFBrook90Julia],
    authors="Fabian Bernhard",
    repo="https://github.com/fabern/LWFBrook90Julia.jl/blob/{commit}{path}#L{line}",
    sitename="LWFBrook90Julia.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://fabern.github.io/LWFBrook90Julia.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/fabern/LWFBrook90Julia.jl",
    devbranch = "main"
)