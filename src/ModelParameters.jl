module ModelParameters
# Use the README as the module docs
@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    read(path, String)
end ModelParameters

using AbstractNumbers,
      ConstructionBase,
      Flatten,
      PrettyTables, 
      Setfield,
      Tables
      
export AbstractModel, MutableModel, Model, StaticModel

export Param, AbstractParam

export params, paramvals, simplify, update, update!

include("param.jl")
include("model.jl")
include("tables.jl")

end
