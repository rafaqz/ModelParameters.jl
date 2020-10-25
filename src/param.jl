
"""
Abstract supertype for parameters. 

An `AbstractParam` must define a `fields` method that returns a namedtuple,
and a constructor that accepts a namedtuple. It must have a `val` property, 
and should use `checkhasval` on it's input in its constructor if it holds a 
`NamedTuple`.
"""
abstract type AbstractParam{T} <: AbstractNumbers.AbstractNumber{T} end


# units field special-casing trait
struct WithUnits end
struct NoUnits end

hasunits(p::AbstractParam) = 
    hasfield(typeof(fields(p)), :units) ? WithUnits() : NoUnits()


"""
    val(m::AbstractParam)
    val(NoUnits(), m::AbstractParam)

If there is a units field val will include the units. 
This design is so that units don't have to be repeatedy used 
on value and bounds, and can be in separate columns in tables.

If you want `val` with no units when there is a units fiels, you
can explicitly call `val(NoUnits(), x)`.
"""
val(p::AbstractParam) = val(hasunits(p), p)

val(::NoUnits, p::AbstractParam) = p.val
val(::WithUnits, p::AbstractParam) = val(WithUnits(), p.units, p)
val(::WithUnits, units::Nothing, p::AbstractParam) = p.val
val(::WithUnits, units, p::AbstractParam) = p.val * units

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
AbstractNumbers.number(p::AbstractParam) = val(p)
AbstractNumbers.basetype(::Type{<:AbstractParam{T}}) where T = T 
AbstractNumbers.like(::Type{<:AbstractParam}, x) = x



# Methods for objects that hold params

simplify(x, nm=:val) = Flatten.modify(f -> getproperty(f, nm), x, AbstractParam)

params(x) = Flatten.flatten(x, AbstractParam)

field(x, nm::Symbol=:value) = map(f -> getproperty(f, nm), params(x))
field(x, i::Int) =  map(f -> f[i], params(x))

checkhasparam(x) =
    hasparam(x) || throw(ArgumentError("model has no `Param` fields"))

hasparam(x) = length(params(x)) > 0


"""
    Param(p::NamedTuple)
    Param(; kw...)
    Param(val)

A wrapper type that lets you extract model parameters and metadata about the model like
bounding val, units priors, or anything else you want to attach.

The first argument is assigned to the `val` field, and if only keyword arguments are used,
`val`, must be one of them. `val` is used as the number val if the model us run
without stripping out the `Param` fields. `simplify` also takes only the `:val` field.
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

"""
    fields(p::Param)

Returns a `NamedTuple` of the parameter fields.
"""
fields(p::Param) = getfield(p, :fields)


# Utils

checkhasval(nt::NamedTuple{Keys}) where {Keys} = 
    first(Keys) == :val || _novalerror(nt)
# @noinline avoids allocations unless there is actually an error
@noinline _novalerror(nt) =
    throw(ArgumentError("First field of Param must be :val"))


