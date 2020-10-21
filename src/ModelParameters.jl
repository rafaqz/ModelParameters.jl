module ModelParameters

# Use the README as the module docs
@doc let
    path = joinpath(dirname(@__DIR__), "README.md")
    include_dependency(path)
    read(path, String)
end ModelParameters

using Tables, PrettyTables, Flatten

export Model, Param

export param, strip 

include("tables.jl")

end
