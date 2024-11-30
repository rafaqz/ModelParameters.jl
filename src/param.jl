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
# We probably want this too, but the julia number system
# does not make it possible:
# abstract type AbstractComplexParam{T} <: AbstractComplex end

const AllParams = Union{AbstractParam,AbstractRealParam}

function ConstructionBase.setproperties(p::P, patch::NamedTuple) where P<:AllParams
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

for P in (:AbstractParam, :AbstractRealParam)
    @eval begin
        # Base NamedTuple-like interface
        Base.keys(p::$P) = keys(parent(p))
        # Base.values has the potential to be confusing, as we
        # have a val field in Param.  Not sure what to do about this.
        Base.values(p::$P) = values(parent(p))
        @inline Base.propertynames(p::$P) = propertynames(parent(p))
        @inline Base.getproperty(p::$P, x::Symbol) = getproperty(parent(p), x)
        @inline Base.get(p::$P, key::Symbol, default) = get(parent(p), key, default)
        @inline Base.getindex(p::$P, i) = getindex(parent(p), i)
        @inline Base.getindex(p::$P) = getindex(p.val)
        # We have some inconsistencies here... is is a Number or a NamedTuple
        @inline Base.getindex(p::$P, I::Integer...) = getindex(parent(p), I...)
        @inline Base.getindex(p::$P, i::CartesianIndex{0}) = getindex(parent(p), i)

        # AbstractNumber interface
        Base.convert(::Type{<:P}, x::P) where {P<:$P} = x
        AbstractNumbers.number(p::$P) = withunits(p)
        AbstractNumbers.basetype(::Type{<:$P{T}}) where T = T
        AbstractNumbers.like(::Type{<:$P}, x) = x
    end
end

# For Ambiguity
AbstractNumbers.like(::Type{<:AbstractRealParam}, xs::Tuple) = AbstractNumbers.like.(xs)
AbstractNumbers.like(::Type{<:AbstractParam}, ::Tuple) = AbstractNumbers.like.(xs)
Base.convert(::Type{<:Real}, x::AbstractRealParam) = AbstractNumbers.number(x)
Base.convert(::Type{<:Number}, x::AbstractParam) = AbstractNumbers.number(x)
Base.convert(::Type{AN}, p::AbstractRealParam) where {T,AN<:AbstractNumbers.AbstractReal{T}} = convert(AN, p.val)
Base.convert(::Type{AN}, p::AbstractParam) where {T,AN<:Union{AbstractNumbers.AbstractNumber{T}, AbstractNumbers.AbstractReal{T}}} = convert(AN, p.val)

# Flatten.jl defaults defined here: AbstractParam needs to be defined first
const SELECT = AllParams
const IGNORE = Union{AbstractDict, Array}  # What else to blacklist?

# Concrete implementations

# We define multiple param types due to shortcomings in julias type system.
# `RealParam` is required to subtype real and be useful in e.g. Distributions.jl

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
struct Param{T<:Number,P<:NamedTuple} <: AbstractParam{T}
    parent::P
    function Param{T,P}(nt::P) where {T<:Number,P<:NamedTuple}
        _checkhasval(T, nt)
        new{T,P}(nt)
    end
end
function Param(nt::NT) where {NT<:NamedTuple}
    Param{typeof(nt.val),NT}(nt)
end

rebuild(p::Param, newval) = Param(newval)

"""
    RealParam(p::NamedTuple)
    RealParam(; kw...)
    RealParam(val)

A wrapper type that lets you extract `Real` typed model parameters and metadata
about the model like bounding val, units priors, or anything else you want to attach.

$PARAMDESCRIPTION
"""
struct RealParam{T<:Real,P<:NamedTuple} <: AbstractRealParam{T}
    parent::P
    function RealParam{T,P}(nt::P) where {T<:Real,P<:NamedTuple}
        _checkhasval(T, nt)
        new{T,P}(nt)
    end
end
function RealParam(nt::NT) where {NT<:NamedTuple}
    RealParam{typeof(nt.val),NT}(nt)
end

rebuild(p::RealParam, newval) = RealParam(newval)

for P in (:Param, :RealParam)
    @eval begin
        Base.parent(p::$P) = getfield(p, :parent)
        $P(; kwargs...) = $P((; kwargs...))
    end
end
RealParam(val::Real; kwargs...) = RealParam((; val=val, kwargs...))
Param(val::Number; kwargs...) = Param((; val=val, kwargs...))

# Methods for objects that hold params
params(x) = Flatten.flatten(x, SELECT, IGNORE)
stripparams(x) = hasparam(x) ? Flatten.reconstruct(x, withunits(x), SELECT, IGNORE) : x


# Utils
hasparam(obj) = length(params(obj)) > 0

function _checkhasval(::Type{T}, nt::NamedTuple{Keys}) where {T,Keys}
    first(Keys) == :val || _novalerror(nt)
    nt.val isa T || _valtypeerror(T, nt)
end
# @noinline avoids allocations unless there is actually an error
@noinline _novalerror(nt) = throw(ArgumentError("First field of Param must be :val"))
@noinline _valtypeerror(T, nt) = throw(ArgumentError("Expected val field to be of type $T, got $(nt.val)"))
