
"""
Abstract supertype for Model, useful if you need to extend 
the behaviour of this package.
"""
abstract type AbstractModel end

"""
    Model(x)

A wrapper type for any model containing [`Param`](@ref) parameters - 
essentially marking that a custom struct or Tuple holds `Param` fields.

This lets you update model from csv, dataframe or any source that implements the
Tables.jl interface.
"""
mutable struct Model{T} <: AbstractModel
    model::T
end
