
"""
Abstract supertype for model wrappers like `Model`, useful
if you need to extend the behaviour of this package.


# Accessing `AbstactModel` parameters

Fields can be accessed with `getindex`:

```julia
model = Model(obj)
@assert model[:val] isa Tuple
@assert model[:val] == model[:val]
@assert model[:units] == model[:units]
```

To get a combined Tuple of `val` and `units`, use [`withunits`](@ref).

The type name of the parent model component, and the field name are also available:

```julia
model[:component]
model[:fieldname]
```


## Getting a `Vector` of parameter values

`Base` methods `collect`, `vec`, and `Array` return a vector of the result of 
`model[:val]`. To get a vector of other parameter fields, simply `collect` the tuple:

```julian
boundsvec = collect(model[:bounds])
```


## Tables.jl interface

All `AbstractModel`s define the Tables.jl interface. This means their paremeters
and parameter metadata can be converted to a `DataFrame` or CSV very easily:

```julia
df = DataFrame(model)
```

Tables.rows will also return all `Param`s as a `Vector` of `NamedTuple`.

To update a model with params from a table, use `update!` or `update`:

```julia
update!(model, table)
```


## `AbstractModel` Interface: Defining your own model wrappers

It may be simplest to use `ModelParameters.jl` on a wrapper type you also use for other 
things. This is what DynamicGrids.jl does with `Ruleset`. It's straightforward to extend 
the interface, nearly everything is taken care of by inheriting from `AbstractModel`. But 
in some circumstances you will need to define additional methods.

`AbstractModel` uses `Base.parent` to return the parent model object.
Either use a field `:parent` on your `<: AbstractModel` type, or add a 
method to `Base.parent`. 

With a custom `parent` field you will also need to define a method for 
[`setparent!`](@ref) and [`setparent`](@ref) that sets the correct field.

An `AbstractModel` with complicated type parameters may require a method of 
`ConstructionBase.constructorof`.

To add custom `show` methods but still print the parameter table, you can use:

```julia
printparams(io::IO, model)
```

That should be all you need to do.
"""
abstract type AbstractModel end

Base.parent(m::AbstractModel) = getfield(m, :parent)
setparent(m::AbstractModel, newparent) = @set m.parent = newparent

params(m::AbstractModel) = params(parent(m))
strip(m::AbstractModel) = strip(parent(m))
function update(x::T, values) where {T<:AbstractModel}
    hasfield(T, :parent) || _updatenotdefined(T)
    setparent(x, update(parent(x), values))
end

@noinline _update_methoderror(T) = error("Interface method `update` is not defined for $T")

paramfieldnames(m) = Flatten.fieldnameflatten(parent(m), SELECTPARAM, IGNORE)
paramparenttypes(m) = Flatten.metaflatten(parent(m), _fieldparentbasetype, SELECTPARAM, IGNORE)
_fieldparentbasetype(T, ::Type{Val{N}}) where {N} = component(T)

"""
    component(::Type{T}) where T

Generates the identifier stored in the :component field of an `AbstractModel`. The default
implementation simply uses `T.name.wrapper` which is the `UnionAll` type corresponding to
the unparameterized type name of `T`.
"""
component(::Type{T}) where {T} = T.name.wrapper

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
Base.collect(m::AbstractModel) = collect(m.val)
Base.vec(m::AbstractModel) = collect(m)
Base.Array(m::AbstractModel) = vec(m)

# Dict methods - data as columns
Base.haskey(m::AbstractModel, key::Symbol) = key in keys(m)
Base.keys(m::AbstractModel) = _keys(params(m), m)

@inline function Base.setindex!(m::AbstractModel, x, nm::Symbol)
    if nm == :component
        erorr("cannot set :component index")
    elseif nm == :fieldname
        erorr("cannot set :fieldname index")
    else
        newparent = if nm in keys(m)
            _setindex(parent(m), Tuple(x), nm)
        else
            _addindex(parent(m), Tuple(x), nm)
        end
        setparent!(m, newparent)
    end
end
# TODO do this with lenses
@inline function _setindex(obj, xs::Tuple, nm::Symbol)
    lens = Setfield.PropertyLens{nm}()
    newparams = map(params(obj), xs) do par, x
        rebuild(par, Setfield.set(parent(par), lens, x))
    end
    return reconstructparam(obj, newparams)
end
@inline function _addindex(obj, xs::Tuple, nm::Symbol)
    lens = Setfield.ComposedLens(Setfield.PropertyLens{:parent}(), Setfield.PropertyLens{nm}())
    newparams = map(params(obj), xs) do par, x
        rebuild(par, (; parent(par)..., (nm => x,)...))
    end
    return reconstructparams(obj, newparams)
end

_keys(params::Tuple, m::AbstractModel) = (:component, :fieldname, keys(first(params))...)
_keys(params::Tuple{}, m::AbstractModel) = ()

@inline function Base.getindex(m::AbstractModel, nm::Symbol)
    if nm == :component
        paramparenttypes(m)
    elseif nm == :fieldname
        paramfieldnames(m)
    else
        map(p -> getindex(p, nm), params(m))
    end
end

function Base.show(io::IO, mime::MIME"text/plain", m::AbstractModel)
    show(io, mime, typeof(m))
    println(io, " with parent object of type: \n")
    show(io, mime, typeof(parent(m)))
    println(io, "\n\n")
    printparams(io::IO, m)
end

printparams(m) = printparams(stdout, m)
function printparams(io::IO, m::AbstractModel)
    if length(m) > 0
        println(io, "Parameters:")
        PrettyTables.pretty_table(io, m)
    end
end

setparent!(m::AbstractModel, newparent) = setfield!(m, :parent, newparent)

