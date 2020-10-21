
"""
Abstract supertype for Params, useful if you need to extend 
the behaviour of this package.
"""
abstract type AbstractParam <: Number end

"""
    Param(p::NamedTuple)
    Param(; kwargs...)
    Param(val)
    Param(value, bounds)

A wrapper type that lets you extract model parameters and metadata about the model like 
bounding values, units priors, or anything else you want to attach.

The first field is special - it it used as the number value if the model us run without
stripping out the `Param` fields. `strip` also assumes that the first field is the value 
to keep in the model.
"""
struct Param{T<:NamedTuple} <: AbstractParam
    fields::T
end
Param(; kwargs...) = Param((; kwargs...))
Param(value) = Param(; value=value)
Param(value, bounds) = Param(; value=value, bounds=bounds)

"""
    fields(p::Param)

Returns a `NamedTuple` of the parameter fields.
"""
fields(p::Param) = getfield(p, :fields)

Base.getproperty(p::Param, x) = getproperty(fields(p), x)
Base.getindex(p::Param, i) = getindex(fields(p), i)
Base.keys(p::Param) = keys(fields(p))

@inline strip(x, nm=:value) = Flatten.modify(f -> getproperty(f, nm), model, AbstractParam)
param(x, nm::Symbol=:value) =  map(f -> getproperty(f, nm), flatparams(x))
param(x, i::Int) =  map(f -> f[i], flatparams(x))

flatparams(x) = Flatten.flatten(x, AbstractParam)
firstparam(x) = first(flatparams(x))
