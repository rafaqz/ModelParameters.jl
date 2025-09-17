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
       Tables

using Setfield

export AbstractModel, Model, StaticModel, MakieModel

export AbstractParam, Param, RealParam

export flatparams, printparams, stripparams, update, update!, withunits, stripunits, groupparams, mapflat

include("interface.jl")
include("param.jl")
include("model.jl")
include("tables.jl")
include("makie.jl")

end
