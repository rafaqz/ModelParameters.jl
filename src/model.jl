
"""
Abstract supertype for model wrappers like `Model`, useful 
if you need to extend the behaviour of this package.


# Interface

`AbstractModel` uses `Base.parent` to return the parent model object. 
"""
abstract type AbstractModel end


Base.parent(m::AbstractModel) = getfield(m, :parent)

paramval(m::AbstractModel) = map(paramval, params(parent(m)))

params(m::AbstractModel) = params(parent(m))

paramfieldnames(m::AbstractModel) = Flatten.fieldnameflatten(parent(m), AbstractParam)
paramparenttypes(m::AbstractModel) = 
    Flatten.metaflatten(parent(m), _fieldparentbasetype_meta, AbstractParam)

simplify(m::AbstractModel) = simplify(parent(m))

_fieldparentbasetype_meta(T, ::Type{Val{N}}) where N = T.name.wrapper


# Tuple-like indexing and iterables interface

# It may seem expensive always calling `param`, but flattening the 
# object occurs once at compile-time, and should have very little cost here.
Base.length(m::AbstractModel) = length(params(m))
Base.size(m::AbstractModel) = (length(params(m)),)
Base.first(m::AbstractModel) = first(params(m))
Base.last(m::AbstractModel) = last(params(m))
Base.firstindex(m::AbstractModel) = 1
Base.lastindex(m::AbstractModel) = length(params(m))
Base.getindex(m::AbstractModel, i) = getindex(params(m), i)
Base.iterate(m::AbstractModel) = (first(params(m)), 1)
Base.iterate(m::AbstractModel, s) = s > length(m) ? nothing : (params(m)[s], s + 1)

# Vector methods
Base.collect(m::AbstractModel) = collect(paramvals(m))
Base.vec(m::AbstractModel) = [v for v in paramvals(m)]
Base.Array(m::AbstractModel) = vec(m)

# Dict methods - data as columns
Base.haskey(m::AbstractModel, key::Symbol) = key in keys(m) 
Base.hasproperty(m::AbstractModel, key::Symbol) = haskey(m, key)
Base.keys(m::AbstractModel) = (:component, :field, keys(first(params(m)))...)
@inline Base.getproperty(m::AbstractModel, nm::Symbol) = 
    if nm == :component
        paramparenttypes(m)
    elseif nm == :field
        paramfieldnames(m)
    else
        map(p -> getproperty(p, nm), params(m))
    end


Base.show(io::IO, m::AbstractModel) = begin
    show(typeof(m)) 
    println(io, " with parent object of type: \n")
    show(typeof(parent(m))) 
    println(io, "\n\nAnd parameters:")
    PrettyTables.pretty_table(io, m, [keys(m)...])
end


"""
Abstract supertype for mutable model wrappers

# Interface

`MutableModel` uses `Base.parent(model)` to return the parent 
object, and `setparent!(model, parent)` to update it. 
""" 
abstract type MutableModel <: AbstractModel end

setparent!(m::MutableModel, newparent) = setfield!(m, :parent, newparent)

@inline Base.setproperty!(m::MutableModel, nm::Symbol, x) = 
    if nm == :component
        erorr("cannot set :component property")
    elseif nm == :field
        erorr("cannot set :field property")
    else
        newparent = if nm in keys(m)
            _setproperty(parent(m), nm, Tuple(x))
        else 
            _addproperty(parent(m), nm, Tuple(x))
        end
        setparent!(m, newparent)
    end

# TODO do this with lenses
_setproperty(obj, nm::Symbol, xs::Tuple) = begin
    lens = Setfield.PropertyLens{nm}() 
    newparams = map(params(obj), xs) do par, x
        Param(Setfield.set(fields(par), lens, x))
    end
    Flatten.reconstruct(obj, newparams, AbstractParam)
end
_addproperty(obj, nm::Symbol, xs::Tuple) = begin
    newparams = map(params(obj), xs) do par, x
        Param((; fields(par)..., (nm => x,)...))
    end
    Flatten.reconstruct(obj, newparams, AbstractParam)
end

update!(m::MutableModel, vals::AbstractVector{<:AbstractParam}) = 
    update!(m, Tuple(vals))
update!(params::Tuple{<:AbstractParam,Vararg{<:AbstractParam}}) =
    setparent!(m, Flatten.reconstruct(parent(m), params, Param))
update!(m::MutableModel, table) = begin
    cols = (c for c in Tables.columnnames(table) if !(c in (:component, :field)))
    for col in cols
        setproperty!(m, col, Tables.getcolumn(table, col)) 
    end
    m
end

"""
    Model(x)

A wrapper type for any model containing [`Param`](@ref) parameters -
essentially marking that a custom struct or Tuple holds `Param` fields.

This allows you to index into the model as if it is a linear list of parameters, 
or named columns of values and paramiter metadata. You can treat it as an iterable, 
or use the Tables.jl interface to save or update the model to/from csv, a `DataFrame` 
or any source that implements the Tables.jl interface.
"""
mutable struct Model <: MutableModel
    parent
    function Model(parent)
        # Need at least 1 AbstractParam field to be a Model
        checkhasparam(parent)
        # Make sure all params have all the same keys.
        expandedpars = _expandkeys(params(parent))
        expanded = Flatten.reconstruct(parent, expandedpars, AbstractParam)
        new(expanded)
    end
end
Model(m::AbstractModel) = Model(parent(m))

struct IsaTable end
struct NotaTable end

hastable(x) = Tables.istable(x) ? IsATable() : NoaATable() 

update(x, values::AbstractVector) = update(m, Tuple(vals))
update(x, values) = begin
    newparams = map(params(x), values) do param, value
        Param(NamedTuple{keys(param)}((value, Base.tail(fields(param))...)))
    end
    Flatten.reconstruct(x, newparams)
end

"""
    StaticModel(x)

Like [`Model`](@ref) but immutable. This means it can't be used as a 
handle to say - add columns to your model.

You can instead rebuild it immutably. Mot operations on static model
are fast, many are completely compiled away. This means you can use 
methods on it in inner loops with no overhead.
"""
struct StaticModel{P} <: AbstractModel
    parent::P
    function StaticModel(parent)
        # Need at least 1 AbstractParam field to be a Model
        checkhasparam(parent)
        expandedpars = _expandkeys(params(parent))
        expanded = Flatten.reconstruct(parent, expandedpars, AbstractParam)
        # Make sure all params have all the same keys.
        new{typeof(expanded)}(expanded)
    end
end
StaticModel(m::AbstractModel) = StaticModel(parent(m))

update(x::StaticModel, values) = StaticModel(update(parent(m), vals))



# Model Utils

_expandpars(x) = Flatten.reconstruct(parent, _expandkeys(parent), AbstractParam)
# Expand all Params to have the same keys, filling with `nothing`
# This probably will allocate due to `union` returning `Vector`
function _expandkeys(x) 
    pars = params(x)
    allkeys = Tuple(union(map(keys, pars)...))
    newpars = map(pars) do par
        vals = map(allkeys) do key
            get(par, key, nothing)
        end
        Param(NamedTuple{allkeys}(vals))
    end
end
