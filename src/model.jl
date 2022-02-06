
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
function setparent!(m::AbstractModel, newparent)
    setfield!(m, :parent, newparent)
    return m
end

params(m::AbstractModel) = params(parent(m))
stripparams(m::AbstractModel) = stripparams(parent(m))

"""
    component(::Type{T}) where T

Generates the identifier stored in the :component field of an `AbstractModel`. The default
implementation simply uses `T.name.wrapper` which is the `UnionAll` type corresponding to
the unparameterized type name of `T`.
"""
component(::Type{T}) where T = T.name.wrapper
component(T, ::Type{Val{N}}) where N = component(T)
paramfieldnames(m::AbstractModel) = Flatten.fieldnameflatten(parent(m), SELECT, IGNORE)
paramcomponents(m::AbstractModel) = Flatten.metaflatten(parent(m), component, SELECT, IGNORE)

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
        PrettyTables.pretty_table(io, m; header=[keys(m)...])
    end
end

# Tuple-like indexing and iterables interface

# It may seem expensive always calling `param`, but flattening the
# object occurs once at compile-time, and should have very little cost here.
Base.IndexStyle(::Type{<:AbstractModel}) = IndexCartesian()
Base.length(m::AbstractModel) = length(params(m))
Base.size(m::AbstractModel) = (length(params(m)), length(keys(m)))
Base.first(m::AbstractModel) = first(params(m))
Base.last(m::AbstractModel) = last(params(m))
Base.firstindex(m::AbstractModel) = 1
Base.lastindex(m::AbstractModel) = length(params(m))
Base.iterate(m::AbstractModel) = (first(params(m)), 1)
Base.iterate(m::AbstractModel, s) = s > length(m) ? nothing : (params(m)[s], s + 1)
Base.eachcol(m::AbstractModel) = (m[col] for col in keys(m))
Base.eachrow(m::AbstractModel) = m

# Vector methods
Base.collect(m::AbstractModel) = collect(m.val)
Base.vec(m::AbstractModel) = collect(m)
Base.Array(m::AbstractModel) = vec(m)

# Dict methods - data as columns
Base.haskey(m::AbstractModel, key::Symbol) = key in keys(m)
Base.keys(m::AbstractModel) = _keys(params(m), m)
_keys(params::Tuple, ::AbstractModel) = (:component, :fieldname, keys(first(params))...)
_keys(::Tuple{}, ::AbstractModel) = ()
_isreserved(key::Symbol) = key == :component || key == :fieldname
@inline _enumerate(tup::NTuple{N,Any}) where N = map(tuple, tuple(1:N...), tup) # type stable tuple enumeration

# Indexing kernels
@inline _getindex(ps::Tuple{Vararg{<:Param}}, i) = _getindex(ps, i, :)
@inline _getindex(ps::Tuple{Vararg{<:Param}}, col::Symbol) = _getindex(ps, :, col)
@inline _getindex(ps::Tuple{Vararg{<:Param}}, i, ::Colon) = ps[i]
@inline _getindex(ps::Tuple{Vararg{<:Param}}, i, col::Symbol) = map(p -> p[col], ps[i])
@inline _getindex(ps::Tuple{Vararg{<:Param}}, i::AbstractVector{Bool}, col::Symbol) = _getindex(ps, findall(i), col)
@inline _setindex(obj, xs, ::Colon, cols) = _setindex(obj, xs, 1:length(params(obj)), cols)
@inline _setindex(obj, xs, idxs::AbstractVector{Bool}, cols::AbstractVector) = _setindex(obj, xs, findall(idxs), cols)
@inline _setindex(obj, xs, idxs::AbstractVector{Bool}, ::Type{Val{col}}) where col = _setindex(obj, xs, findall(idxs), Val{col})
@inline @generated _setindex(ps::Tuple{Vararg{<:Param}}, x, i::Integer, ::Type{Val{col}}) where col = :(@set ps[i].$col = x)
@inline function _setindex(obj, x, i::Integer, ::Type{Val{col}}) where col
    ps = params(obj)
    newps = _setindex(ps, x, i, Val{col})
    return Flatten.reconstruct(obj, newps, SELECT, IGNORE)
end
@inline function _setindex(obj, xs, ::Colon, ::Type{Val{col}}) where col
    # handle special case for ::Colon (all indices) where we can be type stable
    ps = params(obj)
    newps = map(_enumerate(ps)) do (i,p)
        _setindex((p,), xs[i], 1, Val{col})[1]
    end
    return Flatten.reconstruct(obj, newps, SELECT, IGNORE)
end
@inline function _setindex(obj, xs, idxs::AbstractVector, ::Type{Val{col}}) where col
    ps = params(obj)
    for i in 1:length(idxs)
        ps = _setindex(ps, xs[i], idxs[i], Val{col})
    end
    return Flatten.reconstruct(obj, ps, SELECT, IGNORE)
end
@inline function _addindex(obj, xs, ::Type{Val{col}}) where col
    newparams = map(params(obj), xs) do p, x
        Param((; parent(p)..., col => x))
    end
    Flatten.reconstruct(obj, newparams, SELECT, IGNORE)
end

# Indexing interface
@inline Base.getindex(m::AbstractModel, col::Symbol) = getindex(m, :, col)
@inline Base.getindex(m::AbstractModel, i) = getindex(m, i, :)
@inline Base.getindex(m::AbstractModel, ::Colon, ::Colon) = m
@inline function Base.getindex(m::AbstractModel, i, col)
    return if col == :component
        paramcomponents(m)[i]
    elseif col == :fieldname
        paramfieldnames(m)[i]
    else
        _getindex(params(m), i, col)
    end