update!(m::AbstractModel, vals::AbstractVector{<:AllParams}) = update!(m, Tuple(vals))
function update!(params::Tuple{<:AllParams,Vararg{AllParams}})
    setparent!(m, reconstructparams(parent(m), params))
end
function update!(m::AbstractModel, table)
    cols = (c for c in Tables.columnnames(table) if !(c in (:component, :fieldname)))
    for col in cols
        setindex!(m, Tables.getcolumn(table, col), col)
    end
    m
end

"""
    Model(x)

A wrapper type for any model containing [`Param`](@ref) parameters - essentially marking 
that a custom struct or Tuple holds `Param` fields.

This allows you to index into the model as if it is a linear list of parameters, or named 
columns of values and paramiter metadata. You can treat it as an iterable, or use the 
Tables.jl interface to save or update the model to/from csv, a `DataFrame` or any source 
that implements the Tables.jl interface.
"""
mutable struct Model <: AbstractModel
    parent
    function Model(parent)
        # Need at least 1 AbstractParam field to be a Model
        if hasparam(parent)
            # Make sure all params have all the same keys.
            expandedpars = _expandkeys(params(parent))
            parent = reconstructparams(parent, expandedpars)
        else
            _noparamwarning()
        end
        new(parent)
    end
end
Model(m::AbstractModel) = Model(parent(m))

@inline @generated function _update_params(ps::P, values::Union{<:AbstractVector,<:Tuple}) where {N,P<:NTuple{N,AllParams}}
    expr = Expr(:tuple)
    for i in 1:N
        expr_i = quote
            par = ps[$i]
            rebuild(par, NamedTuple{keys(par)}((values[$i], Base.tail(parent(par))...)))
        end
        push!(expr.args, expr_i)
    end
    return expr
end

update(x, values) = _update(ModelParameters.params(x), x, values)
@inline function _update(p::P, x, values::Union{<:AbstractVector,<:Tuple}) where {N,P<:NTuple{N,AllParams}}
    @assert length(values) == N "values length must match the number of parameters"
    newparams = _update_params(p, values)
    reconstructparams(x, newparams)
end
@inline function _update(p::P, x, table) where {N,P<:NTuple{N,AllParams}}
    @assert size(table, 1) == N "number of rows must match the number of parameters"
    cols = (c for c in Tables.columnnames(table) if !(c in (:component, :fieldname)))
    newparams = map(p, tuple(1:N...)) do param, i
        Param(NamedTuple{keys(param)}(map(name -> Tables.getcolumn(table, name)[i], cols)))
    end
    return reconstructparams(x, newparams)
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
            reconstructparams(parent, expandedpars)
        else
            _noparamwarning()
        end
        # Make sure all params have all the same keys.
        new{typeof(parent)}(parent)
    end
end
StaticModel(m::AbstractModel) = StaticModel(parent(m))

# Model Utils

_expandpars(x) = reconstructparams(parent, _expandkeys(parent))
# Expand all Params to have the same keys, filling with `nothing`
# This probably will allocate due to `union` returning `Vector`
function _expandkeys(x)
    pars = params(x)
    allkeys = Tuple(union(map(keys, pars)...))
    _expandkeys1(pars, Val{allkeys}())
end
Base.@assume_effects :foldable function _expandkeys1(pars, ::Val{Keys}) where Keys
    return map(pars) do par
        vals = map(Keys) do key
            hasproperty(par, key) ? par[key] : nothing
        end
        rebuild(par, NamedTuple{Keys}(vals))
    end
end

_noparamwarning() = @warn "Model has no Param fields"

# Parameter grouping
"""
    groupparams(m::AbstractModel, cols::Symbol...)

Groups parameters in `m` hierarchically according to `cols`. A `Symbol` constructor must be defined for the value type of each
parameter field (e.g. `String`, `Symbol`, and `Int` would all be valid by default). The returned value is a nested named tuple
where the hierachical order follows the order of `cols`.

For example, we could group parameters first by component name, then by field name:

# Examples
```julia-repl
julia> groupparams(Model((a=Param(1.0), b=Param(2.0))), :component, :fieldname)
(NamedTuple = (a = ..., b = ...),)
```
"""
groupparams(m::AbstractModel) = m
groupparams(m::AbstractModel, cols::Symbol...) = _groupparams(m, cols...)
_groupparams(m) = [Param(NamedTuple(tuple(:val => p.val, (k => p[k] for k in keys(p) if k != :val)...))) for p in m]
function _groupparams(m, cols::Symbol...)
    col = first(cols)
    names = map(Symbol, Tables.getcolumn(Tables.columns(m), col))
    groupnames = Tuple(unique(names))
    return NamedTuple{groupnames}(Tuple(_groupparams(filter(x -> Symbol(x[col]) == n, collect(Tables.rows(m))), Base.tail(cols)...) for n in groupnames))
end

"""
    mapflat(f, collection; maptype::Type=Union{NamedTuple,Tuple,AbstractArray})

"Flattened" version of `map` where `f` is applied to all nested non-collection elements of `x`. The transformed result
is returned with the nested structure of the input `x` unchanged. Note that this differs from `flatmap` in functional
settings, which is typically just `map` followed by `flatten`.

# Examples
```julia-repl
julia> mapflat(x -> 2*x, (a = (b = (1,)), c = (d = (2,))))
(a = (b = (2,)), c = (d = (4,)))
```
"""
function mapflat(f, collection; maptype::Type{T}=Union{NamedTuple,Tuple,AbstractArray}) where {T}
    select(x) = f(x)
    select(x::T) = map(select, x)
    return map(select, collection)
end
