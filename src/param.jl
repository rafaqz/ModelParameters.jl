# We define multiple param types due to shortcomings in julias type system.
# `RealParam` is required to subtype real and be useful in e.g. Distributions.jl
#
"""
     AbstractParam <: AbstractNumbers.AbstractNumber

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

# We probably want this too, but the julia number system doesnt make it possible:
# abstract type AbstractComplexParam{T} <: AbstractComplex end

"""
     AbstractConst <: AbstractNumbers.AbstractNumber

Abstract supertype for constants. Theses are wrappers for model constant values and
metadata that are returned from [`constants`](@ref).

They behave exactly like Param, so that it is easy to define specific
variables as a parameter or a constant with minimal effort.
"""
abstract type AbstractConst{T} <: AbstractNumbers.AbstractNumber{T} end
abstract type AbstractRealConst{T} <: AbstractNumbers.AbstractReal{T} end

const AllParams = Union{AbstractParam,AbstractRealParam}
const AllConst = Union{AbstractConst,AbstractRealConst}
const AllParamsOrConst = Union{AllParams,AllConst}

function ConstructionBase.setproperties(p::P, patch::NamedTuple) where P<:AllParamsOrConst
    fields = ConstructionBase.setproperties(parent(p), patch)
    P.name.wrapper(fields)
end

for (P, T) in ((:Param, :Number), (:RealParam, :Real), (:Const, :Number), (:RealConst, :Real))
    AP = Symbol(:Abstract, P)
    AT = Symbol(:Abstract, T)
    matchingparam = P == :Const ? :Param : :RealParam
    docstring = if P in (:Param, :RealParam) 
        """
            $P(p::NamedTuple)
            $P(; kw...)
            $P(val)

        A wrapper type that lets you extract all `Number` typed model parameters and their 
        metadata, like bounding val, units priors, or anything else you want to attach.

        The first argument is assigned to the `val` field, and if only keyword arguments are used,
        `val`, must be one of them. `val` is used as the number val if the model us run
        without stripping out the `Param` fields. `stripparams` also takes only the `:val` field.
        """
    else
        """
            $P(p::NamedTuple)
            $P(; kw...)
            $P(val)

        A constant that otherwise behaves like a $matchingparam. It will not be returns by 
        `params` but instead by `constants`.

        The purpose is to allow easily removing paramters from optimisation or interactive
        plots, by switching them from $matchingparam to $P.
        """
    end
    @eval begin
        # Methods on abstract types
        # Base NamedTuple-like interface
        Base.keys(p::$AP) = keys(parent(p))
        # Base.values has the potential to be confusing, as we
        # have a val field in Param.  Not sure what to do about this.
        Base.values(p::$AP) = values(parent(p))
        @inline Base.propertynames(p::$AP) = propertynames(parent(p))
        @inline Base.getproperty(p::$AP, x::Symbol) = getproperty(parent(p), x)
        @inline Base.get(p::$AP, key::Symbol, default) = get(parent(p), key, default)
        @inline Base.getindex(p::$AP, i) = getindex(parent(p), i)
        @inline Base.getindex(p::$AP) = getindex(p.val)
        # We have some inconsistencies here... is is a Number or a NamedTuple
        @inline Base.getindex(p::$AP, I::Integer...) = getindex(parent(p), I...)
        @inline Base.getindex(p::$AP, i::CartesianIndex{0}) = getindex(parent(p), i)
        Base.convert(::Type{<:P}, x::P) where {P<:$AP} = x
        # For ambiguity
        Base.convert(::Type{<:$T}, x::$AP) = AbstractNumbers.number(x)
        Base.convert(::Type{AN}, p::$AP) where {T,AN<:AbstractNumbers.$AT{T}} = convert(AN, p.val)
        # AbstractNumber interface
        AbstractNumbers.number(p::$AP) = withunits(p)
        AbstractNumbers.basetype(::Type{<:$AP{T}}) where T = T
        AbstractNumbers.like(::Type{<:$AP}, x) = x
        # For ambiguity
        AbstractNumbers.like(::Type{<:$AP}, xs::Tuple) = AbstractNumbers.like.(xs)

        # Concrete implementations
        struct $P{T<:$T,P<:NamedTuple} <: $AP{T}
            parent::P
            function $P{T,P}(nt::P) where {T<:$T,P<:NamedTuple}
                _checkhasval(T, nt)
                new{T,P}(nt)
            end
        end
        # Constructors
        $P(val::$T; kwargs...) = $P((; val=val, kwargs...))
        $P(nt::NT) where {NT<:NamedTuple} = $P{typeof(nt.val),NT}(nt)
        $P(; kwargs...) = $P((; kwargs...))
        # Add a docstring
        @doc $docstring $P 

        rebuild(p::$P, newval) = $P(newval)
        Base.parent(p::$P) = getfield(p, :parent)
    end
end

# Flatten.jl defaults defined here: AbstractParam needs to be defined first
const SELECTPARAM = AllParams
const SELECTCONST = AllConst
const SELECTALL = Union{AllParams,AllConst}
const IGNORE = Union{AbstractDict,Array}  # What else to blacklist?

params(x) = Flatten.flatten(x, SELECTPARAM, IGNORE)
constants(x) = Flatten.flatten(x, SELECTCONST, IGNORE)
paramsandconstants(x) = Flatten.flatten(x, SELECTALL, IGNORE)

reconstructparams(obj, newparams) = 
    Flatten.reconstruct(obj, newparams, SELECTPARAM, IGNORE)
reconstructconstants(obj, newparams) = 
    Flatten.reconstruct(obj, newparams, SELECTCONST, IGNORE)

@inline paramswithunits(m, args...) = map(p -> withunits(p, args...), params(m))
@inline constantswithunits(m, args...) = map(p -> withunits(p, args...), constants(m))

strip(x) = hasparamorconstant(x) ? Flatten.reconstruct(x, map(withunits, paramsandconstants(x)), SELECTALL, IGNORE) : x

hasparam(obj) = length(params(obj)) > 0
hasconstant(obj) = length(constants(obj)) > 0
hasparamorconstant(obj) = length(paramsandconstants(obj)) > 0

@inline withunits(p::AllParamsOrConst, fn::Symbol=:val) =
    _applyunits(*, getproperty(p, fn), get(p, :units, nothing))

@inline stripunits(m, xs) = map(stripunits, paramsandconstants(m), xs)
@inline stripunits(p::AllParamsOrConst, x) = _applyunits(/, x, get(p, :units, nothing))

@deprecate stripparams strip

# Param might have `nothing` for units
@inline _applyunits(f, x, units) = f(x, units)
@inline _applyunits(f, x, ::Nothing) = x
@inline _applyunits(f, xs::Tuple, units) = map(x -> f(x, units), xs)
@inline _applyunits(f, xs::Tuple, units::Nothing) = xs
@inline _applyunits(f, ::Nothing, units) = nothing
@inline _applyunits(f, ::Nothing, ::Nothing) = nothing

function _checkhasval(::Type{T}, nt::NamedTuple{Keys}) where {T,Keys}
    first(Keys) == :val || _novalerror(nt)
    nt.val isa T || _valtypeerror(T, nt)
end
# @noinline avoids allocations unless there is actually an error
@noinline _novalerror(nt) = throw(ArgumentError("First field of Param must be :val"))
@noinline _valtypeerror(T, nt) = throw(ArgumentError("Expected val field to be of type $T, got $(nt.val)"))
