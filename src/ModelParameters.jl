module ModelParameters
# Use the README as the module docs
@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    read(path, String)
end ModelParameters

import AbstractNumbers,
       ConstructionBase,
       Flatten,
       PrettyTables, 
       Setfield,
       Tables 
      
export AbstractModel, MutableModel, Model, StaticModel

export AbstractParam, Param

export params, paramval, simplify, update, update!

include("interface.jl")
include("param.jl")
include("model.jl")
include("tables.jl")

end
