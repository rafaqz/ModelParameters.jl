module InteractModels
# Use the README as the module docs
@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    read(path, String)
end InteractModels

using Interact,
      Reexport

@reexport using ModelParameters

export InteractModel

include("interactive.jl")

end
