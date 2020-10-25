using ModelParameters, InteractModels
using Documenter

makedocs(;
    modules=[ModelParameters, InteractModels],
    authors="Rafael Schouten <rafaelschouten@gmail.com> and contributors",
    repo="https://github.com/rafaqz/ModelParameters.jl/blob/{commit}{path}#L{line}",
    sitename="ModelParameters.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://rafaqz.github.io/ModelParameters.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/rafaqz/ModelParameters.jl",
)
