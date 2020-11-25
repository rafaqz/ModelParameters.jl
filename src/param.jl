"""
Abstract supertype for parameters. Theses are wrappers for model parameter values and 
metadata that are returned from [`params`](@ref), and used in 
`getfield/setfield/getpropery/setproperty` methods and to generate the Tables.jl interface. 
They are stripped from the model with [`stripparams`](@ref).

An `AbstractParam` must define a `Base.parent` method that returns a `NamedTuple`, and a
constructor that accepts a `NamedTuple`. It must have a `val` property, and should use
`checkhasval` in its constructor.
"""
abstract type AbstractParam{T} <: AbstractNumbers.AbstractNumber{T} end

@inline withunits(m, args...) = map(p -> withunits(p, args...), params(m))
@inline function withunits(p::AbstractParam, fn::Symbol=:val)
    _applyunits(*, getproperty(p, fn), get(p, :units, nothing))
end

@inline stripunits(m, xs) = map(stripunits, params(m), xs)
@inline function stripunits(p::AbstractParam, x)
    _applyunits(/, x, get(p, :units, nothing))
end

# Param might have `nothing` for units
@inline _applyunits(f, x, units) = f(x, units)
@inline _applyunits(f, x, ::Nothing) = x
@inline _applyunits(f, xs::Tuple, units) = map(x -> f(x, units), xs)
@inline _applyunits(f, xs::Tuple, units::Nothing) = xs
@inline _applyunits(f, ::Nothing, units) = nothing
@inline _applyunits(f, ::Nothing, ::Nothing) = nothing

# Base NamedTuple-like interface
Base.keys(p::AbstractParam) = keys(parent(p))
# Base.values has the potential to be confusing, as we
# have a val field in Param.  Not sure what to do about this.
Base.values(p::AbstractParam) = values(parent(p))
@inline Base.propertynames(p::AbstractParam) = propertynames(parent(p))
@inline Base.getproperty(p::AbstractParam, x::Symbol) = getproperty(parent(p), x)
@inline Base.get(p::AbstractParam, key::Symbol, default) = get(parent(p), key, default)
@inline Base.getindex(p::AbstractParam, i) = getindex(parent(p), i)


# AbstractNumber interface
Base.convert(::Type{Number}, x::AbstractParam) = number(x)
Base.convert(::Type{P}, x::P) where {P<:AbstractParam} = x
AbstractNumbers.number(p::AbstractParam) = withunits(p)
AbstractNumbers.basetype(::Type{<:AbstractParam{T}}) where T = T
AbstractNumbers.like(::Type{<:AbstractParam}, x) = x

# Flatten.jl defaults defined here: AbstractParam needs to be defined first
const SELECT = AbstractParam
const IGNORE = AbstractArray

# Concrete implementation

"""
    Param(p::NamedTuple)
    Param(; kw...)
    Param(val)

A wrapper type that lets you extract model parameters and metadata about the model like
bounding val, units priors, or anything else you want to attach.

The first argument is assigned to the `val` field, and if only keyword arguments are used,
`val`, must be one of them. `val` is used as the number val if the model us run
without stripping out the `Param` fields. `stripparams` also takes only the `:val` field.
"""
struct Param{T,P<:NamedTuple} <: AbstractParam{T}
    parent::P
end
Param(nt::NT) where {NT<:NamedTuple} = begin
    _checkhasval(nt)
    Param{typeof(nt.val),NT}(nt)
end
Param(val; kwargs...) = Param((; val=val, kwargs...))
Param(; kwargs...) = Param((; kwargs...))

Base.parent(p::Param) = getfield(p, :parent)

# Methods for objects that hold params
params(x) = Flatten.flatten(x, SELECT, IGNORE)
stripparams(x) = hasparam(x) ? Flatten.reconstruct(x, withunits(x), SELECT, IGNORE) : x


# Utils
hasparam(obj) = length(params(obj)) > 0

_checkhasval(nt::NamedTuple{Keys}) where {Keys} = first(Keys) == :val || _novalerror(nt)
# @noinline avoids allocations unless there is actually an error
@noinline _novalerror(nt) = throw(ArgumentError("First field of Param must be :val"))
