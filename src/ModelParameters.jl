module ModelParameters
# Use the README as the module docs
@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    read(path, String)
end ModelParameters

using Flatten,
      PrettyTables, 
      Tables
      
export Model, Param

export params, strip, update

include("param.jl")
include("model.jl")
include("tables.jl")

end
