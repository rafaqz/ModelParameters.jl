
"""
Abstract supertype for Params, useful if you need to extend
the behaviour of this package.
"""
abstract type AbstractParam <: Number end

"""
    Param(p::NamedTuple)
    Param(; kw...)
    Param(val)
    Param(value, bounds)

A wrapper type that lets you extract model parameters and metadata about the model like
bounding values, units priors, or anything else you want to attach.

The first argument is assigned to the `value` field, and if only keyword arguments are used,
`value`, must be one of them. `value` is used as the number value if the model us run
without stripping out the `Param` fields. `strip` also takes only the `:value` field.
"""
struct Param{T<:NamedTuple} <: AbstractParam
    fields::T
    Param{T}(nt) where {T<:NamedTuple} = begin
        hasfield(T, :value) || _novaluerror(nt)
        new{T}(nt)
    end
end
Param(; kwargs...) = Param((; kwargs...))
Param(value; kwargs...) = Param(; value=value, kwargs...)

# @noinline avoids allocations unless there is actually an error
@noinline _novaluerror(nt) =
    throw(ArgumentError("Param $nt has no field :value"))

"""
    fields(p::Param)

Returns a `NamedTuple` of the parameter fields.
"""
fields(p::Param) = getfield(p, :fields)
val(p::Param) = fields(p).val

Base.getproperty(p::Param, x) = getproperty(fields(p), x)
Base.getindex(p::Param, i) = getindex(fields(p), i)
Base.get(p::Param, key::Symbol, default) =
    hasfield(fields(p), x) ? getproperty(fields(p), x) : default
Base.keys(p::Param) = keys(fields(p))
Base.values(p::Param) = values(fields(p))

@inline strip(x, nm=:value) = Flatten.modify(f -> getproperty(f, nm), model, AbstractParam)

field(x, nm::Symbol=:value) = map(f -> getproperty(f, nm), param(x))
field(x, i::Int) =  map(f -> f[i], param(x))

param(x) = Flatten.flatten(x, AbstractParam)
strip(x) = modify(p -> p.value, x, AbstractParam)

checkhasparam(inner) =
    hasparam(inner) || throw(ArgumentError("model has no `Param` fields"))

hasparam(x) = length(param(inner)) > 0
