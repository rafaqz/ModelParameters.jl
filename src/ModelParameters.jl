module ModelParameters
# Use the README as the module docs
@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    read(path, String)
end ModelParameters

import AbstractNumbers,
       ConstructionBase,
       ConstructionBaseExtras,
       Flatten,
       PrettyTables, 
       Tables 

using Setfield
      
export AbstractModel, Model, StaticModel

export AbstractParam, Param

export params, printparams, stripparams, update, update!, withunits, stripunits, group, flat

include("interface.jl")
include("param.jl")
include("model.jl")
include("tables.jl")

end
