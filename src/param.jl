"""
Abstract supertype for parameters. 

An `AbstractParam` must define a `Base.parent` method that returns a `NamedTuple`, and a 
constructor that accepts a namedtuple. It must have a `val` property, and should use 
`checkhasval` on it's input in its constructor if it holds a `NamedTuple`.
"""
abstract type AbstractParam{T} <: AbstractNumbers.AbstractNumber{T} end


# units field special-casing trait
struct WithUnits end
struct NoUnits end

hasunits(p::AbstractParam) = hasfield(typeof(parent(p)), :units) ? WithUnits() : NoUnits()


"""
    unitfulval(m::AbstractParam)

If there is a units field val will include the units. This design is so that units don't 
have to be repeatedy used on value and bounds, and can be in separate columns in tables.
"""
uval(p::AbstractParam) = uval(hasunits(p), p)

# Param may not have units fields
_uval(::NoUnits, p::AbstractParam) = p.val
_uval(::WithUnits, p::AbstractParam) = _uval(p.val, p.units)
# Param might have `nothing` for units
_uval(val, ::Nothing) = val
_uval(val, units) = val * units


# Base NamedTuple-like interface
Base.keys(p::AbstractParam) = keys(fields(p))
# Base.values has the potential to be confusing, as we 
# have a val field in Param.  Not sure what to do about this.
Base.values(p::AbstractParam) = values(fields(p))
Base.propertynames(p::AbstractParam) = propertynames(fields(p))
Base.getproperty(p::AbstractParam, x::Symbol) = getproperty(fields(p), x)
Base.get(p::AbstractParam, key::Symbol, default) = get(fields(p), key, default)
Base.getindex(p::AbstractParam, i) = getindex(fields(p), i)


# AbstractNumber interface
Base.convert(::Type{Number}, x::AbstractParam) = number(x)
Base.convert(::Type{P}, x::P) where {P<:AbstractParam} = x
AbstractNumbers.number(p::AbstractParam) = paramval(p)
AbstractNumbers.basetype(::Type{<:AbstractParam{T}}) where T = T 
AbstractNumbers.like(::Type{<:AbstractParam}, x) = x


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
struct Param{T,N<:NamedTuple} <: AbstractParam{T}
    fields::N
end
Param(nt::N) where {N<:NamedTuple} = begin
    checkhasval(nt)
    Param{typeof(nt.val),N}(nt)
end
Param(val; kwargs...) = Param((; val=val, kwargs...))
Param(; kwargs...) = Param((; kwargs...))

fields(p::Param) = getfield(p, :fields)


# Methods for objects that hold params
params(x) = Flatten.flatten(x, AbstractParam)

stripparams(x, nm=:val) = Flatten.reconstruct(x, paramval(x), AbstractParam)


# Utils

checkhasparam(obj) = hasparam(obj) || throw(ArgumentError("model has no `Param` fields"))

hasparam(obj) = length(params(obj)) > 0

checkhasval(nt::NamedTuple{Keys}) where {Keys} = first(Keys) == :val || _novalerror(nt)
# @noinline avoids allocations unless there is actually an error
@noinline _novalerror(nt) = throw(ArgumentError("First field of Param must be :val"))
