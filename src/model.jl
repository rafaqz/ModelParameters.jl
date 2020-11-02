
"""
Abstract supertype for model wrappers like `Model`, useful
if you need to extend the behaviour of this package.

# Accessing AbstactModel parameters

Fields can be accessed with `getproperty` or `getindex`:

```julian
model = Model(obj)
@assert model.val isa Tuple
@assert model.val == model[:val]
@assert model.units == model[:units]
```

To get a combined Tuple of `val` and `units`, use [`uval`](@ref).

The type name of the parent model component, and the field name are also available:

```julia
model.component
model.field
```


# Converting to a `Vector` of parameter values

`Base` methods `collect`, `vec`, and `Array`, return a vector of the result of 
[`uval`](@ref).

To get a vector of other parameter fields, simply `collect` the tuple:

```julian
boundsvec = collect(model.bounds)
```

## Tables.jl interface

Tables.rows will return all Params as a `Vector` of `NamedTuple`.


## `AbstractModel` Interface: Defining your own model wrappers

It may be simplest to use `ModelParameters` on a wrapper type you also use
for other things. It very straightforward to extend the interface. Nearly
everything is taken care of by inheriting from `AbstractModel`.

In some circumstances you will need to define additional methods.

`AbstractModel` uses `Base.parent` to return the parent model object.
Either use a field :parent on your `<: AbstractModel` type, or add a 
method to `Base.parent`. 

With a custom `parent` field you will also need to define a method for 
[`update`](@ref).

Complex type parameters may reuire a method of `ConstructionBase.constructorof`.

To add custom `show` methods but still print the parameter table, you can use

```julia
printparams(io::IO, model)
```

Thats should be all you need to do.
"""
abstract type AbstractModel end

Base.parent(m::AbstractModel) = getfield(m, :parent)

uval(m) = map(uval, params(m))
params(m::AbstractModel) = params(parent(m))
stripparams(m::AbstractModel) = stripparams(parent(m))
function update(x::T, values) where {T<:AbstractModel} 
    hasfield(T, :parent) || _updatenotdefined(T)
    T(update(parent(m), vals))
end

@noinline _update_methoderror(T) = error("Interface method `update` is not defined for $T")

paramfieldnames(m) = Flatten.fieldnameflatten(parent(m), AbstractParam)
paramparenttypes(m) = Flatten.metaflatten(parent(m), _fieldparentbasetype, AbstractParam)

_fieldparentbasetype(T, ::Type{Val{N}}) where N = T.name.wrapper


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
Base.collect(m::AbstractModel) = collect(uval(m))
Base.vec(m::AbstractModel) = collect(m)
Base.Array(m::AbstractModel) = vec(m)

# Dict methods - data as columns
Base.haskey(m::AbstractModel, key::Symbol) = key in keys(m)
Base.hasproperty(m::AbstractModel, key::Symbol) = haskey(m, key)
Base.keys(m::AbstractModel) = _keys(params(m), m)

_keys(params::Tuple, m::AbstractModel) = (:component, :field, keys(first(params))...)
_keys(params::Tuple{}, m::AbstractModel) = ()

@inline Base.getindex(m::AbstractModel, nm::Symbol) = getproperty(m, nm)
@inline function Base.getproperty(m::AbstractModel, nm::Symbol)
    if nm == :component
        paramparenttypes(m)
    elseif nm == :field
        paramfieldnames(m)
    else
        map(p -> getproperty(p, nm), params(m))
    end
end

function Base.show(io::IO, m::AbstractModel)
    show(typeof(m))
    println(io, " with parent object of type: \n")
    show(typeof(parent(m)))
    println(io, "\n\n")
    _printparams(io::IO, m)
end

printparams(m) = printparams(stdout, m)
printparams(io::IO, m) = printparams(io::IO, params(m))
function printparams(io::IO, m::Tuple)
    println(io, "Parameters:")
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

update!(m::MutableModel, vals::AbstractVector{<:AbstractParam}) = update!(m, Tuple(vals))
function update!(params::Tuple{<:AbstractParam,Vararg{<:AbstractParam}})
    setparent!(m, Flatten.reconstruct(parent(m), params, Param))
end
function update!(m::MutableModel, table)
    cols = (c for c in Tables.columnnames(table) if !(c in (:component, :field)))
    for col in cols
        setproperty!(m, col, Tables.getcolumn(table, col))
    end
    m
end

@inline Base.setindex!(m::MutableModel, x, nm::Symbol) = setproperty!(m, nm, x)
@inline function Base.setproperty!(m::MutableModel, nm::Symbol, x)
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
end

# TODO do this with lenses
@inline function _setproperty(obj, nm::Symbol, xs::Tuple)
    lens = Setfield.PropertyLens{nm}()
    newparams = map(params(obj), xs) do par, x
        Param(Setfield.set(fields(par), lens, x))
    end
    Flatten.reconstruct(obj, newparams, AbstractParam)
end
@inline function _addproperty(obj, nm::Symbol, xs::Tuple)
    newparams = map(params(obj), xs) do par, x
        Param((; fields(par)..., (nm => x,)...))
    end
    Flatten.reconstruct(obj, newparams, AbstractParam)
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
        if hasparam(parent)
            # Make sure all params have all the same keys.
            expandedpars = _expandkeys(params(parent))
            parent = Flatten.reconstruct(parent, expandedpars, AbstractParam)
        else
            _noparamwarning()
        end
        new(parent)
    end
end
Model(m::AbstractModel) = Model(parent(m))

_noparamwarning() = @warn "Model has no Param fields"


update(x, values::AbstractVector) = update(m, Tuple(vals))
function update(x, values)
    newparams = map(params(x), values) do param, value
        Param(NamedTuple{keys(param)}((value, Base.tail(fields(param))...)))
    end
    Flatten.reconstruct(x, newparams)
end

"""
    StaticModel(x)

Like [`Model`](@ref) but immutable. This means it can't be used as a
handle to add columns to your model or update it in a user interface.
"""
struct StaticModel{P} <: AbstractModel
    parent::P
    function StaticModel(parent)
        # Need at least 1 AbstractParam field to be a Model
        if hasparam(parent)
            expandedpars = _expandkeys(params(parent))
            parent = Flatten.reconstruct(parent, expandedpars, AbstractParam)
        else
            _noparamwarning()
        end
        # Make sure all params have all the same keys.
        new{typeof(parent)}(parent)
    end
end
StaticModel(m::AbstractModel) = StaticModel(parent(m))


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