end
@inline Base.setindex(m::AbstractModel, xs, col::Union{Symbol,Type{<:Val}}) = Base.setindex(m, xs, :, col)
@inline Base.setindex(m::AbstractModel, xs, i) = Base.setindex(m, xs, i, :)
@inline Base.setindex(m::AbstractModel, xs, i, col::Symbol) = Base.setindex(m, xs, i, Val{col})
@inline Base.setindex(m::AbstractModel, xs, i, ::Type{Val{col}}) where col = Base.setindex(m, xs, collect(i), Val{col})
@inline Base.setindex(m::AbstractModel, xs, i::Integer, ::Type{Val{col}}) where col = Base.setindex(m, xs, [i], Val{col})
@inline function Base.setindex(m::AbstractModel, xs, i, cols::Union{Tuple,AbstractVector})
    for col in cols
        m = Base.setindex(m, Tables.getcolumn(xs, col), i, Val{col})
    end
    return m
end
@inline function Base.setindex(m::AbstractModel, xs, i::AbstractVector, ::Type{Val{col}}) where col
    @assert !_isreserved(col) "column name :$col is reserved and cannot be modified"
    @assert col ∈ keys(m) "column $col does not exist"
    return _setindex(m, xs, i, Val{col})
end
@inline function Base.setindex(m::AbstractModel, xs, ::Colon, ::Type{Val{col}}) where col
    @assert !_isreserved(col) "column name :$col is reserved and cannot be modified"
    return if col ∈ keys(m)
        _setindex(m, xs, :, Val{col})
    else
        _addindex(m, xs, Val{col})
    end
end
@inline Base.setindex!(m::AbstractModel, xs, col::Union{Symbol,Type{Val}}) = setindex!(m, xs, :, col)
@inline Base.setindex!(m::AbstractModel, xs, i) = setindex!(m, xs, i, :)
@inline Base.setindex!(m::AbstractModel, xs, i, col) = setparent!(m, parent(Base.setindex(m, xs, i, col)))

# helper function for evaluating indexing predicates
@inline _indices(m, rule) = findall(map(rule, map((c, n, p) -> setparent(p, (; parent(p)..., :component => c, :fieldname => n)), paramcomponents(m), paramfieldnames(m), params(m))))
@inline _indices(::Any, ::Nothing) = Colon()

# Update (value)
"""
    update(obj, xs::Union{AbstractVector,Tuple}, rule=nothing)

Updates the `val` field of `Param`s at rows selected by `rule` in `obj` with the values in `xs`. Type stable and
allocation free when all rows are selected (i.e. `rule=nothing`).
"""
update(obj, xs::Union{AbstractVector,Tuple}, rule=nothing) = _setindex(obj, xs, _indices(obj, rule), Val{:val})
update(m::AbstractModel, xs::Union{AbstractVector,Tuple}, rule=nothing) = Base.setindex(m, xs, _indices(m, rule), Val{:val})
# Update (table)
"""
    update(m::AbstractModel, table, rule=nothing)

Updates the columns of `Param`s at rows selected by `rule` in `m` with the values in `table`, which must implement
the `Tables.jl` interface.
"""
update(m::AbstractModel, table, rule=nothing) = Base.setindex(m, table, _indices(m, rule), filter(!_isreserved, Tables.columnnames(table)))
# Update helpers
"""
    update!(m::AbstractModel, xs, rule=nothing)

Mutating version of `update` which sets the parent of `m` to the updated value.
"""
update!(m::AbstractModel, xs, rule=nothing) = setparent!(m, parent(update(m, xs, rule)))
"""
    update(f, m::AbstractModel, rule=nothing)
    update!(f, m::AbstractModel, rule=nothing)

Updates `Param`s in `m` matching the predicate `rule` with values produced by function `f`.
`rule` should be a function of the form `rule(::Param)::Bool` and `f` should have the
form `f(::Param)::T` where `T` is a vector of values or table.
"""
update!(f, m::AbstractModel, rule=nothing) = setparent!(m, parent(update(f, m, rule)))
function update(f, m::AbstractModel, rule=nothing)
    # case 1: use :val field for 1-D vector
    astable(xs::AbstractVector{<:Number}) = Tables.table(xs; header=[:val])
    astable(xs) = Tables.columns(xs)
    ps = params(m)
    idxs = _indices(m, rule)
    xs = astable(reduce(vcat, map(f, ps[idxs])))
    return Base.setindex(m, xs, idxs, Tables.columnnames(xs))
end

"""
    Model(x)

A wrapper type for any model containing [`Param`](@ref) parameters - essentially marking 
that a custom struct or Tuple holds `Param` fields.

This allows you to index into the model as if it is a linear lisat of parameters, or named 
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
            parent = Flatten.reconstruct(parent, expandedpars, SELECT, IGNORE)
        else
            _noparamwarning()
        end
        new(parent)
    end
end
Model(m::AbstractModel) = Model(parent(m))

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
            parent = Flatten.reconstruct(parent, expandedpars, SELECT, IGNORE)
        else
            _noparamwarning()
        end
        # Make sure all params have all the same keys.
        new{typeof(parent)}(parent)
    end
end
StaticModel(m::AbstractModel) = StaticModel(parent(m))

# Model Utils

# Expand all Params to have the same keys, filling with `nothing`
# This probably will allocate due to `union` returning `Vector`
function _expandkeys(x)
    pars = params(x)
    allkeys = Tuple(union(map(keys, pars)...))
    return map(pars) do par
        vals = map(allkeys) do key
            get(par, key, nothing)
        end
        Param(NamedTuple{allkeys}(vals))
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
