
"""
Abstract supertype for Model, useful if you need to extend
the behaviour of this package.
"""
abstract type AbstractModel{K,I} end

# units field special-casing trait
struct WithUnits end
struct NoUnits end

hasunits(m::AbstractModel) = hasfield(fields(m), :units) ? HasUnits() : NoUnits()

"""
    val(m::AbstractModel)
    val(NoUnits(), m::AbstractModel)

If there is a units field val will include the units. 
This design is so that units don't have to be repeatedy used 
on value and bounds, and can be in separate columns in tables.

If you want `val` with no units when there is a units fiels, you
can explicitly call `val(NoUnits(), x)`.
"""
val(m::AbstractModel) = val(hasunits(m), m)
val(::WithUnits, m::AbstractModel) = map(p -> p.val * p.units, params(inner(m)))
val(::NoUnits, m::AbstractModel) = map(val, params(inner(m)))

param(m::AbstractModel) = param(inner(m))
strip(m::AbstractModel) = strip(inner(m))

# Tuple-like indexing and iterables interface

# It may seem expensive always calling `param`, but flattening the 
# object occurs once at compile-time, and should have no cost here.
Base.length(m::AbstractModel) = length(param(m))
Base.size(m::AbstractModel) = (length(param(m)),)
Base.first(m::AbstractModel) = first(param(m))
Base.last(m::AbstractModel) = last(param(m))
Base.firstindex(m::AbstractModel) = 1
Base.lastindex(m::AbstractModel) = length(param(m))
Base.getindex(m::AbstractModel, i) = getindex(param(m), i)
Base.iterate(m::AbstractModel) = (first(param(m)), 1)
Base.iterate(m::AbstractModel, s) = s > length(m) ? nothing : (param(m)[s], s + 1)

# Vector methods
Base.collect(m::AbstractModel) = collect(val(m))
Base.vec(m::AbstractModel) = [v for v in val(m)]
Base.Array(m::AbstractModel) = vec(m)

# Dict methods - data as columns
Base.keys(m::AbstractModel{K}) where K = K
Base.getproperty(m::AbstractModel, nm::Symbol) = map(p -> getproperty(p, nm), param(m))


"""
    Model(x)

A wrapper type for any model containing [`Param`](@ref) parameters -
essentially marking that a custom struct or Tuple holds `Param` fields.

This allows you to index into the model as if it is a linear list of parameters,
treat it as an iterable, or use the Tables.jl interface to save or update the model 
to/from csv, a `DataFrame` or any source that implements the Tables.jl interface.
"""
mutable struct Model{K,I} <: AbstractModel{K,I}
    inner::I
end
Model(inner) = begin
    # Need at least 1 AbstractParam field to be a Model
    checkhasparam(inner)
    K = keys(first(param(inner)))
    Model{K,typeof(inner)}(inner)
end

"""
    inner(model::AbstractModel)

Get the original inner model without the `Model` wrapper.
"""
inner(m::Model) = m.inner

"""
    update(model::AbstractModel, vals::Tuple)

"""
update(m::Model, vals::AbstractArray) = update(m, Tuple(vals))
update(m::Model, vals::Tuple) = begin
    newparams = map(flatten(m.inner), values) do param, value
        @set param.fields.value = value
    end
    update(m, newparams)
end
update(m::Model, params::Tuple{<:Param,Vararg{<:Param}}) =
    m.inner = reconstruct(m.inner, params, Param) 
