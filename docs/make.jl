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
        "ModelParameters" => "index.md",
        "InteractModels" => "interactmodels.md",
    ],
)

deploydocs(;
    repo="github.com/rafaqz/ModelParameters.jl",
)
