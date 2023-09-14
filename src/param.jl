"""
Abstract supertype for parameters. Theses are wrappers for model parameter values and 
metadata that are returned from [`params`](@ref), and used in 
`getfield/setfield/getpropery/setproperty` methods and to generate the Tables.jl interface. 
They are stripped from the model with [`stripparams`](@ref).

An `AllParams` must define a `Base.parent` method that returns a `NamedTuple`, and a
constructor that accepts a `NamedTuple`. It must have a `val` property, and should use
`checkhasval` in its constructor.
"""
abstract type AbstractParam{T} <: AbstractNumbers.AbstractNumber{T} end
abstract type AbstractRealParam{T} <: AbstractNumbers.AbstractReal{T} end
abstract type AbstractArrayParam{T,N} <: AbstractArray{T,N} end
# We probably want this too, but the julia number system 
# does not make it possible: 
# abstract type AbstractComplexParam{T} <: AbstractComplex end

const AllParams = Union{AbstractParam,AbstractRealParam,AbstractArrayParam}

function ConstructionBase.setproperties(p::P, patch::NamedTuple) where P <: AllParams
    fields = ConstructionBase.setproperties(parent(p), patch)
    P.name.wrapper(fields)
end

@inline withunits(m, args...) = map(p -> withunits(p, args...), params(m))
@inline function withunits(p::AllParams, fn::Symbol=:val)
    _applyunits(*, getproperty(p, fn), get(p, :units, nothing))
end

@inline stripunits(m, xs) = map(stripunits, params(m), xs)
@inline function stripunits(p::AllParams, x)
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
Base.keys(p::AllParams) = keys(parent(p))
# Base.values has the potential to be confusing, as we
# have a val field in Param.  Not sure what to do about this.
Base.values(p::AllParams) = values(parent(p))
@inline Base.propertynames(p::AllParams) = propertynames(parent(p))
@inline Base.getproperty(p::AllParams, x::Symbol) = getproperty(parent(p), x)
@inline Base.get(p::AllParams, key::Symbol, default) = get(parent(p), key, default)
@inline Base.getindex(p::AllParams, i) = getindex(parent(p), i)

Base.@assume_effects foldable rebuild(p::T, newval) where T<:AllParams = T.name.wrapper(newval)

# AbstractNumber interface
Base.convert(::Type{Number}, x::Union{AbstractParam,AbstractRealParam}) = AbstractNumbers.number(x)
Base.convert(::Type{P}, x::P) where {P<:Union{AbstractParam,AbstractRealParam}} = x
AbstractNumbers.number(p::Union{AbstractParam,AbstractRealParam}) = withunits(p)
AbstractNumbers.basetype(::Type{<:Union{<:AbstractParam{T},<:AbstractRealParam{T}}}) where T = T
AbstractNumbers.like(::Type{<:Union{AbstractParam,AbstractRealParam}}, x) = x

# Flatten.jl defaults defined here: AbstractParam needs to be defined first
const SELECT = AllParams
const IGNORE = AbstractDict # What else to blacklist?

# Concrete implementations

# We define multiple param types due to shortcomings in julias type system.
# `RealParam` is required to subtype real and be useful in e.g. Distributions.jl
# `ArrayParam` is required to have whole arrays as variables.

const PARAMDESCRIPTION = """
The first argument is assigned to the `val` field, and if only keyword arguments are used,
`val`, must be one of them. `val` is used as the number val if the model us run
without stripping out the `Param` fields. `stripparams` also takes only the `:val` field."""

"""
    Param(p::NamedTuple)
    Param(; kw...)
    Param(val)

A wrapper type that lets you extract model parameters and metadata about the model like
bounding val, units priors, or anything else you want to attach.

$PARAMDESCRIPTION
"""
struct Param{T,P<:NamedTuple} <: AbstractParam{T}
    parent::P
end
function Param(nt::NT) where {NT<:NamedTuple}
    _checkhasval(nt)
    Param{typeof(nt.val),NT}(nt)
end

"""
    RealParam(p::NamedTuple)
    RealParam(; kw...)
    RealParam(val)

A wrapper type that lets you extract `Real` typed model parameters and metadata 
about the model like bounding val, units priors, or anything else you want to attach.

$PARAMDESCRIPTION
"""
struct RealParam{T,P<:NamedTuple} <: AbstractRealParam{T}
    parent::P
end
function RealParam(nt::NT) where {NT<:NamedTuple}
    _checkhasval(nt)
    RealParam{typeof(nt.val),NT}(nt)
end

"""
    ArrayParam(p::NamedTuple)
    ArrayParam(; kw...)
    ArrayParam(val)

A wrapper type that lets you extract `AbstractArray` typed model parameters and metadata 
about the model like bounding val, units priors, or anything else you want to attach.

$PARAMDESCRIPTION
"""
struct ArrayParam{T,N,P<:NamedTuple} <: AbstractArrayParam{T,N}
    parent::P
end
function ArrayParam(nt::NT) where {NT<:NamedTuple}
    _checkhasval(nt)
    A = nt.val
    ArrayParam{eltype(nt.val),ndims(nt.val),NT}(nt)
end

for P in (:Param, :RealParam, :ArrayParam) 
    @eval begin
        $P(val; kwargs...) = $P((; val=val, kwargs...))
        $P(; kwargs...) = $P((; kwargs...))
        Base.parent(p::$P) = getfield(p, :parent)
    end
end

# AbstractArray interface
Base.iterate(A::ArrayParam) = iterate(parent(A))
Base.size(A::ArrayParam) = size(parent(A))
Base.firstindex(A::ArrayParam) = firstindex(parent(A))
Base.lastindex(A::ArrayParam) = lastindex(parent(A))

# Methods for objects that hold params
params(x) = Flatten.flatten(x, SELECT, IGNORE)
stripparams(x) = hasparam(x) ? Flatten.reconstruct(x, withunits(x), SELECT, IGNORE) : x


# Utils
hasparam(obj) = length(params(obj)) > 0

_checkhasval(nt::NamedTuple{Keys}) where {Keys} = first(Keys) == :val || _novalerror(nt)
# @noinline avoids allocations unless there is actually an error
@noinline _novalerror(nt) = throw(ArgumentError("First field of Param must be :val"))
